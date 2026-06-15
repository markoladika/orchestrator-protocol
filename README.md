# Orchestrator Protocol

A multi-session coordination pattern for Claude Code: one orchestrator (tech lead) plans and dispatches work while specialized agents execute focused, parallel work on the same codebase — with minimal collisions.

## What is this?

**Orchestrator Protocol** enables high-throughput AI-assisted engineering by splitting work across specialized Claude Code sessions:

- **Orchestrator / tech lead** — Holds the plan, plans WITH the human, dispatches work, reviews and merges, pins durable patterns to memory
- **Workers / agents** — Focused domains or feature slices; execute work, report back
- **Human** — Approves scope, makes architectural decisions, ratifies merges
- **Subagents** — Stateless specialists invoked by the lead or an agent for a specific task

## Two variants — pick the one that fits

This repo ships **two equal ways** to run the protocol. Same roles and philosophy; different coordination + isolation mechanics.

| | **Variant A — tmux coordination** | **Variant B — worktrees + Agent Teams** |
|---|---|---|
| **Files** | `ORCHESTRATOR_BOOTSTRAP.md` + `ORCHESTRATOR_PROTOCOL.md` | `AGENT_ORCHESTRATOR_PROTOCOL.md` (self-contained, includes installer) |
| **How sessions talk** | tmux `send-keys` between persistent sessions | Native **Agent Teams** auto-mailbox (no polling) |
| **Code isolation** | shared checkout + per-session branches, discipline-based | **git worktree per agent** (a private "desk"), enforced by git |
| **Needs tmux?** | Yes (core) | No — in-process by default; tmux is an optional split-panes *view* |
| **Best for** | Persistent multi-account sessions, remote server, autonomous overnight runs | Local parallel building with native coordination + hard file isolation |

Both keep the same two rules: **one owner per slice** (agents never edit the same files) and **only the lead touches `main`**. You can start with either and move between them — the structure is the same underneath.

## In practice

In a single day testing this protocol on a production codebase:

- ~50 tasks closed
- 40+ file changes shipped
- 9 durable structural patterns pinned to persistent memory
- 4 P0 production bugs caught + fixed
- 1 comprehensive database security audit
- 0 regressions

## Files

**Variant A — tmux coordination**
- **`ORCHESTRATOR_BOOTSTRAP.md`** — Quick start. What the orchestrator session loads on startup.
- **`ORCHESTRATOR_PROTOCOL.md`** — Full reference. Architecture, worked examples, common pitfalls, session rotation.

**Variant B — worktrees + Agent Teams**
- **`AGENT_ORCHESTRATOR_PROTOCOL.md`** — Self-contained spec **and** installer. Hand it to Claude Code in any repo and say "set this up" — it scaffolds the structure for you. No tmux required.

**Shared**
- **`Setup-Guide.md`** — From zero to orchestrating in ~60 minutes (statusline, multi-account, remote server, PM framework, orchestrator). Mostly Variant A; Variant B reuses the PM-framework steps and skips the tmux/server steps.

## Getting started

**Variant B (fastest, local, no tmux):**
Paste into a Claude Code session at your repo root:
```
Read https://github.com/markoladika/orchestrator-protocol/blob/main/AGENT_ORCHESTRATOR_PROTOCOL.md
and set it up for this repo. Follow its "FOR CLAUDE CODE — SETUP" section.
```
You need: [Claude Code](https://docs.claude.com/en/docs/claude-code) (v2.1.32+), a git repo, and Agent Teams enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`).

**Variant A (persistent sessions, tmux):**
1. Read `ORCHESTRATOR_BOOTSTRAP.md` for the core concepts (5 min read)
2. Follow the **Fast start** in `ORCHESTRATOR_PROTOCOL.md`
3. Dispatch your first work using the included templates

You need: Claude Code, [tmux](https://github.com/tmux/tmux), and a git repository.

## License

MIT — Free to use, modify, and distribute.

## Questions?

This protocol is designed for real production work. If you hit edge cases or want to adapt it to your workflow, the full references (`ORCHESTRATOR_PROTOCOL.md` for Variant A, `AGENT_ORCHESTRATOR_PROTOCOL.md` for Variant B) cover common pitfalls.
