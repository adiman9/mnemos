# FactoryAI Droids Adapter

Adapter for [FactoryAI Droids](https://factory.ai) — AI coding agents that run in isolated cloud environments.

## What It Does

- Deploys skills to `.factory/skills/`
- Deploys hooks to `.factory/hooks/` (hooks.json + shell scripts)
- Copies `SYSTEM.md` as `DROIDS.md` at workspace root

## Hook Events Used

| Event | Script | Purpose |
|-------|--------|---------|
| `SessionStart` | `session-start.sh` | Inject MEMORY.md via `additionalContext` JSON response |
| `Stop` | `session-capture.sh` | Transform Droids JSONL transcript to mnemos format |
| `PostToolUse` (Edit) | `validate-note.sh` | Schema enforcement on note writes |
| `PostToolUse` (Edit) | `auto-commit.sh` | Non-blocking git commit on vault changes |
| `UserPromptSubmit` | `context-inject.sh` | (Optional) Dynamic context injection |

## Droids-Specific Features

**Native JSONL Support**: Droids already store session transcripts as JSONL at `~/.factory/sessions/<project>/`. The adapter reads these directly via `transcript_path` provided in hook input.

**Context Injection**: Unlike Claude Code which uses stdout for context, Droids use a JSON response with `additionalContext` field. The `session-start.sh` hook outputs:

```json
{
  "additionalContext": "=== mnemos Session Start ===\n..."
}
```

**Hook Input Format**: All Droids hooks receive JSON via stdin containing:
- `session_id`: Current session identifier
- `transcript_path`: Path to the native JSONL transcript
- `tool_name`, `tool_input`: For tool-related hooks

## Full Hook Coverage

All 4 mnemos lifecycle events are natively supported:

| mnemos Event | Droids Hook | Notes |
|--------------|-------------|-------|
| Session Start | `SessionStart` | Full support via `additionalContext` |
| Per-turn Capture | `Stop` | Full support, `transcript_path` provided |
| Pre-compaction | — | No native event; use heuristics if needed |
| Post-write Validation | `PostToolUse` (Edit) | Full support |

## Install

```bash
# From mnemos root:
./install.sh --adapter droids <workspace-path> <vault-path>
```

**Workspace** = Your project directory (where you run `droid`). mnemos installs hooks and skills here in `.factory/`.

**Vault** = Persistent knowledge store. Can be shared across multiple workspaces.

Example:
```bash
./install.sh --adapter droids ~/projects/my-app ~/mnemos-vault
```

## Manual Setup

If not using the installer, copy files manually:

1. Copy `adapters/droids/hooks.json` to `.factory/hooks.json` in your project
2. Copy hook scripts to `.factory/hooks/scripts/`
3. Copy skills from `core/skills/` to `.factory/skills/`
4. Create `.mnemos.yaml` pointing to your vault:

```yaml
vault_path: /path/to/your/vault
```

## Droid Transcript Format

Droids emit events like:
```json
{"type":"system","subtype":"init","session_id":"abc-123","model":"claude-opus-4.6"}
{"type":"tool_call","toolName":"Execute","parameters":{"command":"npm test"}}
{"type":"tool_result","toolId":"Execute","value":"FAIL: test_auth.py..."}
{"type":"completion","finalText":"The build error was due to..."}
```

The adapter transforms these to mnemos standard format:
```json
{"ts":"...","role":"tool_use","tool":"Execute","content":"{\"command\":\"npm test\"}","session_id":"abc-123"}
{"ts":"...","role":"tool_result","tool":"Execute","content":"FAIL: test_auth.py...","session_id":"abc-123"}
{"ts":"...","role":"assistant","content":"The build error was due to...","session_id":"abc-123"}
```

## Troubleshooting

**Hooks not firing**: Ensure `.factory/hooks.json` exists and Droids version supports hooks. Check `droid --version`.

**Transcript not found**: The adapter looks for transcripts at `~/.factory/sessions/<encoded-workspace-path>/`. Verify this directory exists after running a Droid session.

**Context not injected**: Ensure `session-start.sh` outputs valid JSON. Test with:
```bash
echo '{"session_id":"test"}' | bash .factory/hooks/scripts/session-start.sh
```

## References

- [Droids Hooks Reference](https://docs.factory.ai/reference/hooks-reference)
- [Droid Exec Documentation](https://docs.factory.ai/cli/droid-exec/overview)
- [Custom Droids Guide](https://docs.factory.ai/cli/configuration/custom-droids)
