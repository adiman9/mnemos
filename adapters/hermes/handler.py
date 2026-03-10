"""
mnemos hook handler — captures session transcripts to vault.

Events:
  gateway:startup  → Initialize vault structure
  session:start    → Create session meta file
  agent:end        → Capture user message + assistant response
  session:reset    → Mark session boundary
"""

import json
import os
from pathlib import Path
from datetime import datetime

VAULT = Path(os.getenv("MNEMOS_VAULT", Path.home() / ".mnemos" / "vault"))
MAX_CONTENT = 5000


async def handle(event_type: str, context: dict):
    """Route Hermes events to mnemos operations."""
    try:
        if event_type == "gateway:startup":
            _ensure_vault()
            print("[mnemos] Vault initialized at", VAULT)
        elif event_type == "session:start":
            _create_session_meta(context)
        elif event_type == "agent:end":
            _capture_turn(context)
        elif event_type == "session:reset":
            _mark_session_boundary(context)
    except Exception as e:
        print(f"[mnemos] Hook error: {e}")


def _ensure_vault():
    dirs = [
        "self",
        "notes",
        "memory/daily",
        "memory/sessions",
        "memory/.dreams",
        "ops/queue",
        "ops/logs",
        "inbox",
        "templates",
    ]
    for d in dirs:
        (VAULT / d).mkdir(parents=True, exist_ok=True)

    identity = VAULT / "self/identity.md"
    if not identity.exists():
        identity.write_text("""# Identity

Who you are and how you work. Update as you develop preferences.

## Core Identity

[Describe your role and working style]

## Working Preferences

[Capture preferences discovered through experience]
""")

    goals = VAULT / "self/goals.md"
    if not goals.exists():
        goals.write_text("""# Goals

## Active

[Current objectives]

## Completed

[Recently finished]

## Parked

[On hold — with reason]
""")

    memory = VAULT / "memory/MEMORY.md"
    if not memory.exists():
        memory.write_text("""# Memory Boot Context

No observations yet. Run /observe after a few sessions to begin capturing insights.
""")


def _truncate(text: str, max_len: int = MAX_CONTENT) -> str:
    if len(text) <= max_len:
        return text
    return text[:max_len] + "[truncated]"


def _create_session_meta(context: dict):
    session_id = context.get("session_id", "")
    if not session_id:
        return

    sessions_dir = VAULT / "memory/sessions"
    sessions_dir.mkdir(parents=True, exist_ok=True)

    meta_file = sessions_dir / f"{session_id}.meta.json"
    if meta_file.exists():
        return

    meta = {
        "session_id": session_id,
        "harness": "hermes",
        "platform": context.get("platform", "unknown"),
        "user_id": context.get("user_id", ""),
        "start_time": datetime.utcnow().isoformat() + "Z",
        "vault_path": str(VAULT),
    }
    meta_file.write_text(json.dumps(meta) + "\n")


def _append_entry(session_id: str, role: str, content: str):
    if not content:
        return

    sessions_dir = VAULT / "memory/sessions"
    sessions_dir.mkdir(parents=True, exist_ok=True)

    output = sessions_dir / f"{session_id}.jsonl"
    entry = {
        "ts": datetime.utcnow().isoformat() + "Z",
        "role": role,
        "content": _truncate(content),
        "session_id": session_id,
    }

    with open(output, "a") as f:
        f.write(json.dumps(entry) + "\n")


def _capture_turn(context: dict):
    session_id = context.get(
        "session_id", f"hermes-{datetime.now().strftime('%Y%m%d')}"
    )

    user_message = context.get("message", "")
    if user_message:
        _append_entry(session_id, "user", user_message)

    response = context.get("response", "")
    if response:
        _append_entry(session_id, "assistant", response)


def _mark_session_boundary(context: dict):
    """Mark session boundary for observation extraction."""
    session_key = context.get("session_key", "")
    sessions_dir = VAULT / "memory/sessions"

    if session_key:
        boundary_file = sessions_dir / ".boundaries"
        with open(boundary_file, "a") as f:
            f.write(f"{datetime.utcnow().isoformat()}Z {session_key}\n")
