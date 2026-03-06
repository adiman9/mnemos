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

Add to `~/.codex/config.toml`:

```toml
notify = ["/path/to/workspace/.mnemos/hooks/scripts/codex-notify.sh"]
```

## Transcript Capture

Codex writes session rollouts to `rollouts/*.jsonl`. The `notify` hook can invoke `session-capture.sh` to incrementally convert these to mnemos standard JSONL format in `memory/sessions/`. Without a pre-compaction hook, some transcript data may be lost during context resets.

## Limitations

Without per-file-write hooks, the validate-note and auto-commit behaviors only trigger at turn boundaries. For active vaults, consider running validation as a periodic script outside the agent.
