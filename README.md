<h1 align="center">sdd-flow</h1>

<p align="center">
  <strong>Spec-Driven Development orchestration for AI coding agents.</strong><br>
  <em>Turns a feature prompt into a disciplined init → design+tasks → implement → verify pipeline, enforced by cold-context subagents.</em>
</p>

<p align="center">
  <code>Agent Skills pack</code> · <a href="https://agentskills.io">agentskills.io</a>-compliant · zero runtime dependency, zero MCP server
</p>

<p align="center">
  <a href="#overview">Overview</a> &bull;
  <a href="#install">Install</a> &bull;
  <a href="#sdd-lifecycle">SDD Lifecycle</a> &bull;
  <a href="#skills--subagents">Skills & Subagents</a> &bull;
  <a href="#configuration--rules-sync">Configuration</a> &bull;
  <a href="#faq">FAQ</a>
</p>

---

## Overview

> **spec-driven development** — no code is written until scope, design, and tasks are confirmed
> on disk. Every phase is a separate subagent, cold-started, reading only the artifact it needs.

An agent that goes straight from prompt to code skips architecture, invents scope as it goes, and
produces a diff nobody reviewed against a plan. sdd-flow fixes this by turning the SDD lifecycle
into disk artifacts under `.spec/<feature-slug>/` and a fixed sequence of subagent hand-offs —
each one starts with **no memory of the conversation**, forcing every decision to be written down
before the next phase can act on it.

sdd-flow is **not** an MCP server and depends on **no external "skills engine."** It ships two
plain artifact types that any agent harness can read directly off disk:

- **Skills** (`skills/<name>/SKILL.md`) — orchestrator + standards, `agentskills.io`-compliant frontmatter.
- **Subagent prompts** (`agents/<name>.md`) — the five roles, plain markdown with `name`+`description` frontmatter.

`.mcp.json` ships as `{"mcpServers": {}}` — an empty placeholder. There is no process to spawn, no
`command`/`args`/`env`, nothing running between sessions. The orchestrator, Init, Tech Lead,
Developer, and Verifier are **prompt roles**, not tool calls.

```
Agent (Claude Code · Gemini CLI · Codex · Cursor · Opencode · Kilo · ...)
    │ reads skills/*/SKILL.md + agents/*.md directly off disk
    ▼
sdd skill (Orchestrator) ──delegates──► sdd-init / sdd-tech-lead / sdd-developer / sdd-verifier
    │                                        (cold-context subagents, one phase each)
    ▼
Workspace:  .spec/<feature-slug>/{scope,design,tasks/,verify}.md   +   git commits   +   PR
```

- **Sequential tasks** — one developer at a time, one commit per task.
- **PR-only** — the Verifier opens a pull request on PASS. Never auto-merges.
- **Convention-first** — `AGENTS.md` is law; a user-provided precondition, read by every agent, never created or edited by sdd-flow.
- **Token-friendly** — Orchestrator stays thin, subagents read only what they need, Tech Lead curates per-task context so devs don't grep blindly.

---

## Install

### Claude Code

```
/plugin marketplace add nushey/sdd-flow
/plugin install sdd-flow@sdd-flow
```

Restart Claude Code. The `sdd` skill and five subagents register automatically — "registration"
means the plugin loader indexes `skills/` and `agents/` from the installed plugin directory; there
is no separate config file to edit.

### Gemini CLI

```bash
gemini extensions install https://github.com/nushey/sdd-flow
```

*(Or point to a local checkout: `gemini extensions install ./sdd-flow`)*

### Any other client (Codex, Opencode, Kilo, Cursor, Windsurf/Devin Desktop, Antigravity)

sdd-flow is harness-neutral Agent Skills — any client that reads `.agents/skills/` picks it up
with **one command**:

```bash
curl -fsSL https://raw.githubusercontent.com/nushey/sdd-flow/main/scripts/install.sh \
  | bash -s -- --client <codex|opencode|kilo|cursor|windsurf|antigravity>
```

