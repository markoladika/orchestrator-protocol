---
---

```

                              C L A U D E  C O D E

                    ███████╗ ███████╗ ████████╗ ██╗   ██╗ ██████╗
                    ██╔════╝ ██╔════╝ ╚══██╔══╝ ██║   ██║ ██╔══██╗
                    ███████╗ █████╗      ██║    ██║   ██║ ██████╔╝
                    ╚════██║ ██╔══╝      ██║    ██║   ██║ ██╔═══╝
                    ███████║ ███████╗    ██║    ╚██████╔╝ ██║
                    ╚══════╝ ╚══════╝    ╚═╝     ╚═════╝  ╚═╝

        From Zero to Orchestrating autonomous sessions in 60 Minutes

                    Step-by-step setup with copy-paste prompts.
```

---

# What This Setup Will Bring You

After ~60 minutes of setup, you get:

- ⚡ **3x rate limit headroom** — multi-account routing via simple bash wrappers
- 📡 **Code from anywhere** — laptop, iPad, phone — sessions persist across disconnect
- 🧠 **AI agents in parallel** — orchestrator dispatches to focused worker sessions
- 🌙 **Autonomous overnight runs** — schedule triggers + auto-resume = wake up to shipped code
- 📋 **PM-driven workflow** — Plan Tracker, Bug Tracker, Architecture rules baked into every change

**One-time setup. Pays back forever.**

## Want Claude Code to walk you through it?

Paste this into a Claude Code session:

```
Read https://github.com/markoladika/orchestrator-protocol/blob/main/Setup-Guide.md
and walk me through every step.

Create a task list with one task per Step (0–7). Execute in order.
For each step: tell me where to run it (laptop / server / per-project),
ask for any inputs you need (VPS IP, account number, project path),
run the prompts, confirm success before moving on.
Pause for my approval on anything external (VPS, Tailscale signup, auth).
```

---

# Setup Order — Overview

Run these in sequence. Each step builds on the previous.

| # | Setup                      | Time   | Notes                       |
|---|----------------------------|--------|-----------------------------|
| 0 | Claude Code installed      | —      | Prerequisite                |
| 1 | Statusline                 | 5 min  | Required · visibility       |
| 2 | Robo-Talk                  | 2 min  | Recommended · less noise    |
| 3 | Multi-account              | 5 min  | Recommended · 3x headroom   |
| 4 | Remote server + Tailscale  | 15 min | Required · any device       |
| 5 | Persistent sessions (tmux) | 10 min | Required · stay alive       |
| 6 | PM framework               | 10 min | Required · trackers + rules |
| 7 | Orchestrator mode          | 5 min  | Required · runs the show    |

> **Required items are needed for autonomous work.**

> Every step has a **Claude Code prompt** (preferred) and a **manual command** (optional fallback). You can do the entire setup by pasting prompts.

> **Two orchestration variants — this guide builds toward Variant A.**
> The full setup above (remote server + tmux persistent sessions) is for **Variant A — tmux coordination**: persistent multi-account sessions, autonomous overnight runs, code from any device.
> If you only want **local parallel building on one machine**, use **Variant B — worktrees + Agent Teams** (`AGENT_ORCHESTRATOR_PROTOCOL.md`). Variant B needs **no tmux and no server** — so you can **skip Steps 4 and 5** — and it sets itself up. Do still do **Step 6 (PM framework)**; it benefits both. Then jump to the Variant B option in Step 7.

---

# Step 0 — Prerequisite: Install Claude Code

## What you do

Install Claude Code on your machine and authenticate. This is the only command you need — everything from Step 1 onward runs through Claude Code.

## Install

```bash
curl -fsSL https://claude.ai/install | sh
claude auth login
```

> Verify: `claude --version` prints something like `2.1.121 (Claude Code)`.

---

# Step 1 — Statusline

## What you do

Set up the statusline so you can see context %, rate limits, and model at a glance — your dashboard before you have a dashboard.

## Prompt (paste in any Claude Code session)

```
/statusline show model, context %, 5h and 7d rate limits with bars and reset times, curretn model used
```

Claude Code generates the script, makes it executable, saves it to `~/.claude/`, and updates `~/.claude/settings.json` automatically. Applies to every project on this machine.

> Verify: open any Claude Code session — statusline appears at the bottom showing `ctx 42% | 5h ████░░░░░░ 48%: 3pm | 7d ████░░ 40% | Opus 4.7 (1M context)`.

