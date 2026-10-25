<h1 align="center">sdd-flow</h1>

<p align="center">
  <strong>Spec-Driven Development and standalone engineering workflows for AI coding agents.</strong>
</p>

<p align="center">
  <code>Agent Skills pack</code> · <a href="https://agentskills.io">agentskills.io</a>-compliant · Python 3.11+ for the local checker · zero runtime server
</p>

<p align="center">
  <a href="#overview">Overview</a> &bull;
  <a href="#what-it-provides">What It Provides</a> &bull;
  <a href="#workflows">Workflows</a> &bull;
  <a href="#install">Install</a>
</p>

---

## Overview

`sdd-flow` brings structured engineering workflows to coding agents through plain Markdown skills (`skills/<name>/SKILL.md`) and role subagents (`agents/<name>.md`).

Instead of jumping straight from a prompt to unreviewed code, it persists specifications and plans under `.spec/` and delegates execution phases to isolated, cold-context subagents. Every agent reads your project's `AGENTS.md` (and `CLAUDE.md` when present) as its source of truth, and every workflow ends locally without pushing, opening PRs, or touching remotes.

---

## What It Provides

### Skills

| Skill | Invocation | Purpose |
|-------|------------|---------|
| `sdd` | `/sdd <feature>` | Full SDD orchestrator: triages scope, writes `.spec/<slug>/` artifacts, and delegates each phase to an isolated subagent. |
| `mini-sdd` | `/mini-sdd <change>` | Lean SDD flow for small changes: plans in the orchestrator (`sdd-plan`) and delegates implementation to one cold-context developer subagent. |
| `sharp-me` | `/sharp-me <idea>` | Grills an idea through research, focused questions, and tradeoff recommendations until it is a well-defined concept; saves `.spec/<name>/brief.md`. |
| `sdd-plan` | `/sdd-plan <request>` | Writes a proportional implementation plan to `.spec/<name>/plan.md` without modifying code, reading a brief or diagnosis as input when one applies; also serves as Mini-SDD's planner. |
| `sdd-debug` | `/sdd-debug <issue>` | Investigates a failure in the current session, proves the root cause, maps all affected points across callers and interacting modules, and explains what broke and why in `.spec/<bug-slug>/diagnosis.md`. |
| `sdd-implement` | `/sdd-implement <plan>` | Implements all or selected points of any plan in the current session or an isolated subagent, tracking runs in `.spec/<name>/history.md` without creating commits. |
| `sdd-review` | `/sdd-review <request>` | Delegates code quality review, acceptance compliance review, or both to an isolated reviewer subagent without modifying code. |
| `pr-creation` | `/pr-creation` | Formats pull request descriptions around user value and essential reviewer context when explicitly requested. |
| `writing-agents` | `/writing-agents <text or files>` | Evaluates and corrects agent instructions in Markdown, preserving behavior while improving clarity and concision. |
| `writing-humans` | `/writing-humans <text or material>` | Evaluates and corrects human-facing writing for clarity, natural language, and coherent arguments while preserving meaning and depth. |

### Role Subagents

Used by `/sdd` and `/mini-sdd` for cold-context phase isolation:

| Subagent | Role |
|----------|------|
| `sdd-init` | Verifies `AGENTS.md` exists and refines `intake.md` into `scope.md` with stable `AC-NNN` acceptance IDs. |
| `sdd-tech-lead` | Writes `design.md`, `tasks.index.md`, and atomic task files under `tasks/` (or `fixes/` during failure recovery). |
| `sdd-developer` | Implements one Full SDD task per run, commits with conventional commits, and records the implementation log. |
| `sdd-verifier` | Validates git history against task logs, runs tests, verifies every `AC-NNN`, and commits spec artifacts locally on pass. |
| `mini-sdd-developer` | Executes all tasks in a Mini-SDD `plan.md` in a fresh context after loading its declared bootstrap skills and MCP tools. |

---

## Workflows

### Full SDD (`/sdd`)

Designed for larger features and architectural changes:

