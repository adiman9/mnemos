# Codex CLI Adapter

Adapter for [OpenAI Codex CLI](https://github.com/openai/codex).

## Status: Partial Support

Codex CLI exposes only the `after_agent` (turn complete) lifecycle event to external scripts. This means mnemos hooks degrade:

| mnemos Event | Codex Equivalent | Status |
|-------------|------------------|--------|
| SessionStart | None | **Not supported** — AGENTS.md provides static context instead |
| PostToolUse (Write) | None | **Not supported** — no per-file-write hook |
| Stop | `notify` (after_agent) | Partial — fires after each turn, not just session end |
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

Add to `~/.codex/config.toml`:

```toml
notify = ["/path/to/workspace/.mnemos/hooks/scripts/codex-notify.sh"]
```

## Limitations

Without per-file-write hooks, the validate-note and auto-commit behaviors only trigger at turn boundaries. For active vaults, consider running validation as a periodic script outside the agent.
