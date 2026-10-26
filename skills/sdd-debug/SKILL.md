---
name: sdd-debug
description: >
  Investigate a bug or failure in the current session, prove its root cause
  with concrete evidence, find every affected point across callers and
  interacting modules, and explain what broke and why in a short diagnosis
  saved to .spec/<bug-slug>/diagnosis.md, without modifying code. Use when the
  user asks to debug an issue, find why something fails, or trace a regression
  or broken behavior. Do not plan or implement the fix; sdd-plan turns the
  diagnosis into a fix plan.
---

# sdd-debug

Diagnose a failure to its root cause, map every point where the defect surfaces across callers and interacting modules, and explain what broke and why. Run directly in the current session. Diagnose only: do not plan the fix, modify project files, create branches, commit, push, or delegate to subagents.

## 1. Investigate and prove the root cause

Read what establishes the facts before asking the user:

1. `AGENTS.md` and `CLAUDE.md` at the project root. Load the skills and invoke the context or graph tools those rules require for the affected paths.
2. The execution path where the symptom appears, tracing backward from the point of failure to where the invalid state, unhandled condition, or broken invariant originates.
3. Relevant tests, logs, or reproduction commands allowed by the project rules. Prioritize reproducing the failure when a viable procedure is available and permitted. If you do not reproduce it, record why and distinguish the inspected path from observed behavior. Never build when project rules forbid it.

Ground every claim in inspected code or execution output. Separate demonstrated facts from hypotheses. If missing runtime inputs, reproduction context, or business intent prevent full confirmation, state what is proven and ask only for the missing evidence, one question at a time.

Describe the root cause supported by the evidence, whether it concerns code, data, configuration, environment, concurrency, or dependencies. These code examples are not exhaustive categories:

- **Unhandled valid or edge case:** a reachable state—such as a legitimate `null`, empty collection, boundary value, or ordering case—was omitted from the logic. Prove how that state reaches the code.
- **Misplaced or broken logic:** a calculation, state transition, or invariant is enforced in the wrong place or implemented incorrectly.
- **Defective contract:** a method signature, type, or module boundary forces callers into invalid states or makes the invariant impossible to maintain cleanly.

## 2. Map the failure surface in callers and interacting modules

A symptom rarely marks the only affected line. Once you identify the root cause, inspect the surrounding flow—without scanning unrelated parts of the repository:

- **Direct and indirect callers** of the affected function, endpoint, or contract.
- **Interacting modules and sibling operations** that share the same data flow, state transition, or contract (for example, read/write pairs, create/update paths, or serialization boundaries touching the same model).
- **Downstream consumers** that rely on the behavior or contract being corrected.

List every concrete location (`path:line`) where the defect originates, propagates, or requires coordinated updates, so the later fix covers the full problem at once.

## 3. Explain and save the diagnosis

Answer in chat with a short explanation anyone on the team can follow: what broke and why. Then save `.spec/<bug-slug>/diagnosis.md` in the workspace, creating the folder when needed. Write in the user's language, short and plain, with only these sections:

- **What broke:** the observed failure and the flow inspected.
- **Why:** what cause is demonstrated and why it produces the failure, or what remains unproven; distinguish pending hypotheses from established facts.
- **Evidence:** the execution trace, reproduction output, and `path:line` references supporting the diagnosis. State any missing evidence needed to confirm hypotheses. If the failure was not reproduced, explain the limitation and distinguish inspected paths from observed behavior.
- **Affected points:** every location from section 2.

Return the saved path and stop. Do not propose fix steps; `sdd-plan` reads the diagnosis and plans the fix.