Windows: `scripts/install.ps1 -Client <client>`. Per-client install locations, native
alternatives, and limitations (Windsurf/Antigravity have no subagent isolation) →
**[INSTALL.md](./INSTALL.md)**.

### Prerequisites (all clients)

- Your project **must have an `AGENTS.md`** at the root. sdd-flow treats it as law and never
  creates or scaffolds it — that is on you.
- **Git + GitHub CLI (`gh`)**, authenticated (`gh auth login`) — the Verifier opens PRs with it.

### Setup FAQ

> **Is sdd-flow an MCP server I need to start or keep running?**
> No. There is no server, no process, no port. `.mcp.json` is an intentionally empty placeholder.
> The skills and subagent prompts are read directly off disk by whatever harness you're using.

> **Where does sdd-flow "register" itself — is there a config/registry file?**
> No `.skillsconfig`, no `sdd-flow.json`. Claude Code and Gemini CLI use their own plugin/extension
> loaders (`.claude-plugin/`, `gemini-extension.json`); every other client just needs the `skills/`
> and `agents/` folders copied into the directory it already scans (`.agents/skills/`,
> `.codex/agents/`, etc. — see [INSTALL.md](./INSTALL.md)).

> **Do I need to write my own `AGENTS.md`?**
> Yes, before running SDD. It's the single source of truth every subagent reads for domain
> terminology, conventions, and constraints. sdd-flow fails fast (`Status: FAIL — AGENTS.md
> missing`) rather than inventing or scaffolding one.

---

## SDD Lifecycle

### Full SDD

```
/sdd Add OAuth login with Google
```

Best for big features, complex refactors, and changes that need architectural validation and
context isolation between phases.

0. **Triage** (Orchestrator) — asks clarifying questions about scope, PR target branch, and
   Reference Files (Gold Standards) when the architecture is flexible. Writes `intake.md`.
1. **Init & Scope** — `sdd-init` verifies `AGENTS.md` is present (precondition, never created),
   confirms Reference Files exist, and refines `intake.md` into `scope.md` — business intent,
   observable acceptance criteria, style references.
2. **Design + Tasks** — `sdd-tech-lead` writes `design.md` (feature-level, no file lists),
   `tasks.index.md`, and one atomic task file per unit of work, each with its own Reference Files
   for strict style matching.
3. **Implement** — `sdd-developer` runs once per task: reads the task + `design.md` + curated
   context only, implements, commits with conventional commits, fills the Implementation log.
   One task = one commit.
4. **Verify** — `sdd-verifier` cross-checks Implementation logs against actual git history, runs
   tests, reviews architectural fidelity, and opens a PR via `gh pr create` on PASS. Never merges.

All artifacts live under `.spec/<feature-slug>/`. Re-running `/sdd <slug>` on an existing slug
resumes where it left off — nothing restarts from zero.

### Mini-SDD

```
/mini-sdd Fix the typo in the header and update the styles
```

Best for small fixes/refactors where the full 5-phase flow is overkill. Planning (`mini-sdd-planner`
skill) runs directly in the Orchestrator; only implementation is delegated — to a single
`mini-sdd-developer` subagent, cold-started so it loads the Bootstrap (skills + MCP calls) declared
in `plan.md` before writing any code.

### Failure behavior (both flows)

- Max 3 failure cycles per feature.
- On failure, the Tech Lead (Full SDD) or the plan (Mini-SDD) produces a **fix task** under
  `fixes/` — `design.md` stays as-is, the loop doesn't redesign from scratch.
- A fundamental design gap stops the loop and escalates to the user — sdd-flow does not force a
  4th cycle on a broken plan.
- Nothing is pushed until the Verifier passes. On final failure, fix commits stay on the local
  feature branch; you decide what to do with them.

---

## Skills & Subagents