---

# Step 2 — Install Robo-Talk (Cut Token Noise)

## What you do

Install the Robo-Talk output style. Cuts ~60% of Claude's prose: no "great question", no "let me explain", no walls of filler. Status codes + short lines instead.

## Prompt (in Claude Code)

```
Install Robo-Talk from github.com/markoladika/robo-talk by running 
the installer script. After install, verify by checking ~/.claude/
output-styles/ for robo-core-minimal.md and ~/.claude/settings.json
for "outputStyle": "Robo Core". Then tell me how to toggle on/off.
```

## Optional — manual install (one-liner)

```bash
curl -fsSL https://raw.githubusercontent.com/markoladika/robo-talk/main/install.sh | bash
```

## Toggle

```
/robo on            # enable
/robo off           # back to default
```

> Verify: send any message → Claude responds starting with `[STATUS]` and stays under 2 lines of prose.

---

# Step 3 (1/2) — Multi-Account Wrappers (`claude01`, `claude02`)

## What you do

Create per-account wrappers so you can route work to different Anthropic accounts (3x your rate limit headroom). Original `claude` command stays untouched.

## Prompt (in Claude Code) — repeat for each account (01, 02, 03...)

```
Set up an additional Claude Code account on this machine.
Account number: 01     ← change to 02, 03... for each new account

Constraints:
- DO NOT use Edit/Write on ~/.bashrc directly. The harness blocks
  edits containing --allow-dangerously-skip-permissions. Use a
  user-executed installer script at /tmp/install_claude01.sh.
- DO NOT modify the base "claude" command — leave it pointing
  to the raw binary.

The function "claude01" should support:
  claude01 sessionName              → HOME=~/.claude01 claude --name sessionName
  claude01                          → HOME=~/.claude01 claude
  claude01 auth                     → HOME=~/.claude01 claude auth login
  claude01 sessionName --bypass     → above + appends
                                      --allow-dangerously-skip-permissions
                                      (adds bypass to Shift+Tab cycle —
                                      INTERACTIVE: human toggles it)
  claude01 sessionName --auto-bypass → above + appends
                                      --dangerously-skip-permissions
                                      (starts IN bypass mode —
                                      AUTONOMOUS: for orchestrator-spawned
                                      worker sessions that have no human
                                      to press Shift+Tab)
  claude01 --bypass / --auto-bypass → same idea, no session name
Accept "-b" as short alias for "--bypass" and "-B" for "--auto-bypass".
Use "command claude" inside the function to avoid recursion.

Steps:
1. Create directory ~/.claude01/.claude.
2. Write installer at /tmp/install_claude01.sh that removes any
   existing claude01 block from ~/.bashrc (sed) and appends the
   new function.
3. chmod +x /tmp/install_claude01.sh.
4. Tell me to run: bash /tmp/install_claude01.sh && source ~/.bashrc
5. Then I run "claude01 auth" to authenticate.
```

---

# Step 3 (2/2) — Multi-Account: Manual Fallback

## Optional — manual install (single account, no installer trick)

If you'd rather hand-edit, append this directly to `~/.bashrc`:

```bash
# Claude Code account 01
claude01() {
  local extra=() positional=()
  for arg in "$@"; do
    case "$arg" in
      --bypass|-b)       extra+=(--allow-dangerously-skip-permissions) ;;  # interactive: bypass in Shift+Tab cycle
      --auto-bypass|-B)  extra+=(--dangerously-skip-permissions) ;;        # autonomous: starts IN bypass
      *)                 positional+=("$arg") ;;
    esac
  done
  if [ "${positional[0]}" = "auth" ]; then
    HOME=~/.claude01 command claude auth login
  elif [ -n "${positional[0]}" ]; then
    HOME=~/.claude01 command claude --name "${positional[0]}" "${extra[@]}"
  else
    HOME=~/.claude01 command claude "${extra[@]}"
  fi
}
```

Then:

```bash
mkdir -p ~/.claude01/.claude
source ~/.bashrc
claude01 auth        # authenticate the new account
```

> Verify: `type claude01` shows the function. `claude` still runs raw binary.

---

# Step 4 (1/2) — Remote Server + Tailscale: Why

## Why a server (VPS or Mac mini)?

- **Autonomous work** — Claude keeps coding when your laptop is closed
- **No heat / no battery drain** — long sessions don't roast your MacBook
- **Persistent state** — sessions live on the server, survive disconnects
- **Mobile access** — check or steer progress from your phone

