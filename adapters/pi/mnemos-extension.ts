import type { ExtensionAPI } from "@mariozechner/pi-agent-core";
import { readFileSync, writeFileSync, appendFileSync, mkdirSync, existsSync } from "node:fs";
import { join, resolve } from "node:path";

const SCRIPTS_DIR = ".mnemos/hooks/scripts";
const MAX_CONTENT = 2000;

interface CaptureState {
  vaultPath: string;
  sessionsDir: string;
  sessionId: string;
  outputFile: string;
  cursorFile: string;
  metaFile: string;
}

let capture: CaptureState | null = null;

function isoNow(): string {
  return new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
}

function truncate(s: string, max = MAX_CONTENT): string {
  return s.length > max ? s.slice(0, max) + "[truncated]" : s;
}

function resolveVaultPath(cwd: string): string | null {
  const configPath = join(cwd, ".mnemos.yaml");
  if (!existsSync(configPath)) return null;
  const content = readFileSync(configPath, "utf-8");
  const match = content.match(/^vault_path:\s*["']?(.+?)["']?\s*$/m);
  if (!match) return null;
  let vaultPath = match[1].trim();
  if (!vaultPath.startsWith("/")) {
    vaultPath = resolve(cwd, vaultPath);
  }
  return existsSync(vaultPath) ? vaultPath : null;
}

/**
 * Lazily initialize capture state from the ExtensionContext.
 * Returns true if capture is ready, false if vault is not configured.
 */
function ensureCapture(ctx: { cwd: string; sessionManager: { getSessionId(): string } }): boolean {
  if (capture) return true;

  const vaultPath = resolveVaultPath(ctx.cwd);
  if (!vaultPath) return false;

  const sessionId = ctx.sessionManager.getSessionId();
  if (!sessionId) return false;

  const sessionsDir = join(vaultPath, "memory", "sessions");
  mkdirSync(sessionsDir, { recursive: true });

  const cursorFile = join(sessionsDir, ".cursors.json");
  if (!existsSync(cursorFile)) writeFileSync(cursorFile, "{}\n");

  const metaFile = join(sessionsDir, `${sessionId}.meta.json`);
  if (!existsSync(metaFile)) {
    writeFileSync(
      metaFile,
      JSON.stringify({
        session_id: sessionId,
        harness: "pi",
        start_time: isoNow(),
        vault_path: vaultPath,
      }) + "\n",
    );
  }

  capture = {
    vaultPath,
    sessionsDir,
    sessionId,
    outputFile: join(sessionsDir, `${sessionId}.jsonl`),
    cursorFile,
    metaFile,
  };

  return true;
}

/**
 * Append a single entry to the session JSONL file.
 */
function appendEntry(role: string, content: string, extra?: Record<string, unknown>): void {
  if (!capture) return;
  const entry: Record<string, unknown> = {
    ts: isoNow(),
    role,
    content: truncate(content),
    session_id: capture.sessionId,
    ...extra,
  };
  appendFileSync(capture.outputFile, JSON.stringify(entry) + "\n");
}

export default function mnemos(pi: ExtensionAPI) {
  // ── Session lifecycle ─────────────────────────────────────────────────

  pi.on("session_start", async (_event, ctx) => {
    ensureCapture(ctx);
  });

  // ── Boot context injection (MEMORY.md + vault stats) ────────────────

  pi.on("before_agent_start", async (event, ctx) => {
    const result = await pi.exec("bash", [`${SCRIPTS_DIR}/session-start.sh`], { cwd: ctx.cwd });
    if (result.stdout) {
      return {
        systemPrompt: event.systemPrompt + "\n\n" + result.stdout,
      };
    }
  });

  // ── Per-turn transcript capture ───────────────────────────────────────

  pi.on("input", async (event, ctx) => {
    if (!ensureCapture(ctx)) return;
    if (event.text) {
      appendEntry("user", event.text);
    }
  });

  pi.on("turn_end", async (event, ctx) => {
    if (!ensureCapture(ctx)) return;

    const msg = event.message;
    if (msg?.content) {
      if (Array.isArray(msg.content)) {
        const textParts = msg.content
          .filter((p: any) => p.type === "text" && p.text)
          .map((p: any) => p.text as string);

        const textContent = textParts.join("\n");
        if (textContent) {
          appendEntry("assistant", textContent);
        }

        for (const part of msg.content) {
          if ((part as any).type === "tool_use" && (part as any).name) {
            const toolInput = JSON.stringify((part as any).input || {});
            appendEntry("tool_use", truncate(toolInput), { tool: (part as any).name });
          }
        }
      } else if (typeof msg.content === "string" && msg.content) {
        appendEntry("assistant", msg.content);
      }
    }

    if (event.toolResults?.length) {
      for (const tr of event.toolResults as any[]) {
        let content = "";
        if (typeof tr.content === "string") {
          content = tr.content;
        } else if (Array.isArray(tr.content)) {
          content = tr.content
            .filter((p: any) => p.type === "text")
            .map((p: any) => p.text as string)
            .join("\n");
        }
        if (content) {
          appendEntry("tool_result", truncate(content), {
            tool: tr.name || tr.tool_use_id || "",
          });
        }
      }
    }
  });

  // ── Post-tool hooks (validate notes, auto-commit) ─────────────────────

  pi.on("tool_execution_end", async (event) => {
    const toolName = (event as any).toolName?.toLowerCase();
    if (toolName !== "write" && toolName !== "edit") return;

    const filePath = (event as any).args?.filePath || (event as any).args?.file_path || "";

    await pi.exec("bash", [`${SCRIPTS_DIR}/validate-note.sh`], {
      env: { CLAUDE_TOOL_INPUT_FILE_PATH: filePath },
    });

    pi.exec("bash", [`${SCRIPTS_DIR}/auto-commit.sh`], {
      env: { CLAUDE_TOOL_INPUT_FILE_PATH: filePath },
    });
  });

  // ── Session shutdown ──────────────────────────────────────────────────
  pi.on("session_shutdown", async () => {});
}
