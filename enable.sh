#!/bin/bash
# Enable the Agent Orchestrator Protocol globally for Claude Code.
#
# Adds a short, sentinel-wrapped pointer to ~/.claude/CLAUDE.md (loaded into every
# Claude Code session) so that — wherever you run `claude` — the session knows how to
# scaffold the protocol into the CURRENT git repo on request. The pointer references
# THIS clone's protocol file (single source of truth), so `git pull` here updates the
# behaviour everywhere — nothing is duplicated into CLAUDE.md.
#
# Idempotent (re-run any time; replaces the prior block). Backs up CLAUDE.md first.
#   Usage:  bash enable.sh
#   Undo:   remove the <!-- agent-orchestrator-protocol --> block from ~/.claude/CLAUDE.md

set -e
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PROTO="$KIT_DIR/AGENT_ORCHESTRATOR_PROTOCOL.md"
MD="$HOME/.claude/CLAUDE.md"

mkdir -p "$HOME/.claude"
[ -f "$MD" ] || touch "$MD"
cp "$MD" "$MD.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

# Remove any prior block (sentinel-delimited) for idempotency.
if grep -q "<!-- agent-orchestrator-protocol -->" "$MD"; then
  awk '/<!-- agent-orchestrator-protocol -->/{s=1} !s{print} /<!-- \/agent-orchestrator-protocol -->/{s=0}' "$MD" > "$MD.t" && mv "$MD.t" "$MD"
fi

cat >> "$MD" <<EOF

<!-- agent-orchestrator-protocol -->
## Agent orchestration
This machine has the Agent Orchestrator Protocol available.
When I ask to "orchestrate", "run agents", or "set up a team" inside a git repo, read
$PROTO
and run its "FOR CLAUDE CODE — SETUP" in **the current repo** (it scaffolds \`orchestration/agents/\` here).
Do NOT scaffold it in a non-git directory or in a container dir like \`~/dev\` — orchestration is per-codebase.
A "session" is a Claude Code conversation; an "agent" = a session + its \`orchestration/agents/<name>/\` notebook + a worktree desk.
<!-- /agent-orchestrator-protocol -->
EOF

echo "[done] enabled in $MD"
echo "  -> points to $PROTO"
echo "  -> 'git pull' in $KIT_DIR updates the behaviour everywhere; re-run enable.sh after a path change."
