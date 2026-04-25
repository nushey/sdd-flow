# sdd-flow

Spec-Driven Development orchestrator for Claude Code. Turns any feature prompt into a disciplined `init → scope → design+tasks → implement → verify` flow, with five specialized subagents coordinated via a `.spec/<feature-slug>/` folder.

- **Sequential tasks** — one developer at a time, one commit per task.
- **PR-only** — the Verifier opens a pull request on PASS. Never auto-merges.
- **Convention-first** — `AGENTS.md` is law; ensured up-to-date by `sdd-init` at the start of every run.
- **Token-friendly** — Orchestrator stays thin, subagents read only what they need, Tech Lead curates per-task context so devs don't grep blindly.

---

## What's inside

| Component | Type | Purpose |
|-----------|------|---------|
| `sdd` | Skill | Orchestrator skill — invoked by `/sdd <feature>` |
| `create-agentsmd` | Skill | Authors `AGENTS.md` for fresh repos (fallback used by `sdd-init`) |
| `pr-creation` | Skill | PR body standard used by the Verifier — value-oriented, minimal technical noise |
| `sdd-init` | Subagent | Always-run context initializer — keeps `AGENTS.md` current |
| `sdd-pm` | Subagent | Defines scope, user stories, acceptance criteria |
| `sdd-tech-lead` | Subagent | Defines technical design AND decomposes into atomic value-oriented tasks |
| `sdd-developer` | Subagent | Implements one task, commits, fills the per-task Implementation log, never pushes |
| `sdd-verifier` | Subagent | Runs tests, cross-checks Implementation logs against git, opens PR on PASS |
| `agents-md` | MCP server | Scans existing repos to bootstrap or update `AGENTS.md` |

---

## Prerequisites

- **Claude Code** (latest).
- **`uv`** — required for the bundled `agents-md` MCP server.

  **Linux / macOS:**
  ```bash
  curl -LsSf https://astral.sh/uv/install.sh | sh
  ```

  **Windows (PowerShell):**
  ```powershell
  powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
  ```
- **Git + GitHub CLI (`gh`)** — the Verifier opens PRs via `gh pr create`.

---

## Install

```
/plugin marketplace add nushey/sdd-flow
/plugin install sdd-flow@sdd-flow
```

Restart Claude Code. The `sdd` skill, five subagents, and the `agents-md` MCP register automatically.

---

## Usage

```
/sdd Add OAuth login with Google
```

The Orchestrator then:

1. **Triage** — asks at most a few clarifying questions and resolves the PR target branch.
2. **Init** — `sdd-init` ensures `AGENTS.md` exists and reflects the current repo (idempotent — no-op if already current).
3. **Scope** — `sdd-pm` writes `scope.md`.
4. **Design + Tasks** — `sdd-tech-lead` writes `design.md` (feature-level — no file lists), `tasks.index.md`, and one task file per atomic unit. Each task ships with a curated list of context files and suggested files to create/modify, plus an empty Implementation log placeholder.
5. **Implement** — `sdd-developer` executes each task one at a time: reads the task + design.md + the curated context, commits, then fills the task's Implementation log with the actual commit hash and files touched.
6. **Verify** — `sdd-verifier` reads each task's Implementation log, cross-checks against `git show --stat`, runs tests, reviews acceptance, and opens a PR on PASS.

All artifacts live under `.spec/<feature-slug>/`. Re-running `/sdd` on an existing slug resumes where it left off.

---

## Failure behavior

- Max 3 failure cycles per feature.
- On failure, the Tech Lead produces a fix task under `fixes/` — `design.md` stays as-is.
- If the Tech Lead flags the failure as a fundamental design gap, the loop stops and escalates to the user.
- Nothing is pushed until the Verifier passes.
- On final failure, fix commits remain on the local feature branch — you decide what to do.

---

## License

MIT
