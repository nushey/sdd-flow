# sdd-flow

Spec-Driven Development orchestrator for Claude Code. Turns any feature prompt into a disciplined `scope → design → tasks → implement → verify` flow, with five specialized subagents coordinated via a `.spec/<feature-slug>/` folder.

- **Sequential tasks** — one developer at a time, one commit per task.
- **PR-only** — the Verifier opens a pull request on PASS. Never auto-merges.
- **Convention-first** — `AGENTS.md` / `CLAUDE.md` is law; bootstrapped automatically if missing.
- **Token-friendly** — Orchestrator stays thin, subagents read only what they need.

---

## What's inside

| Component | Type | Purpose |
|-----------|------|---------|
| `sdd` | Skill | Orchestrator skill — invoked by `/sdd <feature>` |
| `create-agentsmd` | Skill | Authors `AGENTS.md` for fresh projects |
| `sdd-pm` | Subagent | Defines scope, user stories, acceptance criteria |
| `sdd-architect` | Subagent | Designs the HOW; bootstraps `AGENTS.md` if missing |
| `sdd-po` | Subagent | Decomposes into atomic sequential tasks |
| `sdd-developer` | Subagent | Implements one task, commits, never pushes |
| `sdd-verifier` | Subagent | Runs tests, reviews, opens PR on PASS |
| `agents-md` | MCP server | Scans existing repos to bootstrap `AGENTS.md` |

---

## Prerequisites

- **Claude Code** (latest).
- **`uv`** — required for the bundled `agents-md` MCP server. Install with:
  ```bash
  curl -LsSf https://astral.sh/uv/install.sh | sh
  ```
- **Git + GitHub CLI (`gh`)** — the Verifier opens PRs via `gh pr create`.

---

## Install

```
/plugin marketplace add github:nushey/sdd-flow
/plugin install sdd-flow@sdd-flow
```

Restart Claude Code. The `sdd` skill, five subagents, and the `agents-md` MCP register automatically.

---

## Usage

```
/sdd Add OAuth login with Google
```

The Orchestrator then:

1. **Triage** — asks at most a few clarifying questions.
2. **Scope** — `sdd-pm` writes `scope.md`.
3. **Design** — `sdd-architect` writes `design.md`, bootstrapping `AGENTS.md` first if your repo doesn't have one.
4. **Tasks** — `sdd-po` writes a sequential task list.
5. **Implement** — `sdd-developer` executes each task, committing one at a time.
6. **Verify** — `sdd-verifier` runs tests, reviews commits, opens a PR on PASS.

All artifacts live under `.spec/<feature-slug>/`. Re-running `/sdd` on an existing slug resumes where it left off.

---

## Failure behavior

- Max 3 failure cycles per feature.
- Nothing is pushed until the Verifier passes.
- On final failure, fix commits remain on the local feature branch — you decide what to do.

---

## License

MIT
