---
name: mini-sdd
description: >
  Mini-SDD Flow. A leaner, orchestrator-only version of SDD for smaller tasks.
  Triggered by "/mini-sdd". Uses mini-sdd-planner and mini-sdd-implementer.
---

# Mini-SDD: Lean Spec-Driven Development

Mini-SDD is a streamlined version of the SDD flow designed for smaller features, bug fixes, or refactors. It runs entirely within the Orchestrator's context, avoiding the overhead of subagents while maintaining the discipline of planning and verification.

## When to use Mini-SDD
- The task is expected to take < 5 tasks.
- No complex cross-cutting architectural changes.
- The Orchestrator has sufficient context to handle the implementation.
- You want a quick `plan.md` and rapid execution.

## Phases

### Phase 1: Planning
Invoke `mini-sdd-planner` to research and create `.spec/<slug>/plan.md`.
The user must approve the `plan.md` before proceeding.

### Phase 2: Implementation & Verification
Invoke `mini-sdd-implementer` to execute the tasks in `plan.md`.
This phase handles implementation, testing, and final verification in one flow.

## Invocation
User: `/mini-sdd <task description>`

1.  **Orchestrator**: Detects `/mini-sdd`.
2.  **Orchestrator**: Activates `mini-sdd-planner`.
3.  **Planner**: Creates `plan.md`.
4.  **User**: Reviews and approves `plan.md`.
5.  **Orchestrator**: Activates `mini-sdd-implementer`.
6.  **Implementer**: Completes the task.

## Artifacts
- `.spec/<slug>/plan.md`: The single source of truth for scope, design, and tasks.
