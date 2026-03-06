import type { ExtensionAPI } from "@mariozechner/pi-agent-core";

const SCRIPTS_DIR = ".mnemos/hooks/scripts";

export default async function mnemos(pi: ExtensionAPI) {
  const vaultConfigured = await pi.exec("test", ["-f", ".mnemos.yaml"]);
  if (vaultConfigured.exitCode !== 0) return;

  pi.on("session_start", async () => {
    const result = await pi.exec("bash", [`${SCRIPTS_DIR}/session-start.sh`]);
    if (result.stdout) {
      pi.log(result.stdout);
    }
  });

  pi.on("context", async (event) => {
    const result = await pi.exec("bash", [`${SCRIPTS_DIR}/session-start.sh`]);
    if (result.stdout) {
      event.messages.unshift({
        role: "system",
        content: `<!-- mnemos boot context -->\n${result.stdout}\n<!-- /mnemos boot context -->`,
      });
    }
  });

  pi.on("tool_execution_end", async (event) => {
    const toolName = event.toolName?.toLowerCase();
    if (toolName !== "write" && toolName !== "edit") return;

    const filePath = event.args?.filePath || event.args?.file_path || "";

    await pi.exec("bash", [`${SCRIPTS_DIR}/validate-note.sh`], {
      env: { CLAUDE_TOOL_INPUT_FILE_PATH: filePath },
    });

    pi.exec("bash", [`${SCRIPTS_DIR}/auto-commit.sh`], {
      env: { CLAUDE_TOOL_INPUT_FILE_PATH: filePath },
    });
  });

  pi.on("session_shutdown", async () => {
    await pi.exec("bash", [`${SCRIPTS_DIR}/session-capture.sh`]);
  });
}