Pick one:

| Option | Setup | Cost | Notes |
|--------|-------|------|-------|
| **VPS** (Hostinger / DigitalOcean) | 15 min | ~€8/mo | Public IP, ready in minutes |
| **Mac mini at home** | 1-2 hours | One-time hardware | Repurposes existing kit, lives on your home network |

## Why Tailscale?

- **Encrypted tunnel** between all your devices (laptop, phone, server)
- **Reach Mac mini at home** — bypasses your home router, no port-forwarding
- **Magic DNS hostnames** — `ssh server` instead of `ssh 76.13.x.x`
- **Same connection from anywhere** — coffee shop, train, hotel, all work

> **Do you need Tailscale on a VPS too?**  
> **Mac mini → required.** Home networks have no public IP; Tailscale is the only way in.  
> **VPS → optional but recommended.** A VPS already has a public IP and exposed SSH, so you *can* connect directly. Adding Tailscale lets you firewall off port 22 from the public internet (no brute-force surface) and gives you the same access pattern as the Mac mini.

---

# Step 4 (2/2) — Remote Server + Tailscale: How

> **Prerequisite:** sign up free at `tailscale.com` — use the **same account** on every device (server, laptop, phone). Otherwise they won't see each other.

## Prompt 1 — SSH alias (paste into Claude Code on your laptop)

Replace `ServerName` and the IP with yours:

```
Set up an SSH alias on this Mac so I can connect to my VPS with
one short command.

Server alias: ServerName
VPS IP:       <your-vps-ip>
Login user:   root
Key file:     ~/.ssh/id_ServerName

1. Append a Host entry to ~/.ssh/config (create if missing,
   chmod 700 ~/.ssh and 600 the config file).
2. If ~/.ssh/id_ServerName does not exist, generate a new ed25519
   key pair with no passphrase, then print the .pub contents and
   tell me to paste it into the VPS hPanel "SSH Keys" section.
3. After I confirm the .pub is added, test with:
   ssh ServerName "hostname && uptime"
4. Report success or the exact error.
```

## Prompt 2 — Tailscale (paste on the server via ssh)

```
Install Tailscale on this machine (detect the OS — Linux or macOS — 
and use the right installer). Run "tailscale up" and show me the 
login URL. After login, show me my Tailscale IP and the magic-DNS 
hostname so I can SSH to this machine from other devices on my tailnet.
```

## Optional — manual

```bash
# SSH alias on laptop
cat >> ~/.ssh/config <<'EOF'
Host my-vps
    HostName <your-vps-ip>
    User root
    IdentityFile ~/.ssh/id_my-vps
    IdentitiesOnly yes
EOF
chmod 600 ~/.ssh/id_my-vps

# Tailscale on the server
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

> Verify: from your phone (with Tailscale on + Termius/Blink), `ssh <tailscale-hostname>` connects to the server.

---

# Step 5 — Persistent Sessions (tmux)

## What you do

Install tmux on the remote server and **wrap it around the existing `claudeNN` wrappers from Step 3** (don't replace them — extend them). Result: `claude01 sessionName` creates or reattaches a tmux session with Claude Code already running inside, and the `--bypass` flag still works. Sessions survive disconnect — close laptop, work continues.

## Prompt — tmux + claude wrapper integration (paste on the remote server via ssh)

```
I have one or more "claudeNN" account wrappers in ~/.bashrc (e.g.
claude01) plus the base "claude" command. Add tmux integration to
all of them so running "claude01 sessionName" creates or reattaches
a tmux session "claude01-sessionName" with Claude Code running inside.

IMPORTANT — read ~/.bashrc FIRST to see what's already there:
account wrappers, existing flags like --bypass / -b, anything else.
Reuse the existing conventions — DO NOT regress current behavior,
including the bypass handling. Build tmux on top of the existing
function; don't overwrite it from scratch.

Constraints:
- Don't Edit/Write ~/.bashrc directly. Use a /tmp installer.
- Inside functions, use "command claude" and "command tmux" so the
  wrapper does not recurse into itself.
- Handle "already inside tmux" with switch-client, not attach.
- Make it idempotent and multi-account-safe.

