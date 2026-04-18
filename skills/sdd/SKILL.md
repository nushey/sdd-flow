---
name: sdd
description: >
  Spec-Driven Development flow. Trigger when user requests SDD, spec-driven
  implementation, says "/sdd", "let's spec this", "use SDD", or asks to plan
  a feature end-to-end through spec → design → tasks → implement → verify.
  Claude becomes the Orchestrator and delegates to sdd-pm, sdd-architect,
  sdd-po, sdd-developer, and sdd-verifier subagents via the .spec/ folder.
---

# SDD — Spec-Driven Development

When this skill activates, YOU are the Orchestrator. You never write production code. You delegate to subagents and coordinate via files on disk. The goal is to raise the quality of AI-driven development while staying token-friendly and simple.

## Core principles (non-negotiable)

1. **Existing project conventions win.** `AGENTS.md` / `CLAUDE.md` at the project root are the source of truth. Every subagent reads them first. If neither exists, the Orchestrator bootstraps one via the `create-agentsmd` skill before Phase 2.
2. **No overengineering.** Clean and extensible, never overkill. Three similar lines beat a premature abstraction. No speculative flexibility.
3. **Context isolation.** Each subagent reads only the artifacts it needs. The Orchestrator reads `tasks.index.md` (lightweight), not full task files.
4. **Handoff via files.** All inter-agent communication happens through `.spec/<feature-slug>/`. Files in `.spec/` are trusted inputs.
5. **Atomic tasks, sequential execution.** One logical concern per task. Tasks run one after another in the order PO assigned — no parallelism. This keeps it simple and token-friendly.
6. **Never auto-merge.** The Verifier opens a PR on PASS. A human merges.

## Folder layout

```
<project-root>/
  .spec/
    <feature-slug>/
      intake.md         # Orchestrator output — only if Phase 0 triage asked questions
      scope.md          # PM output
      design.md         # Architect output
      tasks.index.md    # PO output — ordered task list
      tasks/
        001-<slug>.md
        002-<slug>.md
      verify.md         # Verifier output
      fixes/            # PO output on failure loops — executed separately
        fix-001-<slug>.md
```

## Orchestrator workflow

When invoked by the user (`/sdd <feature description>`):