1. **Triage** — Clarifies scope and reference files; writes `.spec/<slug>/intake.md`.
2. **Init (`sdd-init`)** — Produces `.spec/<slug>/scope.md` with testable `AC-NNN` criteria.
3. **Design & Tasks (`sdd-tech-lead`)** — Produces `design.md`, `tasks/<n>-<slug>.md`, and `tasks.index.md`, validated by `sdd check --phase plan`.
4. **Implement (`sdd-developer`)** — Runs one subagent per task; one task equals one commit.
5. **Verify (`sdd-verifier`)** — Runs tests and checks the diff against `scope.md` (up to 3 fix cycles via `fixes/`). Commits `.spec/<slug>/` locally on pass.

```text
.spec/<feature-slug>/
├── intake.md
├── scope.md
├── design.md
├── tasks.index.md
├── tasks/<n>-<slug>.md
├── fixes/<n>-<slug>.md
└── verify.md
```

Full SDD includes a deterministic local checker (`skills/sdd/scripts/sdd check <slug> --phase resume|scope|plan|verify`) that validates file structure, acceptance coverage, and commit hashes using the Python 3.11+ standard library.

### Mini-SDD (`/mini-sdd`)

Designed for smaller features, bug fixes, and contained refactors. The orchestrator plans directly into `.spec/<slug>/plan.md` using `sdd-plan`, pauses for your approval, and delegates execution and verification to a single `mini-sdd-developer` subagent.

### Standalone Skills (`sharp-me`, `sdd-plan`, `sdd-debug`, `sdd-implement`, `sdd-review`, `pr-creation`, `writing-agents`, `writing-humans`)

Each standalone skill works independently of the `/sdd` and `/mini-sdd` pipelines:

- **Refine or debug first:** `sharp-me` turns an idea into `.spec/<name>/brief.md`; `sdd-debug` explains a failure in `.spec/<bug-slug>/diagnosis.md`. Neither touches project code.
- **Plan:** `sdd-plan` is the only skill that writes `.spec/<name>/plan.md`, reading the brief or diagnosis in that folder as input. The plan is never edited during execution.
- **Execute on demand:** `sdd-implement` executes any `.spec/<name>/plan.md` (or external plan) in your current session or an isolated subagent. Both it and Mini-SDD record progress only in `.spec/<name>/history.md`.
- **Review independently:** `sdd-review` audits uncommitted changes, diffs, or files against project conventions and acceptance criteria in an isolated subagent.
- **Improve writing:** `writing-agents` evaluates and corrects instructions while preserving their behavior. `writing-humans` improves text for people by removing needless repetition, artificial phrasing, and unnecessary complexity while preserving meaning, voice, and depth. It summarizes only when requested. Both evaluate before correcting.

---

## Install

Run the interactive installer to choose **local** (project) or **global** (user) scope for `claude`, `gemini`, `codex`, `opencode`, `kilo`, `cursor`, `windsurf`, `antigravity`, `copilot`, or `universal`:

**macOS / Linux / WSL / git-bash**

```bash
curl -fsSL https://raw.githubusercontent.com/nushey/sdd-flow/main/scripts/install.sh | bash
```

**Windows (PowerShell)**

```powershell
irm https://raw.githubusercontent.com/nushey/sdd-flow/main/scripts/install.ps1 -OutFile install.ps1
.\install.ps1
```

**Native plugin / extension commands:**

- **Claude Code:** `/plugin marketplace add nushey/sdd-flow` then `/plugin install sdd-flow@sdd-flow`
- **Gemini CLI:** `gemini extensions install https://github.com/nushey/sdd-flow`
- **OpenAI Codex:** `codex plugin marketplace add nushey/sdd-flow` then `codex plugin add sdd-flow`

See **[INSTALL.md](./INSTALL.md)** for non-interactive CLI flags, per-client paths, and uninstall instructions.

### Prerequisites for `/sdd` and `/mini-sdd`

- **`AGENTS.md` at the project root** — required precondition defining project rules and conventions (`sdd-flow` never generates it).
- **Git repository** with at least one commit.
- **Python 3.11+** for Full SDD's `sdd check` validator (standard library only).

---

## License

MIT
