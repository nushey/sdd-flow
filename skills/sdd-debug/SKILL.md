---
name: sdd-debug
description: >
  Investigate a bug or failure in the current session, trace its root cause with
  concrete evidence, find every affected point across callers and interacting
  modules, and write a root-cause fix plan to .spec/<bug-slug>/plan.md without
  modifying code. Use when the user asks to debug an issue, find why something
  fails, trace a regression or broken behavior, or design a non-patch fix that
  solves a defect at the root. Do not implement code; execution belongs to
  sdd-implement.
---

# sdd-debug

Diagnose a failure to its root cause, map every point where the defect surfaces across callers and interacting modules, and deliver a root-cause fix plan in `.spec/<bug-slug>/plan.md`. Run directly in the current session. Diagnose and plan only: do not modify project files, create branches, commit, push, or delegate to subagents.

## 1. Investigate and prove the root cause

Read what establishes the facts before asking the user:

1. `AGENTS.md` and `CLAUDE.md` at the project root. Load the skills and invoke the context or graph tools those rules require for the affected paths.
2. The execution path where the symptom appears, tracing backward from the point of failure to where the invalid state, unhandled condition, or broken invariant originates.
3. Relevant tests, logs, or reproduction commands allowed by the project rules. Use the available tools to observe the failure or confirm the code path. Never build when project rules forbid it.

Ground every claim in inspected code or execution output. Separate demonstrated facts from hypotheses. If missing runtime inputs or external context prevent full confirmation, state what is proven and ask only for the missing evidence.

Classify the root cause by what actually fails in the code:

- **Unhandled valid or edge case:** a reachable state—such as a legitimate `null`, empty collection, boundary value, or ordering case—was omitted from the logic. Prove how that state reaches the code and handle it where that responsibility belongs.
- **Misplaced or broken logic:** a calculation, state transition, or invariant is enforced in the wrong place or implemented incorrectly.
- **Defective contract:** a method signature, type, or module boundary forces callers into invalid states or makes the invariant impossible to maintain cleanly.

## 2. Map the failure surface in callers and interacting modules

A symptom rarely marks the only affected line. Once you identify the root cause, inspect the surrounding flow—without scanning unrelated parts of the repository:

- **Direct and indirect callers** of the affected function, endpoint, or contract.
- **Interacting modules and sibling operations** that share the same data flow, state transition, or contract (for example, read/write pairs, create/update paths, or serialization boundaries touching the same model).
- **Downstream consumers** that rely on the behavior or contract being corrected.

List every concrete location (`path:line`) where the defect originates, propagates, or requires coordinated updates so the fix covers the full problem at once.

## 3. Resolve contract or scope conflicts before finalizing

Fix the problem at its root while respecting the project's architecture, patterns, and existing contracts. Reuse existing helpers, validations, and domain components instead of duplicating checks at the symptom site. Do not propose symptomatic patches that hide errors, swallow exceptions, invent arbitrary fallbacks, or narrow valid functionality to avoid the failure.

Ask the user before writing the plan only when:

- **A contract or core logic is itself defective:** if respecting an existing contract forces a superficial patch, show the concrete evidence (`path:line` and caller impact) and propose the minimal contract or logic correction alongside its tradeoffs.
- **Required reproduction context or business intent is missing** and cannot be determined from the repository.

Ask one question at a time, with your recommendation and the reason, and wait for the answer:

```text
**<the specific question>**
Recommendation: <your answer and why>. Alternative: <the option you ruled out and why>.
```

## 4. Write the diagnosis and fix plan

Save the result to `.spec/<bug-slug>/plan.md` in the workspace, creating the folder when needed. Write in the user's language and include only sections with substantive content:

- **Symptom and scope:** the observed failure and the bounded flow inspected.
- **Root cause:** the proven origin of the failure (`path:line`), the execution trace or reproduction evidence, and why the current logic or contract fails.
- **Failure points and impact:** all locations across the affected module, its callers, and interacting modules that suffer from the defect or require updates.
- **Root-cause solution:** how the proposed fix resolves the underlying cause within the architecture, which contracts it preserves (or updates by agreement), and what existing components it reuses.
- **Steps:** ordered, reviewable implementation steps with the files each step modifies or creates, ready to execute with `sdd-implement`.
- **Verification:** executable checks, regression tests, or observable outcomes that prove the root cause and all identified failure points are resolved.

Return the saved `.spec/<bug-slug>/plan.md` path and stop. Do not edit code or start implementation.
