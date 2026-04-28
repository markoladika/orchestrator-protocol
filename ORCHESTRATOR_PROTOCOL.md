# Orchestrator Protocol for Claude Code

> Multi-session coordinator + worker pattern with shared task and knowledge state. Sessions communicate via tmux; workers own their tracker rows; orchestrator pins durable knowledge.

**One human + one orchestrator session + N worker sessions, all touching the same repo, with minimal collisions and high throughput.**

## Architecture

```
Human  ──► approves plan + scope, makes architectural decisions
  │
  ▼
Orchestrator  ──► plans WITH human, defines worker sessions and per-session
                  scope, dispatches work, pins durable knowledge to memory
  │
  ▼
Worker sessions  ──► focused on a single domain (defined per-slate by the
                     orchestrator); own their tracker rows; mark items done
                     themselves; can invoke subagents for specialty work
  │
  ▼
Subagents  ──► .claude/agents/*.md specialists (e.g. backend-engineer,
               frontend-engineer, database-engineer, testing-engineer);
               invoked by workers on demand for focused tasks
```

---

## Table of contents

- [What this is](#what-this-is)
- [What you get](#what-you-get)
- [Prerequisites](#prerequisites)
- [⚡ Fast start (one prompt, ~2 minutes)](#-fast-start-one-prompt-2-minutes)
- [Quick start (10 minutes, manual)](#quick-start-10-minutes-manual)
- [The protocol explained](#the-protocol-explained)
- [Copy-paste prompts](#copy-paste-prompts)
  - [Bootstrap the coordinator](#1-bootstrap-the-coordinator)
  - [Bootstrap a worker session](#2-bootstrap-a-worker-session)
  - [Coordinator dispatching work](#3-coordinator-dispatching-work-template)
  - [Worker responding](#4-worker-responding-template)
- [Worked examples](#worked-examples)
- [Common pitfalls](#common-pitfalls)
- [Session rotation (resetting workers without losing state)](#session-rotation-resetting-workers-without-losing-state)
- [Adopting on your project](#adopting-on-your-project)
- [Why it works](#why-it-works)

---

## What this is

A single Claude Code session is bounded by:

- Its **context window** — gets truncated over a long day, loses precision
- Its **serial work model** — one task at a time
- Its **lack of empirical feedback** — code claims work without being verified

This protocol splits work across **specialized sessions** in parallel tmux panes. One session is the **coordinator**; the others are **workers** with focused domains (code review, agent-side, verification, security, frontend). The coordinator holds the canonical task list and surfaces decisions; workers execute focused work and report back.

In a typical engineering day on this protocol you can close ~30-50 tasks, ship multiple structural fixes, and run an empirical verification fixture that catches real bugs the moment they regress.

---

## What you get

In a single 18-hour day testing this protocol on a real production codebase:

- ~50 tasks closed
- 40+ file changes shipped
- 9 durable structural patterns pinned to persistent memory
- 4 P0 production-shape bugs caught + fixed (stuck worker, permission gate, RBAC vocabulary, formatter TypeError)
- 1 comprehensive database security audit (44 RPCs + all RLS policies + grants)
- 1 cross-tenant security gap fixed before reaching production
- 0 regressions to production
- 1 verification fixture validated as the structural defense layer

---

## Prerequisites

You need:

- **[Claude Code](https://docs.claude.com/en/docs/claude-code)** installed and authenticated (any Claude Code-compatible CLI works)
- **[tmux](https://github.com/tmux/tmux)** (most Linux/macOS systems have it; `apt install tmux` / `brew install tmux`)
- A codebase you want to work on (git repo, anything)
- Optional: persistent memory location (`~/.claude/...` or equivalent — see [Memory pinning](#memory-pinning))

That's it. No special framework, no installer.

You also need a `plans/` folder at repo root with `PLAN_TRACKER.md` and `PLAN_TRACKER_BUGS.md` (workers update these directly). If you don't have them yet, the orchestrator will help you bootstrap them in the planning phase below.

---

## How a slate begins

Before any worker session is created, the orchestrator + human define the work.

1. **Read state.** Orchestrator reads `plans/PLAN_TRACKER.md` and `plans/PLAN_TRACKER_BUGS.md` to understand what's already in flight, what's backlog, what's open.
2. **Propose a slate.** Orchestrator drafts: scope of work for the day/week, expected outcomes, estimated effort, candidate sessions to spawn (count + per-session domain).
3. **Human approves.** Plan + scope + session count. Orchestrator does NOT proceed without explicit approval.
4. **Define sessions.** Orchestrator decides domain per session — each session stays focused on its scope so its context doesn't get polluted with unrelated work. Domains are slate-specific (e.g. `claude-auth-refactor`, `claude-migrations`, `claude-fe-redesign`), not a fixed taxonomy.
5. **Write per-session prompts.** Orchestrator writes one bootstrap prompt per session, customized to that session's scope + the rows in `PLAN_TRACKER.md` it will own.
6. **Add slate rows to tracker.** Orchestrator writes Backlog rows to `PLAN_TRACKER.md` — these become each worker's inbox.

Only after step 6 does the orchestrator start spawning tmux sessions and dispatching work.

---

## ⚡ Fast start (one prompt, ~2 minutes)

**The fastest path: paste one prompt into a Claude Code session and let the coordinator handle the rest** — including discovering tmux, creating worker sessions, starting Claude Code in each, and messaging them.

Use this when:
- You already have tmux installed and running
- You don't want to manually create sessions
- You just want to start working in 2 minutes

### Step 1 — Open a Claude Code session

In any terminal:

```bash
claude
```

This becomes your **coordinator** session.

### Step 2 — Paste this prompt

Copy the entire block below (replace `{{PROJECT_NAME}}` and `{{REPO_PATH}}` first):

````
You are the coordinator session in a multi-session orchestration on this codebase.
I want you to bootstrap the entire setup yourself: discover tmux, create worker
sessions, start Claude Code in each, and brief each one with the protocol.

PROJECT:
- Name: {{PROJECT_NAME}}
- Repo: {{REPO_PATH}}
- Stack: {{STACK_SUMMARY — e.g. "Next.js + FastAPI + Postgres"}}

YOUR JOB RIGHT NOW (before any work tasks):

1. Run `tmux list-sessions` and `which tmux` to confirm tmux is available and
   see what sessions already exist.

2. Decide which worker sessions this project needs. Default starter set:
   - claude-eval    — code review, diagnosis
   - claude-tools   — agent-side / tools / skills (skip if no agent layer)
   - claude-onbtest — empirical verification (Playwright, DB queries)
   - claude-sec    — security work (skip if pre-launch / single-tenant)
   - claude-fe     — frontend (skip if no frontend)
   Skip sessions you don't need. Pick names that fit your project.

3. Create each tmux session in detached mode:
     tmux new-session -d -s claude-<role>
   Confirm each was created via `tmux list-sessions`.

4. Start Claude Code in each session. The send-keys + Enter pattern is
   two calls (text first with -l flag, then Enter as a separate call,
   never combined):
     tmux send-keys -t claude-<role> -l "claude"
     sleep 0.3 && tmux send-keys -t claude-<role> Enter
   Wait ~5 seconds for Claude Code to start in each session, then verify
   via `tmux capture-pane -t claude-<role> -p | tail -5` that it's at a
   prompt.

5. For EACH worker session, send the worker bootstrap prompt below
   (customized with that session's domain + specialty). Same two-call
   pattern: send the multi-line prompt body with -l flag, then Enter.

   --- WORKER BOOTSTRAP PROMPT (per worker session) ---
   You are a worker session in a multi-session orchestration with
   claude-coord (coordinator). Coordinator owns the canonical task list
   (numbered T-series). You execute focused work, push concise structured
   reports, and stand down between dispatches.

   YOUR DOMAIN: <domain — e.g. eval / tools / onbtest / sec / fe>
   YOUR SPECIALTY: <specialty — e.g. code review and diagnosis>
   YOUR SESSION SHORTNAME: <shortname — e.g. eval>

   COMMUNICATION:
   - Receive dispatches with [coord] tag from this coordinator session.
   - Push reports back via:
       tmux send-keys -t <coordinator-session-name> -l "[<shortname>] <message>"
       sleep 0.3 && tmux send-keys -t <coordinator-session-name> Enter
     Text first with -l flag, Enter as a SEPARATE second call.
   - Tag your pushes with your session shortname.

   REPORTING:
   - Push per-task or per-batch (coordinator specifies in dispatch).
   - Structure: SHIPPED / DIAGNOSIS / FILES / EMPIRICAL / FOLLOW-UPS.
   - End with "Standing down" or "Moving to T<N>".
   - Reference task IDs always (T<N>); coordinator owns numbering.
   - Surface bonus catches as candidate new T-series for coordinator.

   EXPECTATIONS:
   - Fail loudly — never silently swallow errors.
   - Empirically verify your fixes — smoke before declaring SHIPPED.
   - Catch related bugs while working — flag them in your report.
   - Discriminate "regression I caused" vs "latent bug I surfaced".
   - For schema-touching work, use migration files numbered sequentially.
   - For code-only work, target minimum LOC; structural-fix lens applies.

   PROJECT CONTEXT:
   - {{PROJECT_NAME}}
   - {{REPO_PATH}}

   Acknowledge with a one-liner ("ack, ready") and stand by for first dispatch.
   --- END WORKER BOOTSTRAP PROMPT ---

6. After dispatching the bootstrap prompt to each worker, poll their state
   with `tmux capture-pane -p` until each has acknowledged. Report back to
   me when all workers are ack'd and ready.

YOUR ONGOING ROLE (after bootstrap):

- Hold the canonical task list (numbered T-series) via TaskCreate / TaskUpdate.
- Dispatch focused work to worker sessions via tmux send-keys.
- Synthesize findings, surface decisions to me, pin durable patterns to memory.
- Re-route work when sessions are over-loaded.
- Run continuously; surface to me only when a decision is needed.

KEY MECHANICS:
- tmux send-keys two-call pattern: text with -l flag, THEN Enter as separate
  call. Combining leaves message unsubmitted.
- Tag outbound dispatches with [coord]. Workers tag inbound with their
  shortname.
- Memory location: {{MEMORY_PATH — e.g. "~/.claude/memory/<project>/" or
  leave blank if you don't have persistent memory}}.

WHEN TO SURFACE TO ME:
- New P0 findings, security issues, or anything I should triage.
- Architectural decisions needed (you analyze, I decide).
- Cross-session conflicts you can't resolve.
- Major slate completions worth reviewing.

CURRENT STATE:
- {{LIST_IN_FLIGHT_TASKS — or "No tasks yet, fresh start"}}
- {{TODAY'S_PRIORITIES — or "Awaiting first dispatch"}}

GO. Bootstrap tmux + workers now. Report when ready.
````

### Step 3 — Send the prompt and let it run

The coordinator will:

1. Discover your tmux state (`tmux list-sessions`, `which tmux`)
2. Create the worker tmux sessions for the domains your project needs
3. Start Claude Code in each session
4. Send each worker the bootstrap prompt (customized per domain)
5. Poll until all workers ack
6. Report back to you when ready

**Total time: ~2 minutes** of clock time + your initial paste.

### Step 4 — Dispatch your first work

Once the coordinator reports "all workers ready," dispatch your first task batch using the [Dispatch template](#3-coordinator-dispatching-work-template).

You're running.

> 💡 **If something goes wrong** during bootstrap, the coordinator will tell you what failed and ask. tmux not installed? Wrong path? It'll surface the issue rather than silently fail.

---

## Quick start (10 minutes, manual)

### Step 1 — Create your tmux sessions

Open a terminal and run:

```bash
# Create coordinator session (you'll attach to this most of the time):
tmux new-session -d -s claude-coord

# Create worker sessions (one per domain you need):
tmux new-session -d -s claude-eval        # code review, diagnosis
tmux new-session -d -s claude-tools       # agent-side / tools / skills
tmux new-session -d -s claude-onbtest     # empirical verification
tmux new-session -d -s claude-sec         # security work
tmux new-session -d -s claude-fe          # frontend implementation
```

Verify they exist:

```bash
tmux list-sessions
```

You should see all 6.

### Step 2 — Start Claude Code in each session

Attach to each session and start Claude:

```bash
# Attach to coordinator:
tmux attach -t claude-coord
# Inside the session, start Claude Code:
claude
# Detach with Ctrl+B then D

# Repeat for each worker session:
tmux attach -t claude-eval
claude
# Ctrl+B D

# ... etc for each worker
```

Each session now has Claude Code running, ready for prompts.

### Step 3 — Bootstrap the coordinator

Attach to the coordinator session:

```bash
tmux attach -t claude-coord
```

Paste the [Coordinator Bootstrap prompt](#1-bootstrap-the-coordinator) (replace `{{PLACEHOLDERS}}` with your project specifics).

The coordinator is now in role.

### Step 4 — Bootstrap each worker

For each worker session, attach and paste the [Worker Bootstrap prompt](#2-bootstrap-a-worker-session) (customize the `{{DOMAIN}}` and `{{SPECIALTY}}`).

Each worker acknowledges and stands by.

### Step 5 — Dispatch your first task

Back in the coordinator session, dispatch your first work batch using the [Dispatch template](#3-coordinator-dispatching-work-template).

You're running.

---

## The protocol explained

### Roles

| Role | Held by | Responsibility |
|---|---|---|
| **Human** | You | Approves plan + scope, makes architectural decisions, binding rules |
| **Orchestrator** | One Claude session (`claude-orch`) | Plans WITH human, defines worker sessions, dispatches work, pins durable memory |
| **Worker** | N Claude sessions (one per slate domain) | Executes focused work, owns its tracker rows, marks Done itself, reports back |
| **Subagent** | `.claude/agents/*.md` files | Stateless specialists invoked by workers on demand (backend, frontend, database, testing, etc.) |

### Worker session domains

Domains are **defined per-slate by the orchestrator**, not a fixed taxonomy. Each session stays focused on a single scope so its context doesn't get polluted with unrelated work.

Examples (from real slates):

| Session | Scope (this slate) |
|---|---|
| `claude-auth-refactor` | Rip out the old session-token middleware, replace with the new compliance-compliant one |
| `claude-migrations` | Add 3 numbered migrations + RLS policies for the new tables |
| `claude-fe-redesign` | Re-skin the chat view to Variant C, ship the new prose typography |
| `claude-test-recovery` | Repair the broken Playwright suite, re-register live tests in TEST_TRACKER |

Naming: short, purpose-named, scoped to the slate. When the slate ends, the session is killed; new slate = new sessions.

### Communication mechanism

All inter-session messages go via **tmux send-keys**.

> ⚠ **THE #1 TRAP**: combining text + Enter in one `send-keys` call leaves the message **in the input area unsubmitted**. The recipient never sees it. They keep working as if you said nothing. **Always TWO separate calls** — text first, Enter second. This is the most-common failure mode.

Two-call pattern, every time:

```bash
# Call 1: send the message body (with -l flag, NO Enter):
tmux send-keys -t claude-eval -l "[coord] Your message body here"

# Call 2: send Enter as a SEPARATE call to actually submit:
sleep 0.3 && tmux send-keys -t claude-eval Enter
```

**Symptom of forgetting the second call**: you push a long, important message; recipient seems to ignore it; you check tmux capture-pane and see your message text sitting in their input area, never submitted.

**Mitigation**: every push verb in your code should look like the two-call pair above. If you see only one `tmux send-keys` for an outbound message, the second is missing.

### Tagging convention

Every message uses a square-bracket sender tag at the start:

- `[coord]` — coordinator → worker (matches your coordinator session shortname)
- `[eval]`, `[tools]`, `[onbtest]`, `[sec]`, `[fe]` — worker → coordinator

Examples:
- `[coord] FIVE-ITEM BATCH dispatch — Marko greenlit T151 P0 ...`
- `[eval] T136 ROOT CAUSE FOUND in 60s — single-RPC action-vocabulary outlier ...`
- `[onbtest] BROADER-SWEEP DB-ONLY MATRIX — area 1 critical ...`

### Task ID system

The coordinator owns a single numbered T-series (T1, T2, ..., T199, ...). Workers reference task IDs in every push.

Sub-tasks use suffixes:
- Numbered slices: `T125-1`, `T125-2`, ..., `T125-8`
- Tightly-coupled follow-ups: `T172a` for "fix found while shipping T172"

Each task has:
- **Subject** — imperative title ("Drop defensive try/except wrappers around ArtefactWriter.create")
- **Description** — scope, rationale, owner, sequence
- **Status** — pending → in_progress → completed
- **Owner** — which session

Workers reference IDs in every report so the coordinator can update tracker state without re-reading conversation context.

### Tracker ownership

Workers own their rows in `plans/PLAN_TRACKER.md`. The orchestrator does NOT transcribe worker reports into the tracker — workers update it themselves as part of completing work.

| Action | Done by | When |
|---|---|---|
| Add Backlog rows for the slate | Orchestrator | Planning phase, before workers spawn |
| Move row Backlog → In Progress | Worker | When the worker starts the item |
| Move row In Progress → Done | Worker | In the same edit/commit as the work |
| Log a discovered bug to `PLAN_TRACKER_BUGS.md` | Worker | When the bug is found, before continuing |
| Register a test in `testing/TEST_TRACKER.md` | Worker (via testing-engineer subagent) | Before the plan moves to Done |

The orchestrator reads the tracker periodically to synthesize state — it does not mirror it from reports.

### Subagents

Workers can invoke subagents (`.claude/agents/*.md`) for focused specialty work. A subagent has its own context and returns a result to the worker; workers carry the session-level context.

Common subagents:

| Subagent | Use it for |
|---|---|
| `backend-engineer` | API endpoints, services, auth, error handling, server-side perf |
| `frontend-engineer` | Components, state, routing, styling, a11y |
| `database-engineer` | Schema, migrations, indexes, RLS, query plans |
| `testing-engineer` | Writes/runs tests, registers them in `TEST_TRACKER.md` |

Pattern: worker gets a dispatch from orchestrator → identifies a focused sub-task → invokes the relevant subagent with a one-paragraph brief → integrates the subagent's result → updates tracker → reports back to orchestrator.

Subagents are stateless across invocations. Only the worker session carries persistent context.

### Memory pinning

The orchestrator captures durable patterns to persistent memory. Recommended location:

```
~/.claude/memory/<project-name>/
  MEMORY.md                          # 1-line index of all entries
  reference_<topic>.md               # codebase facts / traps
  feedback_<rule>.md                 # binding rules from human
  project_<workstream>.md            # current state of major work
```

(Adapt path to your Claude Code memory setup.)

Pin a memory entry when:
- A pattern is caught for the **2nd time** (first = curiosity, second = trap)
- A binding rule is articulated by the human
- A non-obvious gotcha would cost future sessions time to rediscover
- A migration template emerges from successful work

---

## Copy-paste prompts

> **Replace `{{PLACEHOLDERS}}`** with your project specifics before pasting. Read each prompt before sending to make sure it matches your context.

### 1. Bootstrap the coordinator

Paste this into your coordinator session (`claude-coord`) at the start of the day or after `/clear`.

````
You are the coordinator session in a multi-session orchestration on this codebase.
Worker sessions are running in parallel tmux sessions. Your shortname is `coord`.

PROJECT:
- Name: {{PROJECT_NAME}}
- Repo: {{REPO_PATH}}
- Stack: {{STACK_SUMMARY — e.g. "Next.js 15 + FastAPI + Supabase"}}
- Key files: {{IMPORTANT_FILES — e.g. "CLAUDE.md, plans/PLAN_TRACKER.md"}}

WORKER SESSIONS AVAILABLE (tmux):
- claude-eval   — code review, diagnosis, audits
- claude-tools  — agent-side, tools, skills, registries
- claude-onbtest — empirical verification (Playwright, DB queries)
- claude-sec    — security work (migrations, RLS, RBAC)
- claude-fe     — frontend implementation
{{ADJUST: keep only sessions you actually have running}}

YOUR ROLE:
- Hold the canonical task list (numbered T-series, persistent across day)
- Dispatch focused work to worker sessions via tmux send-keys
- Synthesize findings, surface decisions to me, pin durable patterns to memory
- Re-route work when sessions are over-loaded; balance bandwidth across domains
- Run continuously; surface to me only when a decision is needed

COMMUNICATION:
- Use tmux send-keys (text via -l flag, THEN separate Enter call):
    tmux send-keys -t claude-<worker> -l "[coord] <message body>"
    sleep 0.3 && tmux send-keys -t claude-<worker> Enter
- Combining text + Enter in one call leaves the message unsubmitted. Always two calls.
- Tag your outbound dispatches with [coord]
- Workers tag inbound with their shortname; route accordingly

TASK MANAGEMENT:
- Use TaskCreate / TaskUpdate to maintain state
- Numbered T-series; sub-tasks use suffixes (T125-1, T125-2; T172a)
- Each task: subject (imperative), description (scope + rationale + sequence),
  status, owner

MEMORY:
- Pin durable patterns at {{MEMORY_PATH — e.g. "~/.claude/memory/<project>/"}}
- Update MEMORY.md index for each new entry
- Types: reference_*, feedback_*, project_*

WHEN TO SURFACE TO ME:
- New P0 findings or security issues
- Architectural decisions needed (you handle the analysis, I make the call)
- Cross-session conflicts you can't resolve
- Major slate completions worth reviewing
- Don't ping me for status updates I didn't ask for

CURRENT STATE:
- {{LIST_IN_FLIGHT_TASKS — or "No tasks yet, fresh start"}}
- {{ACTIVE_WORKERS_AND_DOMAINS}}
- {{TODAY'S_STRATEGIC_PRIORITIES}}

When you have ack from all worker sessions, dispatch the first slate.
````

### 2. Bootstrap a worker session

Paste this into each worker session at the start of the day or after `/clear`. Customize `{{DOMAIN}}` and `{{SPECIALTY}}` per session.

````
You are a worker session in a multi-session orchestration with claude-orch
(orchestrator). You execute focused work in your assigned scope, own your
rows in the project trackers, and report concise structured updates.

YOUR DOMAIN: {{DOMAIN — slate-specific, e.g. "auth-refactor", "migrations"}}
YOUR SCOPE: {{SCOPE — what this session is and isn't responsible for}}
YOUR SESSION SHORTNAME: {{SHORTNAME — e.g. "auth"}}

COMMUNICATION:
- Receive dispatches with [orch] tag from claude-orch
- Push reports back via:
    tmux send-keys -t claude-orch -l "[{{SHORTNAME}}] <message>"
    sleep 0.3 && tmux send-keys -t claude-orch Enter
  Text first with -l flag, Enter as SEPARATE second call. Combining them in
  one call leaves the message unsubmitted.
- Tag your pushes with your session shortname

TRACKER OWNERSHIP (you do this, not orchestrator):
- Read your rows from plans/PLAN_TRACKER.md (orchestrator pre-filled them)
- Move row Backlog → In Progress when you start
- Move In Progress → Done in the SAME commit as the work
- Log discovered bugs to plans/PLAN_TRACKER_BUGS.md before continuing
- Register tests in testing/TEST_TRACKER.md (use testing-engineer subagent)

SUBAGENTS AT YOUR DISPOSAL:
- backend-engineer  — API/services/auth/error handling
- frontend-engineer — components/state/routing/styling
- database-engineer — schema/migrations/RLS/query plans
- testing-engineer  — writes & runs tests, registers in TEST_TRACKER
Invoke via the Task tool with a one-paragraph brief. Subagents are stateless;
you carry the session context.

REPORTING:
- Push per-task or per-batch (orchestrator specifies in dispatch)
- Structure: SHIPPED / DIAGNOSIS / FILES / EMPIRICAL / TRACKER (rows updated) / FOLLOW-UPS
- End with "Standing down" or "Moving to <ID>" so orchestrator knows your state
- Reference plan IDs always; orchestrator owns slate-level numbering

EXPECTATIONS:
- Fail loudly — never silently swallow errors
- Empirically verify your fixes — smoke before declaring SHIPPED
- Catch related bugs while working — log to PLAN_TRACKER_BUGS, flag in your report
- Discriminate "regression I caused" vs "latent bug I surfaced"

MEMORY:
- Orchestrator pins durable patterns. Surface candidates in your reports
  ("MEMORY-WORTHY: X").
- Read existing memory before starting if uncertain about codebase conventions.

PROJECT CONTEXT:
- {{PROJECT_NAME}}
- {{REPO_PATH}}
- {{KNOWN_TRAPS_IN_YOUR_DOMAIN}}

Acknowledge with a one-liner ("ack, ready") and stand by for first dispatch.
````

### 3. Coordinator dispatching work (template)

When the coordinator dispatches to a worker, use this shape:

````
[coord] {{PRIORITY-LEVEL}} dispatch — {{ONE_LINE_CONTEXT}}

(1) T<N> — {{Title}}
SCOPE: {{what to build/fix/investigate}}
WHY: {{rationale or trigger event}}
FILES: {{expected file paths or modules}}
~{{LOC_estimate}}
EMPIRICAL: {{how to verify success}}

(2) T<M> — {{Title}}
... same shape ...

PRIORITY ORDER: {{serial vs parallel guidance}}
PUSH BACK: {{when to report — per-task / batch / on-blocker}}
NOTES: {{memory refs, related tasks, potential traps}}
````

### 4. Worker responding (template)

When a worker reports back, use this shape:

````
[{{shortname}}] T<N> SHIPPED — {{one_line_summary}}

ROOT CAUSE / DIAGNOSIS: {{if applicable}}

FILES:
  {{file_path_1}} — {{what changed}}
  {{file_path_2}} — {{what changed}}

EMPIRICAL: {{smoke evidence, test results, log proof}}

FOLLOW-UPS / NEW FINDINGS: {{captured for coordinator to track}}

Standing down. / Moving to T<M>.
````

---

## Worked examples

### Example dispatch (real, redacted from production use)

```
[coord] FIVE-ITEM BATCH dispatch — Owner greenlit + flagged T151 P0.
Take in this priority order:

(1) T151 SECURITY P0 — Owner directive: every RPC AND every endpoint
must do its own ensure_full_security_context check (org_id/user_id/JWT/
DB-membership), no delegating to downstream gate, Invoker-Definer
pattern non-negotiable.

SCOPE: (a) Trace EXACT missing check at /decisions endpoint in
chat_gateway.py — what's currently between request body parsing and
ApprovalWriter.decide call? (b) AUDIT all protected.*_protected RPCs.
(c) AUDIT all endpoints that call writer methods. (d) Fix /decisions:
add ensure_full_security_context check at request-validation time.
(e) REPORT BACK with audit findings.

(2) T100 — WIRE the shadow_intent_classifier.py module (~52 LOC, written
but not wired). One-line call after prod classifier resolves. Logs to
file (NOT DB) for easy iteration.

(3) T141 — per-call llm.call.completed event. ARCHITECTURAL DECISION:
emit from INSIDE adapter ainvoke (try/finally), NOT from scope-close.
Adapter is the single seam. ~80 LOC.

(4) T133 — dev watchdog auto-restart sidecar. ~50 LOC python +
1 systemd timer.

(5) T150 — sweep all writers for 'await db_conn.execute' + 'return True'
pattern. Defensive cleanup.

T151 first + AUDIT REPORT urgent. Push back per item or batch.
```

### Example worker response (real, redacted from production use)

```
[eval] T136 ROOT CAUSE FOUND in 60s — single-RPC action-vocabulary outlier.

EXACT RPC THAT RAISED:
  protected.artefacts_create_protected
    → public.ensure_full_security_context(user_id, 'artefact', 'create', NULL)

EXACT PERMISSION MISSING:
  public.permissions catalog has TWO entries for resource='artefact':
  artefact.crud + artefact.view. There is NO artefact.create permission
  registered. The RPC asks for an action that doesn't exist in the catalog
  → check_rbac_permission returns FALSE → ensure_full_security_context
  raises FORBIDDEN.

DEFINITIVE EVIDENCE — action vocabulary across all 8 artefact RPCs:
  artefact_get_internal      → 'view'   ✓
  artefact_list_internal     → 'view'   ✓
  artefact_delete_internal   → 'crud'   ✓
  ...
  artefacts_create_protected → 'create' ✗ THE OUTLIER

FIX: one-line migration changing 'artefact','create' → 'artefact','crud'
in artefacts_create_protected. ~10 LOC migration.

T136 closes deterministic 5/5 failure.
Want me to ship Step 1+2 in one slate now?
```

The report is dense, evidence-bearing, and ends with a clear next-step ask. The coordinator can act on it immediately.

---

## Common pitfalls

These are real mistakes from refining this protocol. Avoid them.

### 1. Coordinator over-batching dispatches

Tempting to send a 10-item batch. Workers lose precision past ~5 items.
**Mitigation:** 3-5 items per dispatch; queue more after first ones land.

### 2. Worker silent partial-success

Worker reports "T<N> SHIPPED" but the empirical smoke was incomplete. Coordinator inherits an unverified claim.
**Mitigation:** every SHIPPED report MUST include empirical evidence (smoke output, test result, log line).

### 3. Coordinator over-surfacing to human

Surfacing every status update fragments human attention.
**Mitigation:** surface only decision-needed items. Status is captured in the task list; human can read on demand.

### 4. Sessions duplicating work

Two workers pick up adjacent tasks without coordinating.
**Mitigation:** coordinator owns task ownership in the tracker; dispatch one task per worker; route bandwidth.

### 5. Memory pinning lag

Pattern caught, fix shipped, but memory not updated. Future sessions re-discover the trap.
**Mitigation:** pin memory in the same response cycle as the closing TaskUpdate.

### 6. Combining tmux text + Enter

`send-keys -t session "text" Enter` leaves the message unsubmitted.
**Mitigation:** text first with `-l` flag, Enter as a SEPARATE second call. Always two calls.

### 7. Worker over-scoping

Worker grows a 1-line fix into a 200-LOC refactor.
**Mitigation:** scope in the dispatch ("~30 LOC, surgical"). Worker pushes back if scope reveals more.

### 8. Lack of empirical verification fixtures

Code claims "fixed" but never empirically tested.
**Mitigation:** establish a `*-VERIFY` fixture (Playwright spec or Python harness) early — fires the real flow + checks DB/spine state. The fixture is the structural defense layer.

---

## Session rotation (resetting workers without losing state)

Worker sessions accumulate context over a long day. Past ~80% context, they slow down + burn more tokens per turn. **Rotation = save state, kill, recreate, re-bootstrap with state restored.** The coordinator orchestrates so nothing is lost.

### When to rotate

- Worker context > 80% (visible in their session footer)
- Mid-day if multiple long investigations have accumulated
- End of day before stand-down if the next day starts fresh
- After a major slate ships (clean break + fresh start for next phase)

### When NOT to rotate

- Mid-Playwright run (let it complete)
- Mid-migration (one full migration applied + verified is the unit, don't kill mid-apply)
- Mid-audit-batch (let the report land)

### The rotation protocol

**Step 1 — Coordinator sends `PRE-ROTATION STATE-SAVE` prompt to the worker:**

````
[coord] PRE-ROTATION STATE-SAVE — context is high (~XX%). I'm rotating you to a fresh session to save tokens. Before that:

(1) STOP picking up new work.
(2) If mid-fix, finish to a CLEAN BREAK (don't leave half-applied edits or half-tested fixes).
(3) Push back state-summary in this structure:

  ACTIVE TASK IDS: <T-numbers you own + status — e.g. "T172a in flight, T165 queued, T173 done">
  IN-FLIGHT PROGRESS: <what's done vs pending in current task>
  DISCOVERED KNOWLEDGE: <anything you've learned NOT yet in tracker descriptions or memory — a finding, a gotcha, a partial diagnosis>
  FILES MODIFIED / WIP: <any uncommitted edits you have open, file paths>
  OPEN QUESTIONS: <anything you were going to surface to coordinator>
  RESUME INSTRUCTIONS: <what fresh session needs to know to continue your domain seamlessly>

After you push the summary, stand by. I will: (a) capture your state summary, (b) kill this tmux session, (c) recreate fresh tmux session same name, (d) start claude there, (e) re-bootstrap with protocol + your state summary baked in. The fresh session resumes from where you left off. Push state-summary when you've reached a clean break.
````

**Step 2 — Worker responds with state-summary** (in the structured format above), then stands by.

**Step 3 — Coordinator captures the summary**, verifies nothing critical is missing (compare against the task tracker — does the worker's state summary match what the tracker shows is in-flight for them?). If anything is missing, ask one follow-up before proceeding.

**Step 4 — Coordinator kills + recreates the tmux session:**

```bash
# Kill the existing session:
tmux kill-session -t claude-<role>

# Recreate fresh:
tmux new-session -d -s claude-<role>

# Start Claude Code:
tmux send-keys -t claude-<role> -l "claude"
sleep 0.3 && tmux send-keys -t claude-<role> Enter

# Wait ~5s for boot:
sleep 5

# Verify ready:
tmux capture-pane -t claude-<role> -p | tail -5
```

**Step 5 — Coordinator dispatches a `RESUME BOOTSTRAP` prompt** combining the [Worker Bootstrap prompt](#2-bootstrap-a-worker-session) WITH the captured state-summary at the bottom:

````
[coord] PROTOCOL INIT + STATE RESUME — you are picking up a rotated session.

<full Worker Bootstrap prompt — domain, communication, reporting, expectations, project context — same as fresh bootstrap>

PRIOR SESSION STATE (your previous self saved this before kill):

  ACTIVE TASK IDS: <captured>
  IN-FLIGHT PROGRESS: <captured>
  DISCOVERED KNOWLEDGE: <captured>
  FILES MODIFIED / WIP: <captured>
  OPEN QUESTIONS: <captured>
  RESUME INSTRUCTIONS: <captured>

Acknowledge with one-liner ("ack, ready, resuming T<N>") and stand by. The first dispatch will route based on your resume instructions.
````

**Step 6 — Worker acknowledges in fresh session.** Coordinator dispatches the next work batch picking up from RESUME INSTRUCTIONS.

### What's safe to lose vs preserve

**Safe to lose** (recoverable from coordinator's tracker / memory):
- General project context (in CLAUDE.md / memory)
- Task descriptions + status (in tracker)
- Past completed work history (in tracker)
- Memory patterns (in memory directory)
- The protocol itself (in PROTOCOL.md)

**Must preserve** (only in worker's session context):
- Mid-investigation state (e.g. "I traced the bug to file X line Y, was about to fix Z")
- Discovered knowledge not yet pinned (e.g. found a gotcha but didn't push back yet)
- Uncommitted edits in worker's editor state
- Open questions/findings the worker was going to surface

The state-summary structure forces the worker to externalize the "must preserve" items.

### Validation: did the rotation work?

After re-bootstrap:
- Coordinator dispatches a small task that depends on resume context
- If worker picks it up cleanly → rotation succeeded
- If worker says "I don't have context for this" → rotation lost something, reconstruct from tracker + memory + repeat the dispatch with explicit context

### Files / data NOT lost during rotation

These persist across rotation because they're durable state:
- Git repo (uncommitted edits SHOULD be committed before rotation if non-trivial)
- Database state (migrations are persistent)
- Memory directory (persistent files)
- Task tracker (persistent state)
- PROTOCOL.md + plan docs (in repo)

The tmux session being killed only affects the worker's in-memory conversation context. Everything else survives.

---

## Adopting on your project

Before adopting:

- [ ] Decide which worker session domains your project needs (don't spawn all 5 if you don't need them)
- [ ] Write your **binding rules** first (your "no defensive try/except" + "fail loudly" + style invariants)
- [ ] Bootstrap memory directory with at least: collaboration style, codebase conventions, known traps
- [ ] Create initial T-series tasks before opening dispatch (don't dispatch on empty tracker)
- [ ] Establish the **empirical verification fixture** early — this is your structural defense
- [ ] Run for 1 day, then refine the dispatch templates with what worked

The protocol is a starting point, not a fixed shape. Each project will refine it.

### Tuning for your team size

| Team size | Recommended |
|---|---|
| Solo dev | Coordinator + 2 workers (eval + verification) |
| Small team (2-3 humans) | Coordinator + 3-4 workers |
| Larger | Coordinator + 4-5 workers + per-team specialists |

### Tuning for your codebase

If your project has:
- **Heavy backend / multiple services** → eval + tools + sec
- **Frontend-heavy** → fe + onbtest + eval
- **DB-heavy** → sec + tools + eval
- **Pre-launch / experimental** → onbtest as the verification fixture is critical
- **Production-critical** → sec is non-negotiable

---

## Why it works

Multi-session orchestration is not magic. It works because:

1. **Each session has focused context** — workers don't carry the full project history; they carry their domain. The coordinator carries the high-level state but delegates depth.

2. **Structured communication forces precision** — the dispatch template + response template + ID system make every message dense and actionable. No conversational drift.

3. **Empirical verification is the structural defense** — bugs caught by fixtures don't reach production. The fixture is a piece of code, not a guess.

4. **Memory is durable** — patterns pinned to memory persist across sessions, days, even teams. You don't re-derive lessons every Monday.

5. **The human stays in the architectural loop** — humans make decisions where judgment matters; sessions execute where precision matters. Surface only what needs the human.

In a single 18-hour day on this protocol the team caught 4 P0 bugs, shipped 9 structural fixes, ran a comprehensive security audit, and prevented a cross-tenant data leak from reaching production. The coordinator session never lost track of the 50+ tasks in flight. Workers had focused, productive runs. The human reviewed only decision-needed surface.

---

## Files / locations

- **Memory directory** (per-project, persistent): `~/.claude/memory/<project>/` (or your equivalent)
- **Plan tracker** (master, in repo): `<project>/plans/PLAN_TRACKER.md`
- **Detailed plan docs** (per-feature): `<project>/docs/plans/`
- **Memory index**: `MEMORY.md` in the memory directory
- **Binding rules**: `feedback_*.md` files in the memory directory

---

## License

This protocol is offered under [MIT License](https://opensource.org/licenses/MIT) — adopt, adapt, fork freely.

If you find it useful, consider sharing what you refine. The protocol is a living shape; what works for one project will inform what works for another.

---

## Credits

Developed and refined during engineering work on the [Producting.ai](https://producting.ai) platform, 2026-04-27. Refined by an extended Claude Code session pairing 1 human + 1 coordinator + 5 worker sessions over an 18-hour day.

Originating concepts: tmux for inter-session communication, Claude Code's TaskCreate/TaskUpdate for persistent task state, durable memory for cross-session pattern retention.

Specific gotchas captured (e.g. the tmux send-keys two-call submit pattern, the "registered ≠ runtime usage" trap, the silent-swallow defensive try/except anti-pattern) come from real production work where these mistakes cost real time before being captured as memory.