| Name | Type | Invocation | Purpose |
|------|------|------------|---------|
| `sdd` | Skill | `/sdd <feature>` | Orchestrator — triages, writes `.spec/` artifacts, delegates each phase |
| `mini-sdd` | Skill | `/mini-sdd <change>` | Leaner flow: planning in-orchestrator, one delegated developer subagent |
| `mini-sdd-planner` | Skill | loaded by `mini-sdd` | Merges Init + Tech Lead into a single `plan.md` for small changes |
| `pr-creation` | Skill | loaded by the Verifier | PR body standard — value-oriented, minimal technical noise |
| `writing-skill` | Skill | loaded when a plan/task declares it | Standard for structured technical documentation |
| `sdd-init` | Subagent | delegated, Phase 1 | Verifies `AGENTS.md`, refines `intake.md` → `scope.md` |
| `sdd-tech-lead` | Subagent | delegated, Phase 2 + failure recovery | Writes `design.md`, `tasks.index.md`, task files; produces fix tasks on failure |
| `sdd-developer` | Subagent | delegated once per task | Implements exactly one task, commits, fills Implementation log |
| `sdd-verifier` | Subagent | delegated, Phase 4 | Runs tests, cross-checks logs vs. git, opens PR on PASS |
| `mini-sdd-developer` | Subagent | delegated by Mini-SDD | Cold-context implementer for a Mini-SDD `plan.md`; executes all tasks, commits, reports back |

Full prompt bodies live at `skills/<name>/SKILL.md` and `agents/<name>.md` — read them directly,
there is no compiled/hidden variant.

### Artifacts (`.spec/<feature-slug>/`)

```
.spec/<feature-slug>/
├── intake.md          # Orchestrator's grilling output (Phase 0)
├── scope.md            # sdd-init's refined contract (Phase 1)
├── design.md            # sdd-tech-lead's technical design (Phase 2)
├── tasks.index.md        # ordered task list
├── tasks/<n>-<slug>.md    # one atomic task per file, incl. Implementation log
├── fixes/<n>-<slug>.md    # fix tasks emitted on failure recovery
└── verify.md              # sdd-verifier's PASS/FAIL report (Phase 4)
```

---

## Configuration & Rules Sync

sdd-flow has **no plugin-specific config file** — no `.skillsconfig`, no `sdd-flow.json`. The only
configuration surface is what your agent harness already reads:

| Surface | Owned by | Role |
|---------|----------|------|
| `AGENTS.md` (project root) | You (user-provided precondition) | Domain terminology, conventions, hard architecture rules — every subagent treats it as law |
| `CLAUDE.md` (optional) | You | Read alongside `AGENTS.md` when present; same authority |
| `skills/<name>/SKILL.md` | sdd-flow | Orchestrator + standards prompts — edit only if you're forking the flow itself |
| `agents/<name>.md` | sdd-flow | Canonical subagent prompts — single source of truth; per-client adapters (Codex TOML, Opencode `mode: subagent`, etc.) are generated/copied from these, never hand-edited |

There is no environment variable and no hook sdd-flow injects into the host — it only reads the
files above and writes to `.spec/<feature-slug>/` and git.

---

## FAQ

> **Does sdd-flow talk to any network service?**
> No. It never calls an API on its own. The only network action in the whole flow is the
> Verifier's `gh pr create`, which uses your already-authenticated `gh` CLI.

> **Can I skip a phase, e.g. go straight to Implement?**
> Not through the intended flow — each phase's subagent expects the prior phase's artifact
> (`scope.md`, `design.md`, a task file) to exist and refuses to invent one. You can still run a
> subagent by hand if you already have the artifact it needs.

> **What happens to `.spec/` after Verify passes?**
> Nothing automatic — the folder stays on disk as the record of what was built and why. It's not
> gitignored by default in a consuming project unless you choose to.

> **Why five subagents instead of one big prompt?**
> Context isolation. Each phase starts cold, so a bug in Implement can't leak assumptions the
> Verifier should be checking independently, and Design can't accidentally see code that doesn't
> exist yet.

> **Does the Mini-SDD path get the same context isolation?**
> Partially. Planning runs in the Orchestrator's own context (not isolated); only the developer
> subagent is cold-started. That's the intended trade-off for small changes — full isolation for
> every phase is Full SDD's job.

---

## License

MIT
