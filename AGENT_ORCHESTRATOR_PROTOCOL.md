# Agent Orchestrator Protocol

> A portable, repo-agnostic pattern for running multiple Claude Code agents on **one** codebase without them stepping on each other — a **tech lead** that coordinates and merges, plus as many **agent builders** as you need, each isolated on its own desk.
>
> **This file is both the spec and the installer.** Hand it to Claude Code in any git repo and say *"set this up for me"* — it will read the **[FOR CLAUDE CODE — SETUP](#for-claude-code--setup)** section and scaffold the structure for you. No tmux required.

---

## TL;DR — the mental model

- **Tech lead** = the foreman. Works on `main`. Plans with you, assigns work, reviews, merges. Does small/fast fixes inline; delegates anything bigger.
- **Agent** = a product builder. Owns one **vertical slice** (a whole feature end-to-end: backend + frontend + tests), not a tech layer.
- **Desk** = a **git worktree** — each agent's own private folder so their files/builds never collide.
- **Notebook** = each agent's coordination files (`orchestration/agents/<agent>/`) — **shared**, on `main`, so everyone can read them.
- **Mailbox** = automatic messaging between lead and agents (Claude Code **Agent Teams**). No polling, no copy-paste.
- **Git flow** = agent commits on its own branch → lead reviews → **cherry-picks** the approved commit onto `main` → removes the desk.

**The two rules that keep it from breaking:**
1. **One owner per slice.** Split work by feature, never by layer. Two agents must never edit the same files.
2. **Only the lead touches `main`.** Agents only ever commit to their own branch on their own desk.

---

## Part 1 — The model

### Roles

| Role | Lives in | Does |
|---|---|---|
| **Human (you)** | wherever | Approves the plan + scope, makes architectural calls, does the final merge ratify |
| **Tech lead** | the main checkout, on `main` | Plans with you, defines slices, spawns agents, reviews diffs, cherry-picks to `main`, small fast fixes |
| **Agent** | its own worktree (desk), on its own branch | Builds one vertical slice end-to-end, commits to its branch, reports via mailbox |

The lead **may build** — quick fixes, checks, one-liners, cross-cutting glue. The rule is: the moment it's a *real chunk of work*, hand it to an agent. A foreman picking up a hammer for one nail is fine; a foreman disappearing into framing a wall stops running the site.

### Vertical slices, not layers

Each agent owns a **feature**, not a **layer**. The billing agent owns billing's backend, frontend, and tests. This is what keeps agents from colliding: if two agents both "own the backend" they fight over the same files; if each owns a different *feature*, their files naturally don't overlap. **One owner per slice = no merge surprises.**

### Desks (worktrees) vs Notebooks (sessions)

An agent has two homes, and they live in different places on purpose:

- **Notebook** — small text files (identity, knowledge, status, backlog). **Shared, one copy, on `main`** so the lead and other agents can read it. → `orchestration/agents/<agent>/`
- **Desk** — a full code checkout (where the agent actually edits code). **Private, isolated, one per agent.** → a git worktree beside the repo.

> A branch is just a label in history. A working tree is the actual files in a folder. **One folder can only have one branch checked out at a time** — so multiple agents sharing one folder clobber each other. A **worktree** gives each agent its own folder with its own branch checked out *simultaneously*, all sharing the same `.git` history. That's why worktrees, not bare branches, are the unit of isolation.

Keep the desk **outside** the repo (a sibling folder), never inside the sessions folder — a worktree is a checkout of the repo, and nesting a repo inside itself confuses git.

### Coordination — the mailbox

Use Claude Code **Agent Teams** (experimental; enable with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, needs Claude Code v2.1.32+). What it gives you:

- **Each agent has its own context window.** The lead's conversation does **not** carry over — agents are isolated, not sharing your session.
- **Automatic mailbox.** Messages between lead and agents are delivered automatically; the lead doesn't poll. Agents notify the lead when they go idle.
- **You stay in control.** Cycle between agents with **Shift+Down**; talk to the lead or any agent directly; interrupt anyone anytime.

**Display is a separate, swappable choice — not part of the structure:**
- **In-process** (default, recommended start): all agents in one terminal. No tmux. Full mailbox, full visibility.
- **Split-panes** (optional): each agent in its own tmux/iTerm2 pane. Same team, same mailbox — just a different view. Flip to it later if one window feels busy. See the [appendix](#appendix--optional-expansions).

### Git flow, in one breath

> Lead assigns a slice → agent builds it on its own desk/branch → agent reports "done" via mailbox → lead reviews the diff → lead **cherry-picks** the approved commit onto `main` → lead removes the desk → next slice.

**Cherry-pick** copies *one specific approved commit* onto `main` (vs merge, which brings a whole branch). It creates a new commit with the same changes but a different SHA — so the lead pulls in exactly the vetted change and nothing else.

---

## Part 2 — Repo layout (works for any repo)

```
<repo>/                          ← THE repo (git). Lead works here, on main.
  <your code>                    ← e.g. backend/  frontend/  src/ ...
  orchestration/
    PROTOCOL.md                  ← this file (or a pointer to it)
    LEAD.md                      ← the lead's bootstrap (generated at setup)
    SLATE.md                     ← current plan: which slices are active, who owns what
    agents/
      _template/                 ← notebook template copied per agent
      <agent-a>/                 ← agent A's notebook (shared, on main)
      <agent-b>/                 ← agent B's notebook
    worktrees.md                 ← desk registry: agent → worktree path → branch

<repo>-wt/                       ← DESKS live here, OUTSIDE the repo (siblings)
  <agent-a>/                     ← agent A's private code checkout, its own branch
  <agent-b>/                     ← agent B's private code checkout, its own branch
```

- **Notebook** → `<repo>/orchestration/agents/<agent>/` (shared, on `main`)
- **Desk** → `<repo>-wt/<agent>/` (private, isolated, disposable)

> Run this once **per repo** — there's no global install. Each repo you want agents on gets its own `<repo>/orchestration/` and its own sibling `<repo>-wt/`. Nothing lives at the parent (`dev/`) level.

> A worktree contains its own copy of `orchestration/`. Ignore it — the agent's *real* notebook is always the shared one in the main `<repo>/` checkout. Each agent is told this explicitly in its spawn prompt.

---

## FOR CLAUDE CODE — SETUP

**If a user has handed you this file and asked you to set it up, do the following. Adapt every step to the actual repo — nothing here is hardcoded.**

### Step 0 — Preconditions
1. Confirm the working directory is a git repo (`git rev-parse --is-inside-work-tree`). If not, offer to `git init` or ask for the right path.
2. Note the repo root path as `<repo>` and the sibling desks root as `<repo>-wt`.
3. Tell the user that Agent Teams needs `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` and Claude Code v2.1.32+. Offer to add the env var (e.g. to `.claude/settings.json` or their shell profile). Don't assume it's on.

### Step 1 — Plan the slices WITH the human (do not guess)
1. Briefly explore the repo to understand its shape (top-level dirs, frameworks, existing features).
2. Propose a small set of **vertical slices** (features owned end-to-end), each with a one-line scope and the file/dir roots it would own. **Keep slices non-overlapping** (rule 1).
3. **Ask the human to approve / adjust the slice list and how many agents to run.** Do not proceed without approval. Recommend starting with a handful of *active* agents, not a large fleet.

### Step 2 — Scaffold the coordination layer (on `main`)
Create, if absent:
- `orchestration/` with `LEAD.md`, `SLATE.md`, `worktrees.md`, and `agents/_template/`.
- Copy this file to `orchestration/PROTOCOL.md` (or leave a one-line pointer to its source URL).
- Fill `SLATE.md` with the approved slices: agent name, scope, owned roots, status.
- Generate `LEAD.md` from the **[Lead bootstrap template](#lead-bootstrap-template)**, substituting the real repo path and slice list.
- Populate `agents/_template/` from the **[Notebook template](#notebook-template-lean)**.

### Step 3 — Create each agent's notebook (shared)
For each approved slice, copy `agents/_template/` → `agents/<agent>/` and fill in: role, owned file/dir roots, where-to-learn-your-domain pointers (real entry points in this repo). Keep it **lean** — a router to the code, not a re-statement of it.

### Step 4 — Install the persistence hooks + verify script
Write both scripts from **[Persistence hooks](#persistence-hooks)** to `orchestration/hooks/` (`chmod +x` them), and **merge** the hook block into `.claude/settings.json` — merge, never overwrite; preserve any existing `hooks`/settings (use `jq`/`python3`). Also write **[verify.sh](#verify-script)** and **[agent-bind.sh](#agent-bind-integration-with-claude-code-sessions-optional)** to `orchestration/` (`chmod +x`), and the **[`/session-compact` command](#compaction-command-session-compact)** to `.claude/commands/session-compact.md`. The hooks make the harness enforce notebook flushing before any agent rests or compacts (they require `jq`); `agent-bind.sh` is the optional bridge the `claude-code-sessions` CLI wrapper calls if present; `/session-compact` lets an agent flush + trim its notebook on demand before you compact.

### Step 5 — Register agents for the lead (project CLAUDE.md)
Append the **[Project CLAUDE.md registry](#project-claudemd-registry-lead-discovery)** block to the repo's root `CLAUDE.md` (create it if absent), substituting the real `<repo>`. This is how the lead discovers which agents exist, where their notebooks are, and the `agentType = slice name` spawn convention.

### Step 6 — Set up desks on demand (not all upfront)
Desks are created per slate, not permanently. Record the convention in `worktrees.md` and use, per active agent:
```bash
git worktree add <repo>-wt/<agent> -b <agent>/<short-task>     # create desk + branch
# ... agent works + commits in <repo>-wt/<agent> ...
git worktree remove <repo>-wt/<agent>                          # after merge
```
Add `<repo>-wt/` to `.gitignore` if it would ever land inside the repo path (it shouldn't — keep it a sibling).

### Step 7 — Wire the run
1. Confirm Agent Teams is enabled (Step 0.3). Default display mode: **in-process** (no tmux).
2. Show the human the **[loop](#part-3--running-a-slate)** and the **[Agent spawn prompt](#agent-spawn-prompt-template)** — note it tells each agent its desk path, its notebook path, the two rules, and that a hook enforces flushing before idle.
3. Hand control back: the human (with the lead) plans the first slate and spawns the team.

### Step 8 — Confirm
Run `bash orchestration/verify.sh` and show its output (expect all `ok`). Then print a short summary: what was created (incl. hooks, verify.sh, CLAUDE.md registry), the active slices, how to start a slate, and how to flip to split-panes later. Do **not** push to any remote unless explicitly asked.

---

## Part 3 — Running a slate

1. **Plan with the human.** Lead proposes the slate (scope, slices, agents). Human approves.
2. **Spawn the team** (in-process). Lead spawns one agent per active slice, each with the spawn prompt.
3. **Each agent gets a desk.** `git worktree add <repo>-wt/<agent> -b <agent>/<task>`.
4. **Agents build** their slice end-to-end on their own branch; they read/write their **notebook** in the shared `orchestration/agents/<agent>/`.
5. **Agents report** via mailbox when done (or blocked).
6. **Lead reviews** the diff. If good → `git cherry-pick <sha>` onto `main`. If not → send feedback via mailbox.
7. **Lead removes the desk** and assigns the next slice.
8. **Human ratifies** the final merge state (optional gate).

Only the lead touches `main`. Agents only touch their own branch/desk/notebook.

---

## Part 4 — Persistence, restart & protecting notebooks

Agent Teams teammates are **transient**: when the lead session ends (or the team is cleaned up, or a teammate stops), the teammate sessions and the team/task state are gone — `/resume` does **not** restore teammates. So persistence cannot rely on the live sessions. It lives entirely in the **notebooks on disk**, which Agent Teams never touches.

### Three lifespans — know what survives
- **Live agent (conversation)** — dies with the lead. Transient.
- **Team/task state** (`~/.claude/teams`, `~/.claude/tasks`) — removed when the session ends. Transient.
- **Notebooks** (`orchestration/agents/<agent>/`) — plain files in the repo. **Permanent.** Created once at setup; never recreated.

You never lose the *work state* — only whatever was in conversation but not yet written to a notebook. This layer's whole job is to shrink that gap to near-zero.

### Write-as-you-go (the rule)
Agents update notebooks **continuously**, not at the end: `STATUS.md` on every task transition; append `MEMORY.md`/`DECISIONS.md` on any learning or choice; `KNOWLEDGE.md` when domain understanding changes. A crash then loses at most the last unwritten turn.

### Hooks enforce it (discipline is not enough)
Two hooks make the harness — not goodwill — protect the notebooks. Setup writes them to `orchestration/hooks/` and wires them in `.claude/settings.json` (scripts in [Templates](#persistence-hooks)).

- **`notebook-guard.sh`** on **`Stop`** + **`TeammateIdle`**: before an agent rests, if its `STATUS.md` was not written recently it **blocks once (exit 2)** with "flush your notebook first," then lets it rest. No agent goes idle on stale state. One nudge only — never an infinite loop.
- **`notebook-snapshot.sh`** on **`PreCompact`** + **`SessionEnd`**: overwrites a single `LAST_SNAPSHOT.md` with the latest mechanical state (timestamp, git HEAD, dirty-file count) — survives compaction and graceful exit even if the model wrote nothing. Latest-only, so it never grows; `MEMORY.md` stays human-curated.

> A hard `kill -9` / power loss runs **no** hook — nothing can protect that. The `Stop`/`TeammateIdle` hooks firing every turn are the real safety net: notebooks stay at most one turn stale.

### Compaction ritual — flush, then compact/kill
Two-tier truth: the compaction summary is lossy working residue; the notebook is durable truth. So **flush before compacting**.

- **Manual (preferred):** run **`/session-compact`** (a slash command this protocol installs — template below). It makes the agent write *all* its durables (STATUS / MEMORY / DECISIONS / KNOWLEDGE) **and trim** them, then it tells you to run `/compact`. Two-step, exactly because a command can't trigger `/compact` itself.
- **Automatic:** when Claude Code auto-compacts, the LLM gets no turn to write prose — so the `PreCompact` hook (`LAST_SNAPSHOT.md`) is the mechanical backstop, and the per-turn `Stop`/`TeammateIdle` guard means STATUS was already fresh. You lose at most the last turn's prose.

After compaction (or a cold start) an agent reads its notebook (STATUS → LAST_SNAPSHOT → MEMORY tail) and resumes.

### Restart loop — respawn, never recreate
```
lead dies → teammates die → team/task state gone, NOTEBOOKS intact on disk
→ relaunch lead → it reads SLATE.md + agents/*/STATUS.md to see who existed and where each was
→ respawn a teammate (agentType = its slice) → it reads its notebook → continues
```
You recreate the *agent* (a cheap respawn), never the *files*.

> **Spawn convention that makes the hooks work:** spawn each teammate with **`agentType` = its slice name** (matching its `agents/<slice>/` folder). The hooks read `agent_type` to find the right notebook — and resolve the shared notebook from inside the agent's worktree via `git rev-parse --git-common-dir`, so it always writes to the main checkout, not the worktree copy.

---

## Templates

### Notebook template (lean, separate files)
A notebook is a small set of files in `orchestration/agents/_template/`, copied per agent. Separate files (not one blob) so the hooks can key off `STATUS.md` and append to `MEMORY.md`, and so each survives compaction independently. Keep them lean.

`KNOWLEDGE.md` (identity + where to learn — written once, updated rarely):
```markdown
# <agent> — KNOWLEDGE
**Slice (owns end-to-end):** <feature>
**Owned roots:** <dir/file roots — the ONLY files this agent edits>
**Desk:** ../<repo>-wt/<agent>   ·   **Notebook:** <repo>/orchestration/agents/<agent>/
## Where to learn my domain
- <entry-point files / docs / tests in THIS repo>
```
`STATUS.md` (current state — rewritten on every task transition; the hook checks this):
```markdown
# <agent> — STATUS
- task: <current task> · state: active|blocked|done · branch: <agent>/<task> · commit: <sha>
- next: <next intended action>
```
`MEMORY.md` (append-only human learnings — **one line each**; keep it lean):
```markdown
# <agent> — MEMORY
```
`DECISIONS.md` (append-only non-obvious choices — **one line each**):
```markdown
# <agent> — DECISIONS
- <date> chose A over B because X
```

> **Anti-bloat.** `STATUS.md`/`KNOWLEDGE.md` are rewritten in place and `LAST_SNAPSHOT.md` is overwritten — all bounded. `MEMORY.md`/`DECISIONS.md` are append-only, so keep entries to one line and let **`/session-compact`** trim them (keep the last ~20 MEMORY lines; fold anything still durable into `KNOWLEDGE.md`, drop the rest). A bloated notebook defeats the purpose — cold-start should read in a few KB.

### Lead bootstrap template
`orchestration/LEAD.md`:
```markdown
# Tech Lead — Bootstrap

You are the tech lead for <repo>. You work on `main` in <repo>.

## Your job
- Plan slates WITH the human; get approval before spawning.
- Define non-overlapping vertical slices (one owner per slice).
- Spawn one agent per active slice (Agent Teams, in-process).
- Do small/fast fixes inline; delegate anything bigger.
- Review each agent's diff; cherry-pick approved commits to `main`; remove desks.
- Keep SLATE.md and worktrees.md current.

## The two rules (binding)
1. One owner per slice — agents never edit the same files.
2. Only you touch `main` — agents commit only to their own branch/desk.

## Per agent, at spawn
- Create desk:  git worktree add <repo>-wt/<agent> -b <agent>/<task>
- Spawn the teammate with agentType = its slice name (so notebook hooks resolve).
- Send the Agent spawn prompt (slice, desk path, notebook path, rules).
- On done: review diff → git cherry-pick <sha> → git worktree remove <repo>-wt/<agent>.

## Discover agents & restart (teammates are transient)
- To see which agents exist + what they own: read SLATE.md and agents/*/STATUS.md.
- Teammates do NOT survive a session end and /resume does not restore them.
  To restart one: respawn it (agentType = its slice) — it reads its own notebook
  (STATUS → MEMORY tail) and continues. Never recreate notebooks; they persist on disk.

## Reference
- Protocol: orchestration/PROTOCOL.md
- Current plan: orchestration/SLATE.md
- Desks: orchestration/worktrees.md
- Persistence + hooks: PROTOCOL.md "Part 4"
```

### Agent spawn prompt template
Lead sends this to each agent when spawning:
```
You are a builder agent on <repo>. You own ONE vertical slice end-to-end.

SLICE: <feature — what you own, backend + frontend + tests>
OWNED ROOTS: <the ONLY file/dir roots you may edit>
YOUR DESK (edit code here): <repo>-wt/<agent>/   ← your own worktree, your own branch
YOUR NOTEBOOK (read/write coordination here): <repo>/orchestration/agents/<agent>/
   ← always the MAIN checkout copy, NOT the copy inside your desk

RULES (binding):
- Edit ONLY your owned roots. If you need to touch another slice's files, message the lead — don't edit.
- Commit ONLY to your own branch on your desk. Never touch main.
- Build the slice end-to-end with tests. Verify before reporting done.

WORKFLOW:
- Read your notebook first (role, owned roots, where-to-learn pointers, last STATUS).
- Do the work on your desk; commit to your branch.
- Update your notebook AS YOU GO: STATUS.md on every task change; append
  MEMORY.md/DECISIONS.md on any learning or choice; KNOWLEDGE.md when your
  understanding shifts. Do not batch this to the end — a hook will block you
  from going idle until your STATUS.md is freshly written.
- Report via the mailbox: what shipped, files touched, how you verified, commit SHA.

Acknowledge ("ack, ready") and begin.
```

### Git snippets
```bash
# create a desk
git worktree add <repo>-wt/<agent> -b <agent>/<short-task>

# lead reviews an agent's work (from the main checkout)
git -C <repo> log <agent>/<short-task> --oneline          # find the commit
git -C <repo> show <sha>                                   # review the diff

# lead pulls in the approved commit
git -C <repo> cherry-pick <sha>

# tear down the desk after merge
git worktree remove <repo>-wt/<agent>
git worktree prune
```

### Persistence hooks
Setup writes these two scripts to `orchestration/hooks/` (chmod +x) and wires them in `.claude/settings.json`. They need `jq`. Both resolve the *shared* notebook from inside a worktree via `git rev-parse --git-common-dir`. They identify the agent from `agent_type` (Agent Teams) **or**, for a solo `claude <name>` session, from the `customTitle` in the session's own transcript — so both teammates and solo agent sessions are protected, with no env var.

`orchestration/hooks/notebook-guard.sh` (blocks rest until the notebook is flushed):
```bash
#!/usr/bin/env bash
# Wired to Stop + TeammateIdle. Blocks once (exit 2) if STATUS.md is stale,
# nudging the agent to flush; never loops. Requires jq.
INPUT=$(cat)
# Identify the agent: Agent Teams sets agent_type; a solo `claude <name>` session
# carries its name as customTitle in its own transcript (no env var needed).
AGENT=$(printf '%s' "$INPUT" | jq -r '.agent_type // empty' 2>/dev/null)
if [ -z "$AGENT" ]; then
  TP=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
  [ -f "$TP" ] && AGENT=$(grep '"customTitle"' "$TP" 2>/dev/null | tail -1 | sed -n 's/.*"customTitle":"\([^"]*\)".*/\1/p')
fi
[ -n "$AGENT" ] || exit 0
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // "."' 2>/dev/null)
COMMON=$(git -C "$CWD" rev-parse --git-common-dir 2>/dev/null) || exit 0
MAIN=$(cd "$CWD" && cd "$(dirname "$COMMON")" && pwd)
NB="$MAIN/orchestration/agents/$AGENT/STATUS.md"
[ -f "$NB" ] || exit 0
FLAG="/tmp/robo-nbguard-$AGENT"
# Fresh notebook (written in last 2 min) -> agent flushed -> allow rest.
if [ -n "$(find "$NB" -mmin -2 2>/dev/null)" ]; then rm -f "$FLAG"; exit 0; fi
# Stale: nudge once, but never trap in a loop.
if [ -f "$FLAG" ]; then rm -f "$FLAG"; exit 0; fi
touch "$FLAG"
echo "Flush your notebook before resting: write STATUS.md + append MEMORY.md/DECISIONS.md. ($NB)" >&2
exit 2
```

`orchestration/hooks/notebook-snapshot.sh` (deterministic backstop snapshot):
```bash
#!/usr/bin/env bash
# Wired to PreCompact + SessionEnd. OVERWRITES a single LAST_SNAPSHOT.md with the
# latest mechanical state so durable truth survives compaction/exit even if the
# model wrote nothing. Latest-only -> the file never grows (no unbounded append).
INPUT=$(cat)
# agent_type for Agent Teams; else the solo session's customTitle from its transcript.
AGENT=$(printf '%s' "$INPUT" | jq -r '.agent_type // empty' 2>/dev/null)
if [ -z "$AGENT" ]; then
  TP=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
  [ -f "$TP" ] && AGENT=$(grep '"customTitle"' "$TP" 2>/dev/null | tail -1 | sed -n 's/.*"customTitle":"\([^"]*\)".*/\1/p')
fi
[ -n "$AGENT" ] || exit 0
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // "."' 2>/dev/null)
COMMON=$(git -C "$CWD" rev-parse --git-common-dir 2>/dev/null) || exit 0
MAIN=$(cd "$CWD" && cd "$(dirname "$COMMON")" && pwd)
DIR="$MAIN/orchestration/agents/$AGENT"
[ -d "$DIR" ] || exit 0
TS=$(date '+%Y-%m-%d %H:%M:%S')
HEAD=$(git -C "$CWD" log --oneline -1 2>/dev/null)
DIRTY=$(git -C "$CWD" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
{ echo "# $AGENT — LAST_SNAPSHOT (auto; do not hand-edit)"; echo "- at: $TS"; echo "- commit: ${HEAD:-none}"; echo "- uncommitted: $DIRTY"; } > "$DIR/LAST_SNAPSHOT.md"
exit 0
```

`.claude/settings.json` wiring (merge into existing settings):
```json
{
  "hooks": {
    "Stop":         [{ "hooks": [{ "type": "command", "command": "$CLAUDE_PROJECT_DIR/orchestration/hooks/notebook-guard.sh" }] }],
    "TeammateIdle": [{ "hooks": [{ "type": "command", "command": "$CLAUDE_PROJECT_DIR/orchestration/hooks/notebook-guard.sh" }] }],
    "PreCompact":   [{ "matcher": "auto", "hooks": [{ "type": "command", "command": "$CLAUDE_PROJECT_DIR/orchestration/hooks/notebook-snapshot.sh" }] }],
    "SessionEnd":   [{ "hooks": [{ "type": "command", "command": "$CLAUDE_PROJECT_DIR/orchestration/hooks/notebook-snapshot.sh" }] }]
  }
}
```

### Agent bind (integration with `claude-code-sessions`, optional)
Setup writes this to `orchestration/agent-bind.sh` (`chmod +x`). It's the **bridge** the `claude-code-sessions` CLI wrapper calls *only if it exists* in the repo — so the two tools stay decoupled and re-couple only when orchestration is present. Given an agent name it: binds an **existing** agent (prints a system-prompt that points the session at its notebook), or for a **new** name asks once on the tty before creating the notebook from `_template`. Prompts go to the tty; only the bind text goes to stdout (so the wrapper can pass it via `--append-system-prompt`).
```bash
#!/usr/bin/env bash
# orchestration/agent-bind.sh <name>  -> prints system-prompt binding text on stdout (empty if none).
# Existing agent: bind. New name in an orchestration repo: confirm on tty, create from _template, bind.
name="$1"; [ -n "$name" ] || exit 0
root=$(git -C "$(pwd)" rev-parse --show-toplevel 2>/dev/null) || exit 0
AG="$root/orchestration/agents/$name"
if [ ! -d "$AG" ]; then
  tmpl="$root/orchestration/agents/_template"; [ -d "$tmpl" ] || exit 0
  [ -e /dev/tty ] || exit 0                                  # non-interactive: never auto-create
  printf "Agent '%s' has no notebook here. Create orchestration/agents/%s/ ? [y/N] " "$name" "$name" > /dev/tty
  read ans < /dev/tty
  case "$ans" in y|Y|yes|YES) ;; *) exit 0 ;; esac
  cp -R "$tmpl" "$AG"
  for f in "$AG"/*; do sed -i.bak "s/<agent>/$name/g" "$f" 2>/dev/null && rm -f "$f.bak"; done
fi
cat <<EOF
You are the "$name" agent for this repo. Before anything else, read your durable notebook:
orchestration/agents/$name/KNOWLEDGE.md, STATUS.md, MEMORY.md, LAST_SNAPSHOT.md — then continue from
STATUS. Update STATUS/MEMORY/DECISIONS as you work (a hook enforces a flush before you go idle).
EOF
```

### Compaction command (`/session-compact`)
Setup writes this to `.claude/commands/session-compact.md`. Typing `/session-compact` sends it as a prompt, so the agent flushes + trims its notebook, then asks you to run `/compact` (a command can't trigger `/compact` itself).
```markdown
Flush your durable notebook, then we compact. Steps:

1. Find your agent notebook: `orchestration/agents/<your-session-name>/`.
   If no such folder exists (you're not an orchestration agent), say so and stop.
2. Write your durables now:
   - **STATUS.md** — overwrite: current task, state, branch, last commit, next intended action.
   - **MEMORY.md** — append any non-obvious learning from this session (one line each), THEN trim:
     keep only the last ~20 entries; fold anything still durable into KNOWLEDGE.md and drop the rest.
   - **DECISIONS.md** — append non-obvious choices (one line: "chose A over B because X").
   - **KNOWLEDGE.md** — update only if your understanding of the domain materially changed.
3. Keep every entry terse; never duplicate what the code or STATUS already says.
4. Report exactly what you flushed/trimmed, then tell me: "Ready — run /compact."
```

### Project CLAUDE.md registry (lead discovery)
So any session — especially the lead — knows which agents exist and where their notebooks live, setup appends this block to the project's root `CLAUDE.md`:
```markdown
## Agent Orchestrator

This repo uses the Agent Orchestrator Protocol (`orchestration/PROTOCOL.md`). When asked to run agents / a team:
- **Roster + slices (who exists, what they own):** `orchestration/SLATE.md`
- **Each agent's notebook (identity, status, knowledge):** `orchestration/agents/<agent>/`
- **Lead bootstrap:** `orchestration/LEAD.md` · **Desks (worktrees):** `../<repo>-wt/<agent>/`

As lead: read `SLATE.md` to see which agents exist and what each owns, and read `agents/<agent>/STATUS.md` before assigning or respawning. Spawn each teammate with **agentType = its slice name** (so the notebook hooks resolve). On restart, respawn from the notebooks — never recreate them.
```

### Verify script
Setup writes this to `orchestration/verify.sh` (`chmod +x`). Run it from the repo root any time to confirm the scaffold + hooks are intact; exits non-zero if anything is missing.
```bash
#!/usr/bin/env bash
# Verify the Agent Orchestrator scaffold in this repo. Run from anywhere in the repo.
cd "$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "not a git repo"; exit 1; }
p=0; f=0
ck(){ if eval "$2"; then echo "  ok    $1"; p=$((p+1)); else echo "  FAIL  $1"; f=$((f+1)); fi; }
ck "orchestration/ exists"             '[ -d orchestration ]'
ck "SLATE.md + LEAD.md present"        '[ -f orchestration/SLATE.md ] && [ -f orchestration/LEAD.md ]'
ck "at least one agent notebook"       '[ -n "$(ls -d orchestration/agents/*/ 2>/dev/null | grep -v _template)" ]'
ck "every agent has STATUS.md"         '! ls -d orchestration/agents/*/ 2>/dev/null | grep -v _template | while read -r d; do [ -f "$d/STATUS.md" ] || echo x; done | grep -q x'
ck "hooks present + executable"        '[ -x orchestration/hooks/notebook-guard.sh ] && [ -x orchestration/hooks/notebook-snapshot.sh ]'
ck "settings.json is valid JSON"       '[ ! -f .claude/settings.json ] || python3 -c "import json;json.load(open(\".claude/settings.json\"))" 2>/dev/null'
ck "hooks wired in settings.json"      'grep -q notebook-guard .claude/settings.json 2>/dev/null'
ck "CLAUDE.md registry present"        'grep -qi "Agent Orchestrator" CLAUDE.md 2>/dev/null'
echo "  -> $p ok, $f failed"
[ "$f" -eq 0 ]
```

These are **not** part of the core setup. Reach for them only when you need them.

- **Split-panes / tmux view.** Want each agent in its own visible pane instead of one shared terminal? Switch the Agent Teams display mode to split-panes (uses tmux or iTerm2). **Same team, same automatic mailbox** — purely a viewing change. The structure (lead/agents, desks, notebooks, git flow) is identical, so you can move between in-process and split-panes at any time with no rework.
- **Persistent sessions vs transient teams.** Agent Teams is transient: one team at a time, cleaned up when done (no nested teams, no resume). The notebooks are the durable layer that makes this survivable — see **[Part 4](#part-4--persistence-restart--protecting-notebooks)** for the full persistence/restart/hooks design.
- **Pairs with `claude-code-sessions` (optional, independent).** That CLI kit manages *sessions* = Claude Code **conversations** (`claude <name>` to name/resume a chat, `claude ls`/`rm`). This protocol manages **agents** = a session **+** a durable notebook **+** a worktree desk. They share no files — the kit touches `~/.claude/projects/`, this touches `<repo>/orchestration/agents/` — so use either alone, or both together. Using both: name the conversation the same as the agent slice (`claude billing`), and the resumable chat (the kit's job) lines up with the durable `orchestration/agents/billing/` notebook (this protocol's job) into one persistent agent.
- **Subagents for sub-tasks.** Inside a single agent, use Claude Code subagents (the Task tool) for focused sub-jobs (research, review). They report back only to that agent. Don't nest teams.
- **Going bigger.** If you ever scale past a handful of active agents, keep the inactive ones parked (notebooks retained) rather than deleted, and watch token cost — multi-agent runs cost roughly linearly per active agent.

---

## The two rules (again, because they're everything)

1. **One owner per slice.** Split by feature, never by layer. No two agents edit the same files.
2. **Only the lead touches `main`.** Agents commit only to their own branch on their own desk.

Get these right and everything else — in-process vs split-panes, how many agents, which repo — is a swappable layer on top.
```
