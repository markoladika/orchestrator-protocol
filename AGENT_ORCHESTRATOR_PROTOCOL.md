# Agent Orchestrator Protocol

> A portable, repo-agnostic pattern for running multiple Claude Code agents on **one** codebase without them stepping on each other — a **tech lead** that coordinates and merges, plus as many **agent builders** as you need, each isolated on its own desk.
>
> **This file is both the spec and the installer.** Hand it to Claude Code in any git repo and say *"set this up for me"* — it will read the **[FOR CLAUDE CODE — SETUP](#for-claude-code--setup)** section and scaffold the structure for you. No tmux required.

---

## TL;DR — the mental model

- **Tech lead** = the foreman. Works on `main`. Plans with you, assigns work, reviews, merges. Does small/fast fixes inline; delegates anything bigger.
- **Agent** = a product builder. Owns one **vertical slice** (a whole feature end-to-end: backend + frontend + tests), not a tech layer.
- **Desk** = a **git worktree** — each agent's own private folder so their files/builds never collide.
- **Notebook** = each agent's coordination files (`orchestration/sessions/<agent>/`) — **shared**, on `main`, so everyone can read them.
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

- **Notebook** — small text files (identity, knowledge, status, backlog). **Shared, one copy, on `main`** so the lead and other agents can read it. → `orchestration/sessions/<agent>/`
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
    sessions/
      _template/                 ← notebook template copied per agent
      <agent-a>/                 ← agent A's notebook (shared, on main)
      <agent-b>/                 ← agent B's notebook
    worktrees.md                 ← desk registry: agent → worktree path → branch

<repo>-wt/                       ← DESKS live here, OUTSIDE the repo (siblings)
  <agent-a>/                     ← agent A's private code checkout, its own branch
  <agent-b>/                     ← agent B's private code checkout, its own branch
```

- **Notebook** → `<repo>/orchestration/sessions/<agent>/` (shared, on `main`)
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
- `orchestration/` with `LEAD.md`, `SLATE.md`, `worktrees.md`, and `sessions/_template/`.
- Copy this file to `orchestration/PROTOCOL.md` (or leave a one-line pointer to its source URL).
- Fill `SLATE.md` with the approved slices: agent name, scope, owned roots, status.
- Generate `LEAD.md` from the **[Lead bootstrap template](#lead-bootstrap-template)**, substituting the real repo path and slice list.
- Populate `sessions/_template/` from the **[Notebook template](#notebook-template-lean)**.

### Step 3 — Create each agent's notebook (shared)
For each approved slice, copy `sessions/_template/` → `sessions/<agent>/` and fill in: role, owned file/dir roots, where-to-learn-your-domain pointers (real entry points in this repo). Keep it **lean** — a router to the code, not a re-statement of it.

### Step 4 — Set up desks on demand (not all upfront)
Desks are created per slate, not permanently. Record the convention in `worktrees.md` and use, per active agent:
```bash
git worktree add <repo>-wt/<agent> -b <agent>/<short-task>     # create desk + branch
# ... agent works + commits in <repo>-wt/<agent> ...
git worktree remove <repo>-wt/<agent>                          # after merge
```
Add `<repo>-wt/` to `.gitignore` if it would ever land inside the repo path (it shouldn't — keep it a sibling).

### Step 5 — Wire the run
1. Confirm Agent Teams is enabled (Step 0.3). Default display mode: **in-process** (no tmux).
2. Show the human the **[loop](#part-3--running-a-slate)** and the **[Agent spawn prompt](#agent-spawn-prompt-template)** that the lead will send each agent — note that it tells each agent **its desk path** and **its notebook path** and **the two rules**.
3. Hand control back: the human (with the lead) plans the first slate and spawns the team.

### Step 6 — Confirm
Print a short summary: what was created, the active slices, how to start a slate, and how to flip to split-panes later. Do **not** push to any remote unless explicitly asked.

---

## Part 3 — Running a slate

1. **Plan with the human.** Lead proposes the slate (scope, slices, agents). Human approves.
2. **Spawn the team** (in-process). Lead spawns one agent per active slice, each with the spawn prompt.
3. **Each agent gets a desk.** `git worktree add <repo>-wt/<agent> -b <agent>/<task>`.
4. **Agents build** their slice end-to-end on their own branch; they read/write their **notebook** in the shared `orchestration/sessions/<agent>/`.
5. **Agents report** via mailbox when done (or blocked).
6. **Lead reviews** the diff. If good → `git cherry-pick <sha>` onto `main`. If not → send feedback via mailbox.
7. **Lead removes the desk** and assigns the next slice.
8. **Human ratifies** the final merge state (optional gate).

Only the lead touches `main`. Agents only touch their own branch/desk/notebook.

---

## Templates

### Notebook template (lean)
One small file is enough to start; split later only if it grows. `orchestration/sessions/_template/NOTEBOOK.md`:
```markdown
# <agent> — Notebook

**Slice (owns end-to-end):** <feature>
**Owned roots:** <dir/file roots — the ONLY files this agent edits>
**Desk:** <repo>-wt/<agent>   ·   **Notebook:** <repo>/orchestration/sessions/<agent>/

## Where to learn my domain
- <entry-point files / docs / tests in THIS repo>

## Status
- current task · state (active/blocked/done) · branch · last commit

## Decisions (append-only)
- <non-obvious choices: chose A over B because X>

## Knowledge (append-only)
- <gotchas, contracts, anti-patterns future-me should know>
```

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
- Send the Agent spawn prompt (tells it its slice, desk path, notebook path, rules).
- On done: review diff → git cherry-pick <sha> → git worktree remove <repo>-wt/<agent>.

## Reference
- Protocol: orchestration/PROTOCOL.md
- Current plan: orchestration/SLATE.md
- Desks: orchestration/worktrees.md
```

### Agent spawn prompt template
Lead sends this to each agent when spawning:
```
You are a builder agent on <repo>. You own ONE vertical slice end-to-end.

SLICE: <feature — what you own, backend + frontend + tests>
OWNED ROOTS: <the ONLY file/dir roots you may edit>
YOUR DESK (edit code here): <repo>-wt/<agent>/   ← your own worktree, your own branch
YOUR NOTEBOOK (read/write coordination here): <repo>/orchestration/sessions/<agent>/
   ← always the MAIN checkout copy, NOT the copy inside your desk

RULES (binding):
- Edit ONLY your owned roots. If you need to touch another slice's files, message the lead — don't edit.
- Commit ONLY to your own branch on your desk. Never touch main.
- Build the slice end-to-end with tests. Verify before reporting done.

WORKFLOW:
- Read your notebook first (role, owned roots, where-to-learn pointers).
- Do the work on your desk; commit to your branch.
- Update your notebook (status, decisions, knowledge) as you go.
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

---

## Appendix — Optional expansions

These are **not** part of the core setup. Reach for them only when you need them.

- **Split-panes / tmux view.** Want each agent in its own visible pane instead of one shared terminal? Switch the Agent Teams display mode to split-panes (uses tmux or iTerm2). **Same team, same automatic mailbox** — purely a viewing change. The structure (lead/agents, desks, notebooks, git flow) is identical, so you can move between in-process and split-panes at any time with no rework.
- **Persistent sessions vs transient teams.** Agent Teams is transient: one team at a time, spawned for a burst of work, cleaned up when done (no nested teams, no resume). The `orchestration/sessions/` notebooks are the *durable* home of each slice's identity/knowledge. Treat the notebooks as permanent and each team run as a temporary crew that reads them on spawn and writes back at close.
- **Subagents for sub-tasks.** Inside a single agent, use Claude Code subagents (the Task tool) for focused sub-jobs (research, review). They report back only to that agent. Don't nest teams.
- **Going bigger.** If you ever scale past a handful of active agents, keep the inactive ones parked (notebooks retained) rather than deleted, and watch token cost — multi-agent runs cost roughly linearly per active agent.

---

## The two rules (again, because they're everything)

1. **One owner per slice.** Split by feature, never by layer. No two agents edit the same files.
2. **Only the lead touches `main`.** Agents commit only to their own branch on their own desk.

Get these right and everything else — in-process vs split-panes, how many agents, which repo — is a swappable layer on top.
```
