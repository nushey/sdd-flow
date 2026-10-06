---
name: mini-sdd
description: >
  Mini-SDD Flow. A leaner version of SDD for smaller features, bug fixes, or
  refactors. Triggered by "/mini-sdd". Planning runs in the Orchestrator
  (sdd-plan skill); after the user approves the plan, implementation is
  delegated to a single mini-sdd-developer subagent so the implementation
  context starts clean and honors the Bootstrap (skills + MCP calls) declared
  in the plan. Harness-neutral: works with Claude Code, Gemini CLI, Codex CLI,
  and any agent harness that reads AGENTS.md.
---

# Mini-SDD: Lean Spec-Driven Development

Mini-SDD is a streamlined version of the SDD flow designed for smaller features, bug fixes, or refactors. It keeps the discipline of planning and verification while avoiding the multi-subagent ceremony of the full SDD flow.

The Mini-SDD flow uses exactly **one** subagent (the Developer). Planning runs in the Orchestrator because it is interactive (it asks the user). The Developer runs as a subagent because implementation benefits from a clean, plan-only context — that prevents the failure mode where the implementer skips declared skills and MCP re-fetches because the planner already "loaded them in spirit" earlier in the same context.

> **Cross-agent by design.** `sdd-flow` is meant to work across agent
> harnesses: Claude Code, Gemini CLI, Codex CLI, and any agent that reads
> `AGENTS.md`. All wording in this flow refers to *what* to load
> ("invoke the `mini-sdd-developer` subagent", "load the `<name>` skill")
> rather than to any specific UI element. Use whatever delegation /
> skill-loading mechanism your harness provides.

## Requirements (check before planning)

- The harness can delegate to an isolated subagent AND has the `mini-sdd-developer` role registered (by the name your harness gives it, e.g. `sdd-flow:mini-sdd-developer` for the Claude Code plugin, `mini-sdd-developer` elsewhere). If not, STOP before writing anything and tell the user which requirement is missing — skills-only installs (Antigravity, Windsurf) are partial, see INSTALL.md. Never implement the plan in the Orchestrator instead.
- The project is a git repository — the developer commits every task. If not, STOP before writing anything.

## When to use Mini-SDD
- The task is expected to take fewer than ~5 tasks.
- No complex cross-cutting architectural changes.
- The feature is contained enough that a single `plan.md` (instead of
  separate `scope.md` + `design.md` + per-task files) is enough context for
  the Developer.
- You want a quick `plan.md` and rapid execution.

If the task is larger or architecturally fragile, use the full `/sdd` flow instead.

## Phases

### Phase 0: Setup (Orchestrator)
1. Derive a `feature-slug` (kebab-case).
2. **Branch check (before the resume check):** the feature branch is `feature/<feature-slug>`. Uncommitted changes under `.spec/<feature-slug>/` are this flow's own progress; any other uncommitted change is foreign. Never stash, reset, or discard anything yourself.
   - Already on `feature/<feature-slug>` → continue.
   - On another branch with foreign changes → STOP and ask the user to commit or stash them; switching would carry them onto the feature branch.
   - On another branch otherwise → check out `feature/<feature-slug>`, creating it if missing. If git refuses, STOP and report its error.
3. **Resume check:** if `.spec/<feature-slug>/plan.md` already exists, do NOT recreate or overwrite it. Skip planning, ask the user to approve the existing plan (Phase 1 step 3), then go to Phase 2 — the developer resumes by skipping tasks whose boxes are already checked (those carry a commit hash) and reuses the repair budget recorded in its `## Repair attempts` table.

### Phase 1: Planning (Orchestrator)
1. Load the `sdd-plan` skill in Mini-SDD mode, with `.spec/<feature-slug>/plan.md` as the plan path.
2. `sdd-plan` researches, resolves every blocking decision with the user, and writes the plan following its Mini-SDD contract, including the `Bootstrap` section the Developer must honor.
3. Present the plan and ask the user to approve it. Apply requested changes to `plan.md` and ask again. Do NOT delegate until the user approves.

### Phase 2: Implementation & Verification (Subagent)
The Orchestrator delegates to the `mini-sdd-developer` subagent. The subagent:
1. Starts with a clean context — receives only the plan path and the project root.
2. Honors the plan's `Bootstrap` section (loads declared skills, re-invokes declared MCP tools).
3. Executes ALL tasks in `plan.md` sequentially, committing each with conventional commits.
4. Runs final verification (tests, acceptance criteria, post-implementation validations declared in `Bootstrap`), repairing within a budget of 3 attempts per feature that is recorded in `plan.md` and survives new sessions.
5. Writes the `## Audit` from the final code and commits `plan.md` last.
6. Returns a structured report to the Orchestrator.

The flow ends after this local verification. No role pushes, opens or updates pull requests, merges, or modifies remotes. Publishing is a separate action the user takes outside Mini-SDD.

## Invocation
User: `/mini-sdd <task description>`

1. **Orchestrator**: Detects `/mini-sdd`, checks requirements, branch, and resume state.
2. **Orchestrator**: Loads `sdd-plan`, which writes `.spec/<slug>/plan.md`.
3. **User**: Reviews and approves `plan.md`.
4. **Orchestrator**: Delegates to `mini-sdd-developer` subagent with:
   - `plan.md` path
   - target project root
5. **Developer (subagent)**: Bootstraps → implements all tasks → verifies, validates, and repairs → commits the audit → reports.
6. **Orchestrator**: Relays the developer's report to the user. The flow ends here.

## Artifacts
- `.spec/<slug>/plan.md`: The single source of truth for scope, design, tasks, and bootstrap contract.
- `## Repair attempts` table appended by the developer when a repair is needed (shared 3-attempt budget).
- Optional `## Audit` section appended by the developer if post-implementation validations were declared.

## Why one subagent (and not zero)

The previous Mini-SDD flow ran entirely in the Orchestrator. In practice, the implementer phase skipped declared skills and MCP re-fetches because the Orchestrator's context still "felt" loaded from the planner phase. The result: silent drift from the plan's safeguards.

A single subagent fixes this with minimal overhead: it forces a cold context that has to honor the plan's `Bootstrap` section explicitly. Planning stays in the Orchestrator because it needs interactivity — moving it to a subagent would just add a round-trip cost.
