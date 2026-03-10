#!/usr/bin/env bash
#
# Build script: Copy core skills into the OpenClaw adapter for npm publishing
#
# Usage: ./scripts/build-skills.sh
#
# This copies core/skills/* to adapters/openclaw/skills/ so they're included
# in the npm package. Run before `npm publish`.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADAPTER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$ADAPTER_DIR/../.." && pwd)"

SKILLS_SRC="$REPO_ROOT/core/skills"
SKILLS_DST="$ADAPTER_DIR/skills"

echo "Building mnemos-openclaw skills..."
echo "  Source: $SKILLS_SRC"
echo "  Dest:   $SKILLS_DST"

# Clean destination
rm -rf "$SKILLS_DST"
mkdir -p "$SKILLS_DST"

# Copy all skills
for skill_dir in "$SKILLS_SRC"/*/; do
    skill_name=$(basename "$skill_dir")
    echo "  + $skill_name"
    cp -r "$skill_dir" "$SKILLS_DST/$skill_name"
done

# Count skills
skill_count=$(find "$SKILLS_DST" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
echo ""
echo "Done. $skill_count skills copied to $SKILLS_DST"
echo ""
echo "Next: npm publish (skills will be included via package.json files array)"
