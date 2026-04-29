# sdd-flow

Spec-Driven Development orchestrator for Claude Code. Turns any feature prompt into a disciplined `init → design+tasks → implement → verify` flow, with four specialized subagents coordinated via a `.spec/<feature-slug>/` folder.

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
| `writing-skill` | Skill | Standard for structured technical documentation used by all agents |
| `sdd-init` | Subagent | Preparation phase — ensures `AGENTS.md` is current and defines the `scope.md` contract |
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

### Gemini CLI
Install the extension directly from the repository:
```bash
gemini extensions install https://github.com/nushey/sdd-flow
```
*(Or point to a local directory: `gemini extensions install ./sdd-flow`)*

### Claude Code
```
/plugin marketplace add nushey/sdd-flow
/plugin install sdd-flow@sdd-flow
```

Restart Claude Code. The `sdd` skill, four subagents, and the `agents-md` MCP register automatically.

---

## Usage

```
/sdd Add OAuth login with Google
```

The Orchestrator then:

0. **Triage** — asks clarifying questions about scope, PR target, and **Reference Files** (Gold Standards) if the architecture is flexible (JS/TS).
1. **Init & Scope** — `sdd-init` ensures `AGENTS.md` exists and writes `scope.md`. This file centralizes business intent, acceptance criteria, and style references.
2. **Design + Tasks** — `sdd-tech-lead` writes `design.md` (feature-level — no file lists), `tasks.index.md`, and one task file per atomic unit. Each task ships with **Reference Files** for strict style matching.
3. **Implement** — `sdd-developer` executes each task: reads task + design.md + curated context, commits with conventional commits, then fills the Implementation log.
4. **Verify** — `sdd-verifier` cross-checks logs against git, runs tests, reviews **Architectural Fidelity**, and opens a PR on PASS.

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