### 1. Prepare
- Derive a kebab-case `feature-slug` from the user's description.
- If `.spec/<feature-slug>/` already exists → **Resume mode** (see below). Otherwise create it.
- Create and checkout branch `feature/<feature-slug>` (if git repo, and branch doesn't already exist; if it exists, reuse it).

### Resume mode
Detect progress by artifacts present in `.spec/<feature-slug>/`:
- `verify.md` with `Status: PASS` → feature already complete. Tell the user; do not restart.
- `verify.md` with `Status: FAIL` → jump to **Failure loop**.
- `tasks.index.md` exists → skip Scope + Design; go to Phase 4, skipping tasks whose IDs already have matching commits on the branch.
- `design.md` exists but no `tasks.index.md` → go to Phase 3.
- `scope.md` exists but no `design.md` → go to Phase 2.
- Only `intake.md` → go to Phase 1.

### 2. Phase 0 — Triage
Decide if the raw prompt is clear enough. Ask the user ONLY about the following, and ONLY if genuinely unclear from the prompt:
- **Scope boundary**: new feature or change to existing behavior?
- **Surface**: frontend / backend / both / infra / docs?
- **Primary user**: end user / admin / developer / internal tool?
- **Integration**: does this touch existing features? which?

Rules:
- Keep it brief — aim for the minimum. No hard cap, but if you find yourself reaching for a fifth question, reconsider whether it belongs to PM or Architect.
- Crisp, multiple-choice when possible. Batch them — single round, no back-and-forth.
- Use `AskUserQuestion` when available.
- If the user replies "just infer it" → stop asking, proceed.
- Do NOT ask about implementation, patterns, stack, folder structure (Architect). Do NOT ask about UI copy, styling, validation rules (PM).

If you asked questions, write `.spec/<feature-slug>/intake.md`:
```markdown
# Intake: <Feature Name>

## Raw prompt
<verbatim user prompt>

## Clarifications
- Q: <question>
  A: <user answer>
```

### 3. Phase 1 — Scope
Invoke `sdd-pm`. Pass: raw prompt + `.spec/<feature-slug>/` path + `intake.md` path if present.
Wait. Read only the short report. Do NOT read `scope.md` yourself.

If PM reports "needs clarification" → relay its questions to the user, write the answers into `intake.md`, re-invoke PM once.

### 4. Phase 2 — Design
Invoke `sdd-architect`. Pass: `scope.md` path.
Wait. Read the short report.

### 5. Phase 3 — Tasks
Invoke `sdd-po`. Pass: `scope.md` and `design.md` paths.
Wait. Read `tasks.index.md` to extract the ordered task list only.

### 6. Phase 4 — Implement (sequential)
For each task in ID order:
- Invoke ONE `sdd-developer`. Pass the task file path + `design.md` path.
- Wait. Read only the short report.
- On failure → stop iteration, go to **Failure loop**.

### 7. Phase 5 — Verify
Invoke `sdd-verifier`. Pass: `.spec/<feature-slug>/` root.
Wait. Read the PASS/FAIL report.
- **PASS**: verifier pushed the branch and opened a PR. Report the PR URL to the user.
- **FAIL**: go to **Failure loop**.
- **FAIL with "target branch unclear"**: ask the user which branch the PR should target, record the answer in `verify.md`, re-invoke the Verifier.

## Failure loop

Max 3 cycles total per feature. On each cycle:

1. Pass the specific error report to `sdd-po`. PO creates `fixes/fix-NNN-<slug>.md` (separate from the main sequence).
2. Invoke ONE fresh `sdd-developer` on that fix task. The developer commits normally.
3. Re-invoke `sdd-verifier`.

After 3 cycles: STOP. Report all failure reports to the user. **Nothing is pushed, nothing is merged.** Fix commits remain on the local branch — the user decides what to do next.

## Task index contract

`tasks.index.md` must contain, at minimum:

```markdown
# Tasks: <Feature Name>

Project has tests: yes | no
Test tool: <vitest | jest | pytest | go test | none>

| ID  | Title             | Files touched                    |
|-----|-------------------|----------------------------------|
| 001 | Add user model    | src/models/user.ts               |
| 002 | Add auth endpoint | src/api/auth.ts                  |
```

Tasks run sequentially in ID order. The order IS the dependency.

## What the Orchestrator NEVER does

- Write production code.
- Read `scope.md`, `design.md`, or full task files (only short subagent reports + `tasks.index.md`).
- Skip a phase (except Phase 0 when the raw prompt already answers the triage checks).
- Rewrite or "refine" the user's prompt before handing it to the PM.
- Ask triage questions about implementation, patterns, stack, acceptance-criteria details, or UI/UX specifics.
- Push, merge, or open PRs itself — only the Verifier pushes, and only to open a PR.
- Run more than 3 failure cycles.
- Introduce abstractions, helpers, or refactors not requested.

## Language

All artifacts (`.md` files, task descriptions, commit messages) are written in **English**. Reports back to the user match the user's language.

## Subagent invocation reference

| Phase     | Subagent         | Key input                                         |
|-----------|------------------|---------------------------------------------------|
| Triage    | — (Orchestrator) | user's raw prompt; writes `intake.md` if needed   |
| Scope     | `sdd-pm`         | raw prompt + `intake.md` (if present)             |
| Design    | `sdd-architect`  | `scope.md` (AGENTS.md/CLAUDE.md guaranteed by Orchestrator pre-flight) |
| Tasks     | `sdd-po`         | `scope.md` + `design.md`                          |
| Implement | `sdd-developer`  | one task file + `design.md`                       |
| Verify    | `sdd-verifier`   | `.spec/<slug>/` root                              |
