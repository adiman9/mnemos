/**
 * mnemos adapter for OpenCode (sst/opencode)
 *
 * This plugin bridges mnemos lifecycle hooks into OpenCode's plugin system.
 * It executes the same shell scripts used by Claude Code, just triggered
 * through OpenCode's TypeScript event hooks instead of hooks.json.
 *
 * Install:
 *   1. Copy this file to <workspace>/.opencode/plugins/mnemos-plugin.ts
 *   2. Add to opencode.json: { "plugin": ["./.opencode/plugins/mnemos-plugin.ts"] }
 *   3. Run mnemos install.sh to set up vault + skills
 */

type Plugin = (input: {
  $: (strings: TemplateStringsArray, ...values: unknown[]) => { quiet: () => Promise<{ stdout: { toString: () => string } }> };
  directory: string;
  client?: {
    session?: {
      messages?: (args: { sessionID: string }) => Promise<unknown>;
    };
  };
}) => Promise<Record<string, unknown>>;

declare const Bun: {
  file: (path: string) => { exists: () => Promise<boolean>; text: () => Promise<string> };
  write: (path: string, data: string) => Promise<number>;
};

export default (async (input: Parameters<Plugin>[0]) => {
  const { $, directory, client } = input;
  const scriptsDir = `${directory}/.mnemos/hooks/scripts`;
  const configPath = `${directory}/.mnemos.yaml`;
  const TRUNCATE_LIMIT = 2000;

  const truncate = (value: string): string => {
    if (value.length <= TRUNCATE_LIMIT) return value;
    return `${value.slice(0, TRUNCATE_LIMIT)}[truncated]`;
  };

  const readText = async (path: string): Promise<string> => {
    const file = Bun.file(path);
    if (!(await file.exists())) return "";
    return file.text();
  };

  const parseVaultPath = async (): Promise<string | null> => {
    try {
      const config = await readText(configPath);
      const match = config.match(/^\s*vault_path:\s*(.+)\s*$/m);
      if (!match) return null;
      return match[1].trim().replace(/^['\"]|['\"]$/g, "");
    } catch (error) {
      console.error("[mnemos] failed reading .mnemos.yaml:", error);
      return null;
    }
  };

  const extractText = (value: unknown): string => {
    if (value === null || value === undefined) return "";
    if (typeof value === "string") return value;
    if (typeof value === "number" || typeof value === "boolean") return String(value);
    if (Array.isArray(value)) {
      const joined = value
        .map((part) => extractText(part))
        .filter((part) => part.length > 0)
        .join("\n");
      if (joined.length > 0) return joined;
    }
    if (typeof value === "object") {
      const record = value as Record<string, unknown>;
      const orderedKeys = [
        "text",
        "content",
        "input",
        "output",
        "args",
        "arguments",
        "reasoning",
        "name",
        "tool",
        "parts",
        "message",
      ];
      for (const key of orderedKeys) {
        if (!(key in record)) continue;
        const candidate = extractText(record[key]);
        if (candidate.length > 0) return candidate;
      }
      try {
        return JSON.stringify(record);
      } catch {
        return "";
      }
    }
    return "";
  };

  type TranscriptRole = "user" | "assistant" | "tool_use" | "tool_result" | "compaction_boundary";

  type TranscriptLine = {
    ts: string;
    role: TranscriptRole;
    content: string;
    session_id: string;
    tool?: string;
  };

  const statePromise = (async () => {
    const vaultPath = await parseVaultPath();
    if (!vaultPath) return null;
    const sessionsDir = `${vaultPath}/memory/sessions`;
    const cursorsPath = `${sessionsDir}/.cursors.json`;
    const queueBySession = new Map<string, Promise<void>>();

    const ensureSessionsDir = async () => {
      await $`mkdir -p ${sessionsDir}`.quiet();
    };

    const readCursors = async (): Promise<Record<string, { offset: number; observed_offset: number; last_capture: string }>> => {
      try {
        const text = await readText(cursorsPath);
        if (!text.trim()) return {};
        const parsed = JSON.parse(text) as Record<string, { offset: number; observed_offset: number; last_capture: string }>;
        return parsed && typeof parsed === "object" ? parsed : {};
      } catch {
        return {};
      }
    };

    const writeCursors = async (cursors: Record<string, { offset: number; observed_offset: number; last_capture: string }>) => {
      await Bun.write(cursorsPath, JSON.stringify(cursors, null, 2));
    };

    const updateCursor = async (
      sessionID: string,
      updater: (current: { offset: number; observed_offset: number; last_capture: string }) => {
        offset: number;
        observed_offset: number;
        last_capture: string;
      }
    ) => {
      const cursors = await readCursors();
      const current = cursors[sessionID] ?? { offset: 0, observed_offset: 0, last_capture: new Date(0).toISOString() };
      cursors[sessionID] = updater(current);
      await writeCursors(cursors);
    };

    const appendLines = async (sessionID: string, lines: TranscriptLine[]) => {
      if (lines.length === 0) return;
      await ensureSessionsDir();
      const jsonlPath = `${sessionsDir}/${sessionID}.jsonl`;
      const existing = await readText(jsonlPath);
      const payload = `${existing}${lines.map((line) => JSON.stringify(line)).join("\n")}\n`;
      await Bun.write(jsonlPath, payload);
    };

    const ensureMeta = async (sessionID: string, nowIso: string) => {
      const metaPath = `${sessionsDir}/${sessionID}.meta.json`;
      if (await Bun.file(metaPath).exists()) return;
      const meta = {
        session_id: sessionID,
        harness: "opencode",
        start_time: nowIso,
        vault_path: vaultPath,
      };
      await Bun.write(metaPath, `${JSON.stringify(meta, null, 2)}\n`);
    };

    const lineKey = (line: TranscriptLine): string => `${line.role}|${line.tool ?? ""}|${line.content}`;

    const readExistingKeys = async (sessionID: string): Promise<Set<string>> => {
      const jsonlPath = `${sessionsDir}/${sessionID}.jsonl`;
      const text = await readText(jsonlPath);
      const keys = new Set<string>();
      for (const rawLine of text.split("\n")) {
        if (!rawLine.trim()) continue;
        try {
          const parsed = JSON.parse(rawLine) as TranscriptLine;
          keys.add(lineKey(parsed));
        } catch {
        }
      }
      return keys;
    };

    const queueSessionWrite = (sessionID: string, work: () => Promise<void>): Promise<void> => {
      const previous = queueBySession.get(sessionID) ?? Promise.resolve();
      const next = previous
        .catch(() => {})
        .then(work)
        .catch((error) => {
          console.error("[mnemos] transcript capture failed:", error);
        });
      queueBySession.set(sessionID, next);
      return next;
    };

    const normalizeLine = (line: Omit<TranscriptLine, "ts"> & { ts?: string }): TranscriptLine => ({
      ...line,
      ts: line.ts ?? new Date().toISOString(),
      content: truncate(line.content || ""),
    });

    const writeTranscriptLines = async (sessionID: string, lines: Array<Omit<TranscriptLine, "ts">>) => {
      const nowIso = new Date().toISOString();
      await ensureMeta(sessionID, nowIso);
      const normalized = lines
        .map((line) => normalizeLine({ ...line, ts: nowIso }))
        .filter((line) => line.content.length > 0 || line.role === "compaction_boundary");
      if (normalized.length === 0) return;
      await appendLines(sessionID, normalized);
      await updateCursor(sessionID, (current) => ({
        offset: current.offset + normalized.length,
        observed_offset: current.observed_offset,
        last_capture: nowIso,
      }));
    };

    const extractUserContent = (messageInput: Record<string, unknown>): string => {
      const fromInput =
        extractText(messageInput.message) ||
        extractText(messageInput.parts) ||
        extractText(messageInput.content) ||
        extractText(messageInput.userMessage) ||
        extractText(messageInput.prompt);
      if (fromInput) return fromInput;
      return messageInput.messageID ? `[message_id:${String(messageInput.messageID)}]` : "";
    };

    const extractAssistantContent = (messageOutput: Record<string, unknown>): string => {
      return (
        extractText(messageOutput.message) ||
        extractText(messageOutput.parts) ||
        extractText(messageOutput.content) ||
        extractText(messageOutput.response)
      );
    };

    const captureTurn = async (messageInput: Record<string, unknown>, messageOutput: Record<string, unknown>) => {
      const sessionID = String(messageInput.sessionID ?? "");
      if (!sessionID) return;
      const userContent = extractUserContent(messageInput);
      const assistantContent = extractAssistantContent(messageOutput);
      await writeTranscriptLines(sessionID, [
        { role: "user", content: userContent, session_id: sessionID },
        { role: "assistant", content: assistantContent, session_id: sessionID },
      ]);
    };

    const captureTool = async (toolInput: Record<string, unknown>, toolOutput: Record<string, unknown>) => {
      const sessionID = String(toolInput.sessionID ?? "");
      if (!sessionID) return;
      const tool = String(toolInput.tool ?? "unknown");
      const argsText = (() => {
        try {
          return JSON.stringify(toolInput.args ?? {});
        } catch {
          return extractText(toolInput.args);
        }
      })();
      const outputText =
        extractText(toolOutput.output) || extractText(toolOutput.result) || extractText(toolOutput.parts) || extractText(toolOutput);

      await writeTranscriptLines(sessionID, [
        { role: "tool_use", content: argsText, tool, session_id: sessionID },
        { role: "tool_result", content: outputText, tool, session_id: sessionID },
      ]);
    };

    const messageToLines = (sessionID: string, message: Record<string, unknown>): TranscriptLine[] => {
      const roleRaw = String(message.role ?? "");
      const role = roleRaw.toLowerCase();
      const tool = message.tool ? String(message.tool) : undefined;
      const content = extractText(message.content) || extractText(message.parts) || extractText(message.message) || "";

      if (role === "user" || role === "assistant") {
        return [
          normalizeLine({
            role: role as "user" | "assistant",
            content,
            session_id: sessionID,
            ts: typeof message.ts === "string" ? message.ts : undefined,
          }),
        ];
      }
      if (role === "tool_use" || role === "tool_result") {
        return [
          normalizeLine({
            role: role as "tool_use" | "tool_result",
            content,
            tool,
            session_id: sessionID,
            ts: typeof message.ts === "string" ? message.ts : undefined,
          }),
        ];
      }

      if (role === "tool") {
        const argsText = (() => {
          try {
            return JSON.stringify(message.args ?? {});
          } catch {
            return extractText(message.args);
          }
        })();
        return [
          normalizeLine({ role: "tool_use", content: argsText, tool, session_id: sessionID }),
          normalizeLine({ role: "tool_result", content, tool, session_id: sessionID }),
        ];
      }

      return [];
    };

    const flushBeforeCompaction = async (sessionID: string) => {
      if (!client?.session?.messages) return;

      const history = await client.session.messages({ sessionID });
      const messages = Array.isArray(history)
        ? history
        : Array.isArray((history as { messages?: unknown[] }).messages)
          ? ((history as { messages: unknown[] }).messages as unknown[])
          : [];
      const existingKeys = await readExistingKeys(sessionID);
      const pending: TranscriptLine[] = [];

      for (const item of messages) {
        if (!item || typeof item !== "object") continue;
        const lines = messageToLines(sessionID, item as Record<string, unknown>);
        for (const line of lines) {
          const key = lineKey(line);
          if (existingKeys.has(key)) continue;
          existingKeys.add(key);
          pending.push(line);
        }
      }

      const boundary: TranscriptLine = normalizeLine({
        role: "compaction_boundary",
        content: "Context compacted by harness",
        session_id: sessionID,
      });
      pending.push(boundary);

      await ensureMeta(sessionID, new Date().toISOString());
      await appendLines(sessionID, pending);
      await updateCursor(sessionID, () => ({
        offset: 0,
        observed_offset: 0,
        last_capture: new Date().toISOString(),
      }));
    };

    return {
      queueSessionWrite,
      captureTurn,
      captureTool,
      flushBeforeCompaction,
    };
  })();

  // Check if mnemos is configured
  const configExists = await Bun.file(configPath).exists();
  if (!configExists) {
    console.log("[mnemos] No .mnemos.yaml found, plugin inactive");
    return {};
  }

  return {
    // --- SessionStart equivalent ---
    // Inject MEMORY.md and vault stats into system prompt
    "experimental.chat.system.transform": async (_input: unknown, output: { system: string[] }) => {
      try {
        const result = await $`bash ${scriptsDir}/session-start.sh`.quiet();
        if (result.stdout.toString().trim()) {
          output.system.push(
            `\n\n<!-- mnemos boot context -->\n${result.stdout.toString()}\n<!-- /mnemos boot context -->`
          );
        }
      } catch (e) {
        console.error("[mnemos] session-start hook failed:", e);
      }
    },

    "chat.message": async (messageInput: unknown, messageOutput: unknown) => {
      const state = await statePromise;
      if (!state) return;
      const sessionID = String((messageInput as Record<string, unknown>).sessionID ?? "");
      if (!sessionID) return;
      void state.queueSessionWrite(sessionID, async () => {
        await state.captureTurn(
          messageInput as Record<string, unknown>,
          (messageOutput ?? {}) as Record<string, unknown>
        );
      });
    },

    // --- PostToolUse (Write) equivalent ---
    // Validate notes after file writes
    "tool.execute.after": async (toolInput: Record<string, any>, toolOutput: unknown) => {
      const state = await statePromise;
      const sessionID = String((toolInput as Record<string, unknown>).sessionID ?? "");
      if (state && sessionID) {
        void state.queueSessionWrite(sessionID, async () => {
          await state.captureTool(
            toolInput as Record<string, unknown>,
            (toolOutput ?? {}) as Record<string, unknown>
          );
        });
      }

      if (toolInput.tool !== "write" && toolInput.tool !== "edit") return;

      const filePath = toolInput.args?.filePath || toolInput.args?.file_path;
      if (!filePath) return;

      // Run validate-note.sh (sync — blocks until validation completes)
      try {
        const result = await $`CLAUDE_TOOL_INPUT_FILE_PATH=${filePath} bash ${scriptsDir}/validate-note.sh`.quiet();
        if (result.stdout.toString().trim()) {
          console.log("[mnemos] validate:", result.stdout.toString().trim());
        }
      } catch {
        // Validation warnings are non-fatal
      }

      // Run auto-commit.sh (async — fire and forget)
      $`CLAUDE_TOOL_INPUT_FILE_PATH=${filePath} bash ${scriptsDir}/auto-commit.sh`
        .quiet()
        .catch(() => {});
    },

    "experimental.session.compacting": async (compactingInput: unknown, _output: unknown) => {
      const state = await statePromise;
      const sessionID = String((compactingInput as Record<string, unknown>).sessionID ?? "");

      try {
        if (state && sessionID) {
          await state.queueSessionWrite(sessionID, async () => {
            await state.flushBeforeCompaction(sessionID);
          });
        }
      } catch (error) {
        console.error("[mnemos] pre-compaction transcript flush failed:", error);
      }
    },
  };
}) as Plugin;
