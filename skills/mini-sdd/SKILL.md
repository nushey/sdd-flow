---
name: mini-sdd
description: >
  Mini-SDD Flow. A leaner version of SDD for smaller features, bug fixes, or
  refactors. Triggered by "/mini-sdd". Planning runs in the Orchestrator
  (mini-sdd-planner skill); implementation is delegated to a single
  mini-sdd-developer subagent so the implementation context starts clean
  and honors the Bootstrap (skills + MCP calls) declared in the plan.
  Harness-neutral: works with Claude Code, Gemini CLI, Codex CLI, and any
  agent harness that reads AGENTS.md.
---

# Mini-SDD: Lean Spec-Driven Development

Mini-SDD is a streamlined version of the SDD flow designed for smaller features, bug fixes, or refactors. It keeps the discipline of planning and verification while avoiding the multi-subagent ceremony of the full SDD flow.

The Mini-SDD flow uses exactly **one** subagent (the Developer). The Planner runs in the Orchestrator because planning is interactive (it grills the user). The Developer runs as a subagent because implementation benefits from a clean, plan-only context — that prevents the failure mode where the implementer skips declared skills and MCP re-fetches because the planner already "loaded them in spirit" earlier in the same context.

> **Cross-agent by design.** `sdd-flow` is meant to work across agent
> harnesses: Claude Code, Gemini CLI, Codex CLI, and any agent that reads
> `AGENTS.md`. All wording in this flow refers to *what* to load
> ("invoke the `mini-sdd-developer` subagent", "load the `<name>` skill")
> rather than to any specific UI element. Use whatever delegation /
> skill-loading mechanism your harness provides.

## When to use Mini-SDD
- The task is expected to take fewer than ~5 tasks.
- No complex cross-cutting architectural changes.
- The feature is contained enough that a single `plan.md` (instead of
  separate `scope.md` + `design.md` + per-task files) is enough context for
  the Developer.
- You want a quick `plan.md` and rapid execution.

If the task is larger or architecturally fragile, use the full `/sdd` flow instead.

## Phases

### Phase 1: Planning (Orchestrator)
The Orchestrator invokes the `mini-sdd-planner` skill, which:
1. Runs silent research on conventions, affected area, gold-standard candidates, and architecture.
2. Conducts a structured grilling protocol with the user (feature behavior, reference files, architecture fit).
3. Produces `.spec/<slug>/plan.md` including a `Bootstrap` section listing skills and MCP calls the Developer must honor.

The user must approve `plan.md` before proceeding.

### Phase 2: Implementation & Verification (Subagent)
The Orchestrator delegates to the `mini-sdd-developer` subagent. The subagent:
1. Starts with a clean context — receives only the plan path and the project root.
2. Honors the plan's `Bootstrap` section (loads declared skills, re-invokes declared MCP tools).
3. Executes ALL tasks in `plan.md` sequentially, committing each with conventional commits.
4. Runs final verification (tests, acceptance criteria).
5. Runs any post-implementation validations declared in `Bootstrap`.
6. Returns a structured report to the Orchestrator.

The subagent never pushes. It never merges.

## Invocation
User: `/mini-sdd <task description>`

1. **Orchestrator**: Detects `/mini-sdd`.
2. **Orchestrator**: Activates `mini-sdd-planner` skill.
3. **Planner**: Drives grilling, writes `.spec/<slug>/plan.md`.
4. **User**: Reviews and approves `plan.md`.
5. **Orchestrator**: Delegates to `mini-sdd-developer` subagent with:
   - `plan.md` path
   - target project root
6. **Developer (subagent)**: Bootstraps → implements all tasks → verifies → validates → reports.
7. **Orchestrator**: Relays the developer's report to the user. If the user asks for a PR, the Orchestrator uses the `pr-creation` skill to open one (the subagent never pushes).

## Artifacts
- `.spec/<slug>/plan.md`: The single source of truth for scope, design, tasks, and bootstrap contract.
- Optional `## Audit` section appended by the developer if post-implementation validations were declared.

## Why one subagent (and not zero)

The previous Mini-SDD flow ran entirely in the Orchestrator. In practice, the implementer phase skipped declared skills and MCP re-fetches because the Orchestrator's context still "felt" loaded from the planner phase. The result: silent drift from the plan's safeguards.

A single subagent fixes this with minimal overhead: it forces a cold context that has to honor the plan's `Bootstrap` section explicitly. The planner stays in the Orchestrator because grilling needs interactivity — moving it to a subagent would just add a round-trip cost.
