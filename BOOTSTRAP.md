# mnemos — Agent Self-Install

You are an AI agent reading this to install mnemos, a 3-layer memory system. Follow these steps exactly.

## What You Get

- 20 skills for knowledge management (/observe, /reduce, /reflect, /dream, etc.)
- Session hooks for automatic memory capture
- A persistent vault that survives across your sessions

## Step 1: Clone

```bash
git clone https://github.com/ArsContexta/mnemos.git /tmp/mnemos
```

If git is unavailable, download and extract:
```bash
curl -sL https://github.com/ArsContexta/mnemos/archive/refs/heads/main.tar.gz | tar xz -C /tmp
mv /tmp/mnemos-main /tmp/mnemos
```

## Step 2: Detect Your Harness

Check which agent harness you are running in. Run these checks and use the FIRST match:

```bash
# Check in order of specificity
if [ -f ".opencode/config.json" ] || [ -f "opencode.json" ]; then
  ADAPTER="opencode"
elif [ -d ".pi" ] || command -v pi >/dev/null 2>&1; then
  ADAPTER="pi"
elif [ -d ".openclaw" ]; then
  ADAPTER="openclaw"
elif [ -f ".codex/config.toml" ] || [ -f "$HOME/.codex/config.toml" ]; then
  ADAPTER="codex"
elif [ -d ".amp" ]; then
  ADAPTER="amp"
else
  ADAPTER="claude-code"
fi
```

If you know your harness already, just pick: `claude-code` | `opencode` | `pi` | `openclaw` | `codex` | `amp`

The `claude-code` adapter also works for **Cursor** and **Cline**.

## Step 3: Choose Vault Location

The vault is where your persistent memory lives. It should be OUTSIDE your working directory if possible.

- If you have a dedicated memory volume: use that path
- If not: `$HOME/.mnemos-vault` is a safe default
- If constrained to current directory: use `./vault`

## Step 4: Install

```bash
/tmp/mnemos/install.sh --adapter $ADAPTER $(pwd) <vault-path>
```

Replace `<vault-path>` with your chosen path from Step 3.

## Step 5: Verify

After installation, confirm these exist:
- `.mnemos.yaml` in your workspace root (contains vault_path)
- Skills in the appropriate location for your harness
- Vault directories: `<vault>/notes/`, `<vault>/memory/`, `<vault>/self/`, `<vault>/inbox/`

## Step 6: Orient

Read your system prompt file (CLAUDE.md, AGENTS.md, or AGENT.md — whichever was created) to understand how mnemos works. Then:

1. Read `<vault>/self/identity.md` and fill in who you are
2. Read `<vault>/self/goals.md` and set your current objectives
3. Run `/next` to see what needs attention

## Quick Reference

After install, these skills are available:

| Skill | What It Does |
|-------|-------------|
| `/observe` | Capture what you learned during work |
| `/seed` | Queue an article or source for processing |
| `/reduce` | Extract insights from a source |
| `/reflect` | Find connections between notes |
| `/dream` | Cross-domain speculative connections |
| `/next` | What should you do next? |
| `/stats` | Vault health metrics |
| `/learn` | Research a topic and add to vault |

Full skill list: 20 skills total. See the system prompt for complete documentation.

## Optional: Scheduled Execution

Some skills benefit from running automatically (daily consolidation, weekly dreams). Set up OS-level scheduling:

```bash
/tmp/mnemos/schedule.sh --vault <vault-path>
```

This installs launchd (macOS), systemd (Linux), or crontab triggers. Edit `<vault>/ops/schedule.yaml` to customize which skills run and when.

## Cleanup

```bash
rm -rf /tmp/mnemos
```