Install tmux first if missing. Propose your plan in one short message
before writing the installer, so I can sanity-check the session-naming
scheme and confirm the existing wrapper behavior is preserved. After
I approve, write the script, tell me the one command to run, and
verify with: type claude01 && tmux -V. I will test the interactive
launch myself.
```

## Optional — manual install (package only)

```bash
sudo apt install tmux                # Linux (Debian / Ubuntu)
brew install tmux                    # macOS
```

> If you go manual: you also need to **edit your existing `claude01` function from Step 3** to wrap each `command claude ...` invocation with `tmux new-session` / `tmux attach` logic. Keep the `--bypass` argument parsing intact. The Claude Code prompt above does this for you correctly.

> Verify: `claude01 test` opens a tmux session named `claude01-test` with Claude Code running. `claude01 test --bypass` still works. `tmux ls` lists active sessions.

---

# Step 6 (1/4) — Plan Tracker + Bug Tracker

You're acting as the PM. Every project needs a tracking system:

| Artifact | Where | What it does |
|----------|-------|-------------|
| **Plan Tracker** | `plans/PLAN_TRACKER.md` | Index of every feature/refactor in flight |
| **Bug Tracker** | `plans/PLAN_TRACKER_BUGS.md` | Severity-tagged bug list; logged before fix starts |
| **Plan template** | `plans/TEMPLATE_plan.md` | Per-feature spec: Goal · Acceptance · Tasks · Verification |

## Prompt (paste in a Claude Code session at the project root)

```
Set up a plan-tracking system for this project.

1. Create folder "plans/" at the project root.
2. Inside plans/, create TEMPLATE_plan.md with sections:
   ID · Category (Feature|Refactor|Infra|Docs|Spike) · Status
   (Backlog|In Progress|Blocked|Done) · Owner · Created · Goal
   · Acceptance · Approach · Tasks · Verification · Notes.
3. Create plans/PLAN_TRACKER.md — single table grouped by 
   Category, columns: # | Category | Title | Brief | Status | Plan
   The Plan cell links to the detail file: [P-007](./P-007-name.md)
   Pre-fill one example row.
4. Create plans/PLAN_TRACKER_BUGS.md — same shape but for bugs.
   Columns: # | Severity | Title | Repro | Status | Fix Plan
   Severity: P0/P1/P2/P3. Status: Open|Investigating|Fixed|Wontfix.
5. Append a "Workflow" section to project CLAUDE.md enforcing:
   - Every new work item: row in PLAN_TRACKER + dedicated plan file
   - Every bug: row in PLAN_TRACKER_BUGS before fix starts
   - Status transitions ship in the same commit as the work
   - IDs sequential: P-001, P-002... and B-001, B-002...
6. Show me the resulting tree under plans/ + the new CLAUDE.md
   section as a diff.
```

---

# Step 6 (2/4) — Architecture Rules in CLAUDE.md

5 categories of imperatives, encoded so every change respects them:

| Category | Rule of thumb |
|----------|---------------|
| **Modularity** | One file = one responsibility · explicit public API |
| **Reusability** | Search before writing · rule of two (2+ places → extract) |
| **DRY / SoT** | Defined once, imported everywhere · rename = one-file edit |
| **Clean Arch** | Data → service → UI · imports inward · side effects at edges |
| **Change-discipline** | No drive-by refactors · log violations as Refactor plans |

## Prompt (paste in a Claude Code session at the project root)

```
Add an "Architecture Principles" section to the project CLAUDE.md.
Apply to every change Claude Code makes in this repo. Imperatives,
short, no fluff. Include:

MODULARITY
- One module = one responsibility. If a file does two things, split.
- Public API is explicit (named exports / __all__). Internals private.
- No cross-module state. Pass data, don't reach into siblings.

REUSABILITY
- Search the codebase before writing a helper. Extend, don't fork.
- 2+ places = extract. 1 place = leave inline (no premature abstraction).
- Generics live in shared/ or lib/. Domain logic stays per-feature.

SINGLE SOURCE OF TRUTH (DRY)
- Constants, enums, types: defined once, imported everywhere.
- Schema (DB, API, validation) generated from one definition.
- Renaming a contract = one-file edit. Editing 3 places = refactor smell.

CLEAN ARCHITECTURE
- Data layer / business logic / UI never bleed into each other.
- Side effects (network, FS, time, randomness) live at the edges.
- Imports point inward: UI → service → data, never reverse.

CHANGE-DISCIPLINE
- Touch only what the task requires. No drive-by refactors.
- Violations unrelated to the task → write as a Refactor entry in
  plans/PLAN_TRACKER.md. Do NOT fix inline.

