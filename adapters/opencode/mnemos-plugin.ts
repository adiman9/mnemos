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

import type { Plugin } from "@opencode-ai/plugin";

export default (async (input) => {
  const { $, directory } = input;
  const scriptsDir = `${directory}/.mnemos/hooks/scripts`;
  const configPath = `${directory}/.mnemos.yaml`;

  // Check if mnemos is configured
  const configExists = await Bun.file(configPath).exists();
  if (!configExists) {
    console.log("[mnemos] No .mnemos.yaml found, plugin inactive");
    return {};
  }

  return {
    // --- SessionStart equivalent ---
    // Inject MEMORY.md and vault stats into system prompt
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

    // --- PostToolUse (Write) equivalent ---
    // Validate notes after file writes
    "tool.execute.after": async (toolInput, _output) => {
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

    // --- Stop equivalent ---
    // Note: OpenCode doesn't have a direct "session end" hook.
    // Session capture runs via compacting hook as closest equivalent.
    "experimental.session.compacting": async (_input, output) => {
      try {
        await $`bash ${scriptsDir}/session-capture.sh`.quiet();
      } catch {
        // Non-fatal
      }
      // Don't modify compaction output
    },
  };
}) as Plugin;
