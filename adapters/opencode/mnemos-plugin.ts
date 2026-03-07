/**
 * mnemos adapter for OpenCode (sst/opencode)
 *
 * Captures session transcripts via experimental.chat.messages.transform hook
 * which provides the full message history in-process (no HTTP/SDK needed).
 *
 * Install:
 *   1. Copy this file to <workspace>/.opencode/plugins/mnemos-plugin.ts
 *   2. Add to opencode.json: { "plugin": ["./.opencode/plugins/mnemos-plugin.ts"] }
 *   3. Run mnemos install.sh to set up vault + skills
 */

import type { Plugin } from "@opencode-ai/plugin";

const TRUNCATE_LIMIT = 2000;

function truncate(value: string): string {
  if (value.length <= TRUNCATE_LIMIT) return value;
  return `${value.slice(0, TRUNCATE_LIMIT)}[truncated]`;
}

type TranscriptLine = {
  ts: string;
  role: "user" | "assistant" | "tool_use" | "tool_result" | "compaction_boundary";
  content: string;
  session_id: string;
  tool?: string;
};

export default (async (input) => {
  const { $, directory } = input;
  const scriptsDir = `${directory}/.mnemos/hooks/scripts`;
  const configPath = `${directory}/.mnemos.yaml`;

  const configExists = await Bun.file(configPath).exists();
  if (!configExists) {
    console.log("[mnemos] No .mnemos.yaml found, plugin inactive");
    return {};
  }

  const configText = await Bun.file(configPath).text();
  const vaultMatch = configText.match(/^\s*vault_path:\s*(.+)\s*$/m);
  const defaultVault = `${process.env.HOME}/.mnemos/vault`;
  const vaultPath = vaultMatch
    ? vaultMatch[1].trim().replace(/^['"]|['"]$/g, "")
    : defaultVault;

  if (!vaultPath) {
    console.error("[mnemos] No vault_path in .mnemos.yaml");
    return {};
  }

  const sessionsDir = `${vaultPath}/memory/sessions`;
  const cursorsPath = `${sessionsDir}/.cursors.json`;
  await $`mkdir -p ${sessionsDir}`.quiet();

  type CursorEntry = { offset: number; observed_offset: number; last_capture: string };
  type Cursors = Record<string, CursorEntry>;

  async function readCursors(): Promise<Cursors> {
    try {
      const f = Bun.file(cursorsPath);
      if (!(await f.exists())) return {};
      const text = await f.text();
      if (!text.trim()) return {};
      return JSON.parse(text) as Cursors;
    } catch {
      return {};
    }
  }

  async function writeCursors(cursors: Cursors) {
    await Bun.write(cursorsPath, JSON.stringify(cursors));
  }

  async function readExistingLines(sessionID: string): Promise<TranscriptLine[]> {
    try {
      const f = Bun.file(`${sessionsDir}/${sessionID}.jsonl`);
      if (!(await f.exists())) return [];
      const text = await f.text();
      return text
        .split("\n")
        .filter((l) => l.trim())
        .map((l) => JSON.parse(l) as TranscriptLine);
    } catch {
      return [];
    }
  }

  async function appendLines(sessionID: string, lines: TranscriptLine[]) {
    if (lines.length === 0) return;
    const path = `${sessionsDir}/${sessionID}.jsonl`;
    const existing = await (async () => {
      try {
        const f = Bun.file(path);
        if (await f.exists()) return await f.text();
        return "";
      } catch {
        return "";
      }
    })();
    const payload = existing + lines.map((l) => JSON.stringify(l)).join("\n") + "\n";
    await Bun.write(path, payload);
  }

  async function ensureMeta(sessionID: string) {
    const metaPath = `${sessionsDir}/${sessionID}.meta.json`;
    if (await Bun.file(metaPath).exists()) return;
    await Bun.write(
      metaPath,
      JSON.stringify({
        session_id: sessionID,
        harness: "opencode",
        start_time: new Date().toISOString(),
        vault_path: vaultPath,
      }) + "\n"
    );
  }

  function lineFingerprint(line: TranscriptLine): string {
    return `${line.role}|${line.tool ?? ""}|${line.content.slice(0, 200)}`;
  }

  const writeQueues = new Map<string, Promise<void>>();

  function enqueue(sessionID: string, work: () => Promise<void>): void {
    const prev = writeQueues.get(sessionID) ?? Promise.resolve();
    const next = prev.catch(() => {}).then(work).catch((e) => {
      console.error("[mnemos] transcript write failed:", e);
    });
    writeQueues.set(sessionID, next);
  }

  /**
   * Process messages from the in-process history (from experimental.chat.messages.transform).
   * Diffs against existing JSONL and appends new lines.
   */
  async function processMessages(sessionID: string, messages: Array<{ info: any; parts: any[] }>): Promise<number> {
    await ensureMeta(sessionID);
    const existing = await readExistingLines(sessionID);
    const existingFPs = new Set(existing.map(lineFingerprint));
    const newLines: TranscriptLine[] = [];

    for (const msg of messages) {
      if (!msg || typeof msg !== "object") continue;
      const info = msg.info ?? msg;
      const parts: any[] = Array.isArray(msg.parts) ? msg.parts : [];
      const role = String(info?.role ?? "").toLowerCase();
      const msgTime = info?.time?.created
        ? new Date(info.time.created).toISOString()
        : new Date().toISOString();

      if (role === "user" || role === "assistant") {
        const textParts = parts
          .filter((p: any) => p?.type === "text" && typeof p?.text === "string")
          .map((p: any) => p.text as string);
        const content = textParts.join("\n");
        if (!content) continue;

        const line: TranscriptLine = {
          ts: msgTime,
          role: role as "user" | "assistant",
          content: truncate(content),
          session_id: sessionID,
        };
        if (!existingFPs.has(lineFingerprint(line))) {
          newLines.push(line);
          existingFPs.add(lineFingerprint(line));
        }
      }

      for (const part of parts) {
        if (part?.type !== "tool" || !part?.tool) continue;
        const state = part.state;
        if (!state) continue;
        const toolName = String(part.tool);

        const inputContent = (() => {
          if (state.input && typeof state.input === "object") {
            try { return JSON.stringify(state.input); } catch { return ""; }
          }
          return state.raw ?? "";
        })();
        if (inputContent) {
          const useLine: TranscriptLine = {
            ts: state.time?.start ? new Date(state.time.start).toISOString() : msgTime,
            role: "tool_use",
            content: truncate(inputContent),
            tool: toolName,
            session_id: sessionID,
          };
          if (!existingFPs.has(lineFingerprint(useLine))) {
            newLines.push(useLine);
            existingFPs.add(lineFingerprint(useLine));
          }
        }

        if ((state.status === "completed" || state.status === "error") && (state.output || state.error)) {
          const outputContent = state.output ?? state.error ?? "";
          const resultLine: TranscriptLine = {
            ts: state.time?.end ? new Date(state.time.end).toISOString() : msgTime,
            role: "tool_result",
            content: truncate(outputContent),
            tool: toolName,
            session_id: sessionID,
          };
          if (!existingFPs.has(lineFingerprint(resultLine))) {
            newLines.push(resultLine);
            existingFPs.add(lineFingerprint(resultLine));
          }
        }
      }
    }

    if (newLines.length > 0) {
      await appendLines(sessionID, newLines);
      const cursors = await readCursors();
      const cur = cursors[sessionID] ?? { offset: 0, observed_offset: 0, last_capture: "" };
      cursors[sessionID] = {
        offset: existing.length + newLines.length,
        observed_offset: cur.observed_offset,
        last_capture: new Date().toISOString(),
      };
      await writeCursors(cursors);
    }

    return newLines.length;
  }

  let lastSessionID = "";

  return {
    "experimental.chat.system.transform": async (_input, output) => {
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

    "experimental.chat.messages.transform": async (_input, output) => {
      const messages = output?.messages;
      if (!Array.isArray(messages) || messages.length === 0) return;

      const firstMsg = messages[0];
      const sessionID = firstMsg?.info?.sessionID ?? firstMsg?.parts?.[0]?.sessionID ?? "";
      if (!sessionID) return;

      lastSessionID = sessionID;
      enqueue(sessionID, () => processMessages(sessionID, messages));
    },

    "experimental.text.complete": async (textInput, output) => {
      const sessionID = textInput.sessionID;
      if (!sessionID || !output?.text) return;
      lastSessionID = sessionID;

      enqueue(sessionID, async () => {
        await ensureMeta(sessionID);
        const existing = await readExistingLines(sessionID);
        const existingFPs = new Set(existing.map(lineFingerprint));

        const line: TranscriptLine = {
          ts: new Date().toISOString(),
          role: "assistant",
          content: truncate(output.text),
          session_id: sessionID,
        };

        if (existingFPs.has(lineFingerprint(line))) return;

        await appendLines(sessionID, [line]);
        const cursors = await readCursors();
        const cur = cursors[sessionID] ?? { offset: 0, observed_offset: 0, last_capture: "" };
        cursors[sessionID] = {
          offset: existing.length + 1,
          observed_offset: cur.observed_offset,
          last_capture: new Date().toISOString(),
        };
        await writeCursors(cursors);
      });
    },

    "chat.message": async (messageInput, _output) => {
      lastSessionID = messageInput.sessionID ?? lastSessionID;
    },

    "tool.execute.after": async (toolInput, _output) => {
      if (toolInput.tool !== "write" && toolInput.tool !== "edit") return;
      const filePath = toolInput.args?.filePath || toolInput.args?.file_path;
      if (!filePath) return;

      try {
        const result = await $`CLAUDE_TOOL_INPUT_FILE_PATH=${filePath} bash ${scriptsDir}/validate-note.sh`.quiet();
        if (result.stdout.toString().trim()) {
          console.log("[mnemos] validate:", result.stdout.toString().trim());
        }
      } catch {
        // non-fatal
      }

      $`CLAUDE_TOOL_INPUT_FILE_PATH=${filePath} bash ${scriptsDir}/auto-commit.sh`
        .quiet()
        .catch(() => {});
    },

    "experimental.session.compacting": async (compactingInput, _output) => {
      const sessionID = compactingInput.sessionID;
      if (!sessionID) return;

      try {
        const boundary: TranscriptLine = {
          ts: new Date().toISOString(),
          role: "compaction_boundary",
          content: "Context compacted by harness",
          session_id: sessionID,
        };
        await appendLines(sessionID, [boundary]);
        const cursors = await readCursors();
        cursors[sessionID] = {
          offset: 0,
          observed_offset: 0,
          last_capture: new Date().toISOString(),
        };
        await writeCursors(cursors);
      } catch (e) {
        console.error("[mnemos] pre-compaction flush failed:", e);
      }
    },
  };
}) satisfies Plugin;
