# Codex CLI Adapter

Adapter for [OpenAI Codex CLI](https://github.com/openai/codex).

## Status: Partial Support

Codex CLI exposes only the `after_agent` (turn complete) lifecycle event to external scripts. This means mnemos hooks degrade:

| mnemos Event | Codex Equivalent | Status |
|-------------|------------------|--------|
| SessionStart | None | **Not supported** — AGENTS.md provides static context instead |
| PostToolUse (Write) | None | **Not supported** — no per-file-write hook |
| Transcript capture | `notify` (after_agent) | Partial — fires per turn, reads `rollouts/*.jsonl` |
| Pre-compact | None | **Not supported** |
| Auto-commit | `notify` (after_agent) | Partial — commits after turns, not individual writes |

## What Works

- **Skills**: Codex uses `SKILL.md` with YAML frontmatter natively. Full skill support.
- **System prompt**: Codex reads `AGENTS.md` natively. Full support.
- **Turn-end hook**: Can archive sessions and auto-commit via `notify` config.

## Install

```bash
./install.sh --adapter codex <workspace-path> <vault-path>
```

This will:
1. Copy skills to `<workspace>/skills/` (Codex convention)
2. Copy `SYSTEM.md` as `AGENTS.md`
3. Create `.mnemos.yaml`
4. Initialize vault structure
5. Print `config.toml` snippet for the notify hook

## Manual Config

Ensure the project is trusted in `~/.codex/config.toml`:

```toml
[projects."/path/to/workspace"]
trust_level = "trusted"
```

The installer creates a project-local `.codex/config.toml` with the notify hook automatically. If you have a custom global `notify` (e.g. desktop notifications), chain it in the project-local config to preserve it.

## Transcript Capture

Codex writes session rollouts to `~/.codex/sessions/YYYY/MM/DD/rollout-*-{thread-id}.jsonl`. The `codex-notify.sh` hook fires after each agent turn, reads the rollout file, and incrementally converts new entries to mnemos standard JSONL format in `memory/sessions/`. It uses byte-offset cursors to avoid re-processing previously captured content.

## Limitations

Without per-file-write hooks, the validate-note and auto-commit behaviors only trigger at turn boundaries. For active vaults, consider running validation as a periodic script outside the agent.