Show me the diff against existing CLAUDE.md.
```

---

# Step 6 (3/4) — Subagents: Code Specialists

3 stateless specialists workers and you can invoke per task. Each agent has its own context and only the rules it needs.

## Prompt (paste in a Claude Code session at the project root)

```
Create 3 specialist sub-agents under .claude/agents/. Each is a
markdown file with YAML frontmatter (name, description, tools) and
a system-prompt body. Read project CLAUDE.md first — every agent
inherits the architecture rules + Plan Tracker workflow.

1. backend-engineer.md
   API endpoints, services, auth, error handling, security, perf.
   Proposes a plan entry before non-trivial changes.

2. frontend-engineer.md
   Components, state, routing, styling, a11y, SSR/CSR boundaries.
   Reads existing frontend layout and respects it.

3. database-engineer.md
   Schema, sequential migrations, indexes, RLS, query plans.
   Never edits a shipped migration. Introspects live DB before
   trusting migration files.

After writing: list the 3 files and show their frontmatter blocks.
```

---

# Step 6 (4/4) — Subagents: Testing System

The testing-engineer is the 4th specialist + it bootstraps a full testing system that mirrors the Plan Tracker shape.

## Prompt (paste in a Claude Code session at the project root)

```
Create the testing-engineer sub-agent + bootstrap a testing system.

1. Create .claude/agents/testing-engineer.md (same format as the
   3 code specialists). Focus: writing & running tests, owning
   coverage, owning the test tracker. Inherits CLAUDE.md rules.

2. Create folder "testing/" at the project root with subfolders:
     testing/unit/  testing/integration/  testing/e2e/  testing/smoke/

3. Create testing/TEST_TRACKER.md — same shape as PLAN_TRACKER,
   columns:
     # | Layer | Title | Brief | Status | Test File
   Layers: Unit | Integration | E2E | Smoke.
   Each row's Test File cell links to the file under
   testing/<layer>/.
   Pre-fill one example row.

4. Append a "Testing" section to project CLAUDE.md:
   - Every plan in PLAN_TRACKER must list the tests that prove
     its Acceptance criteria.
   - testing-engineer registers each test as a row in TEST_TRACKER
     before the plan moves to "Done".
   - Test IDs are sequential: T-001, T-002, ...

After writing: show the testing/ tree, TEST_TRACKER.md, and the new
CLAUDE.md "Testing" section as a diff. Do not run any tests yet.
```

---

# Step 7 — Orchestrator (The Payoff)

> **Pick your variant.** Below is **Variant A — tmux coordination** (persistent worker sessions, tmux dispatch). For local parallel building with native auto-mailbox + git-worktree isolation and **no tmux**, use the **Variant B** prompt at the end of this step instead.

## Variant A — tmux coordination

## What you do

Start a fresh Claude Code session, paste the orchestrator prompt. The orchestrator fetches the protocol from GitHub, saves it locally, then asks what you want to build — plans the slate WITH you, gets your approval, then spawns worker sessions and starts dispatching.

> ⚠️ **Step 6 (PM Framework) is a hard prerequisite.** The orchestrator reads `plans/PLAN_TRACKER.md`, dispatches into `.claude/agents/`, and tells workers to log bugs to `plans/PLAN_TRACKER_BUGS.md` + tests to `testing/TEST_TRACKER.md`. Without those files, workers run with no shared conventions and the architecture rules don't propagate. Every spawned session inherits the PM framework — that's how the whole system stays coherent.

> ⚠️ **Permissions gotcha for spawned workers:** the `--bypass` flag from Step 3 only adds bypassPermissions to the `Shift+Tab` cycle — it doesn't start in bypass. So spawned workers boot in default mode, hit permission prompts on file edits, and stall (no human there to press Shift+Tab). Use `--dangerously-skip-permissions` (no "allow-") to actually start in bypass. The prompt below tells the orchestrator to ask you before using it.

## Prompt (paste in a fresh Claude Code session at the project root)

```
You are the orchestrator session for this project.

Fetch and SAVE these files to the project root (so future sessions and
workers can read them locally without re-fetching):
- ORCHESTRATOR_BOOTSTRAP.md →
  https://raw.githubusercontent.com/markoladika/orchestrator-protocol/main/ORCHESTRATOR_BOOTSTRAP.md
- ORCHESTRATOR_PROTOCOL.md →
  https://raw.githubusercontent.com/markoladika/orchestrator-protocol/main/ORCHESTRATOR_PROTOCOL.md

