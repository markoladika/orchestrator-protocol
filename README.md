# Orchestrator Protocol

A multi-session coordination pattern for Claude Code: one orchestrator session manages task dispatch, memory, and decisions while specialized worker sessions execute focused work in parallel.

## What is this?

**Orchestrator Protocol** enables high-throughput AI-assisted engineering by splitting work across specialized Claude Code sessions:

- **Orchestrator** — Holds the canonical task list, plans WITH the human, dispatches work to workers, pins durable patterns to memory
- **Workers** — Focused domains (code review, frontend, backend, security, testing); execute work, own tracker rows, report back
- **Human** — Approves plan scope, makes architectural decisions, reads the tracker on demand
- **Subagents** — Stateless specialists invoked by orchestrator or workers for specific tasks

All sessions touch the same repo via tmux coordination. Minimal collisions. High throughput.

## In practice

In a single day testing this protocol on a production codebase:

- ~50 tasks closed
- 40+ file changes shipped  
- 9 durable structural patterns pinned to persistent memory
- 4 P0 production bugs caught + fixed
- 1 comprehensive database security audit
- 0 regressions

## Files

- **`ORCHESTRATOR_BOOTSTRAP.md`** — Quick start. What the orchestrator session loads on startup (176 lines).
- **`ORCHESTRATOR_PROTOCOL.md`** — Full reference. Architecture, worked examples, common pitfalls, session rotation (952 lines).

## Getting started

1. Read `ORCHESTRATOR_BOOTSTRAP.md` for the core concepts (5 min read)
2. Follow the **Fast start** section in `ORCHESTRATOR_PROTOCOL.md` (~2 minutes to bootstrap)
3. Dispatch your first work using the included templates

You need:
- [Claude Code](https://docs.claude.com/en/docs/claude-code) installed
- [tmux](https://github.com/tmux/tmux) (standard on macOS/Linux)
- A git repository to work on

## License

MIT — Free to use, modify, and distribute.

## Questions?

This protocol is designed for real production work. If you hit edge cases or want to adapt it to your workflow, the full reference in `ORCHESTRATOR_PROTOCOL.md` covers common pitfalls and session rotation patterns.
