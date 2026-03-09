"""
mnemos hook handler — captures session transcripts to vault.

Events:
  gateway:startup  → Initialize vault structure
  agent:end        → Capture assistant response
  session:reset    → Mark session boundary
"""

import json
import os
from pathlib import Path
from datetime import datetime

VAULT = Path(os.getenv("MNEMOS_VAULT", Path.home() / ".mnemos" / "vault"))


async def handle(event_type: str, context: dict):
    """Route Hermes events to mnemos operations."""
    try:
        if event_type == "gateway:startup":
            _ensure_vault()
            print("[mnemos] Vault initialized at", VAULT)
        elif event_type == "agent:end":
            _capture_turn(context)
        elif event_type == "session:reset":
            _mark_session_boundary(context)
    except Exception as e:
        print(f"[mnemos] Hook error: {e}")


def _ensure_vault():
    """Initialize vault directory structure."""
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

    # Create default identity file
    identity = VAULT / "self/identity.md"
    if not identity.exists():
        identity.write_text("""# Identity

Who you are and how you work. Update as you develop preferences.

## Core Identity

[Describe your role and working style]

## Working Preferences

[Capture preferences discovered through experience]
""")

    # Create default goals file
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

    # Create boot context file
    memory = VAULT / "memory/MEMORY.md"
    if not memory.exists():
        memory.write_text("""# Memory Boot Context

No observations yet. Run /observe after a few sessions to begin capturing insights.
""")


def _capture_turn(context: dict):
    """Append assistant turn to session transcript."""
    session_id = context.get(
        "session_id", f"hermes-{datetime.now().strftime('%Y%m%d')}"
    )
    response = context.get("response", "")

    if not response:
        return

    sessions_dir = VAULT / "memory/sessions"
    sessions_dir.mkdir(parents=True, exist_ok=True)

    output = sessions_dir / f"{session_id}.jsonl"

    entry = {
        "ts": datetime.utcnow().isoformat() + "Z",
        "role": "assistant",
        "content": response[:5000],  # Truncate very long responses
        "session_id": session_id,
    }

    with open(output, "a") as f:
        f.write(json.dumps(entry) + "\n")


def _mark_session_boundary(context: dict):
    """Mark session boundary for observation extraction."""
    session_key = context.get("session_key", "")
    sessions_dir = VAULT / "memory/sessions"

    if session_key:
        boundary_file = sessions_dir / ".boundaries"
        with open(boundary_file, "a") as f:
            f.write(f"{datetime.utcnow().isoformat()}Z {session_key}\n")