If the files already exist in the project root, read them as-is (don't
overwrite — the local copy may have project-specific edits).

ORCHESTRATOR_BOOTSTRAP.md defines your role, rules, and the "How a slate
begins" flow you must follow. ORCHESTRATOR_PROTOCOL.md is on-demand
reference (worked examples, pitfalls, session rotation).

PERMISSIONS — important for spawned workers:
Before spawning any worker tmux session, ASK ME this question:
  "Auto-bypass mode for workers? Workers running autonomously need to
   skip permission prompts so they don't stall on file edits.
   - YES → workers boot in bypassPermissions (can write/edit/run
     anything without confirming). Right for short autonomous slates.
   - NO → workers boot in default mode and will hit permission prompts;
     you'll need to capture and surface them to me, or pause that worker."

If I answer YES: spawn each worker with the --auto-bypass flag:
  claudeNN sessionName --auto-bypass
(NOT --bypass — that only adds bypass to the Shift+Tab cycle and doesn't
start in it. --auto-bypass actually starts the worker in bypass mode.)

If I answer NO: spawn workers with "claudeNN sessionName" as normal.
When a worker stalls on a prompt, capture its tmux pane, surface the
prompt to me, and wait for my approval before relaying it.

No worker sessions exist yet — you'll spawn them yourself per the protocol.
Read this project's state (CLAUDE.md, plans/), then ask me what feature
I want to work on.
```

---

## Variant B — worktrees + Agent Teams (no tmux)

## What you do

Start a fresh Claude Code session at the project root and let the protocol install itself. Each agent gets its own git worktree ("desk") for hard file isolation; the lead and agents coordinate via the native Agent Teams auto-mailbox. No tmux, no server.

> Prerequisite: Claude Code v2.1.32+ and Agent Teams enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`). Step 6 (PM framework) is recommended but optional.

## Prompt (paste in a fresh Claude Code session at the project root)

```
Read https://raw.githubusercontent.com/markoladika/orchestrator-protocol/main/AGENT_ORCHESTRATOR_PROTOCOL.md
and set it up for THIS repo by following its "FOR CLAUDE CODE — SETUP" section.

- Confirm this is a git repo and that Agent Teams is enabled (offer to enable it).
- Explore the repo, then propose a small set of non-overlapping vertical slices
  (features owned end-to-end) and WAIT for my approval before scaffolding.
- Scaffold orchestration/ (lead bootstrap, slate, per-agent notebooks, worktree registry).
- Show me the result and how to start the first slate. Do NOT push to any remote.
```

> Verify: `orchestration/` exists with `LEAD.md`, `SLATE.md`, `agents/`, and a worktree registry; the lead can spawn one agent per slice, each in its own `../<repo>-wt/<agent>` desk.

---

# You're Set Up — Now Go Use It

You now have:

1. **Statusline + Robo-Talk** → visibility + cut noise
2. **Multi-account wrappers** (`claude01`, `claude02`...) → 3x rate-limit headroom
3. **Remote server + Tailscale** → access from any device, any network
4. **tmux** → persistent sessions, survive disconnect
5. **PM scaffolding per project** → trackers, subagents, architecture rules
6. **Orchestrator** → one prompt, parallel sessions, autonomous slates

## Resources

- **All repos:** [github.com/markoladika](https://github.com/markoladika/)
- **Robo-Talk** (output styles + token reduction): [github.com/markoladika/robo-talk](https://github.com/markoladika/robo-talk)
- **Orchestrator Protocol** (bootstrap + protocol): [github.com/markoladika/orchestrator-protocol](https://github.com/markoladika/orchestrator-protocol)
  - Variant A — tmux coordination: `ORCHESTRATOR_BOOTSTRAP.md` + `ORCHESTRATOR_PROTOCOL.md`
  - Variant B — worktrees + Agent Teams (self-installing, no tmux): `AGENT_ORCHESTRATOR_PROTOCOL.md`
- **This Setup Guide** (slides): in the orchestrator-protocol repo

## Let's Connect

- **GitHub:** [github.com/markoladika](https://github.com/markoladika/)
- **X:** [x.com/markoladika](https://x.com/markoladika/)
- **LinkedIn:** [linkedin.com/in/markoladika](https://www.linkedin.com/in/markoladika/)
- **Reach out:** open an issue on any repo, or message me on X / LinkedIn
