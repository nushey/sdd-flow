---
name: sdd
description: >
  Spec-Driven Development flow. Trigger when user requests SDD, spec-driven
  implementation, says "/sdd", "let's spec this", "use SDD", or asks to plan
  a feature end-to-end through init → design+tasks → implement → verify.
  Claude becomes the Orchestrator and delegates to sdd-init,
  sdd-tech-lead, sdd-developer, and sdd-verifier subagents.
---

# SDD — Spec-Driven Development

When this skill activates, YOU are the Orchestrator. You never write production code. You delegate to subagents and coordinate via files on disk. The goal is to raise the quality of AI-driven development while staying token-friendly and simple.

---

## Invocation contract (READ FIRST — non-negotiable)

The whole value of SDD is **context isolation**. That only works if each phase runs inside a **separate subagent context**. If you — the Orchestrator — do the work yourself, SDD degrades to a single monolithic prompt and the orchestrator context balloons.

**Hard rules for the Orchestrator:**

1. **Every subagent phase below MUST be executed by delegating to a subagent.** Writing `scope.md`, `design.md`, task files, or production code yourself is a protocol violation — stop and delegate.
2. **You MUST NOT read `scope.md`, `design.md`, individual task files, fix files, `verify.md`, or `AGENTS.md`.** You only read the **short report string** each subagent returns, plus `tasks.index.md`.
3. **You MUST NOT bootstrap `AGENTS.md` yourself.** That is the `sdd-init` agent's job (Phase 1).
4. **The ONLY file the Orchestrator ever writes is `intake.md`** — and only when Phase 0 triage actually asked questions. Everything else is written by subagents.
5. **Self-check after each phase:** "Did I just delegate this to a subagent? If no → I am violating the contract."

### Subagent Delegation Protocol

Delegate to subagents using your environment's native subagent tool.

**Protocol Requirements:**
- **Agent Identifier**: Pass the correct subagent name (e.g., `sdd-flow:sdd-tech-lead`).
- **Cold-Start Context**: The subagent starts cold. Your prompt must include every absolute path, file, and instruction it needs. Do NOT rely on "what we discussed".
- **Structured Prompt**: Use a clear, self-contained brief including the project root, feature slug, spec folder path, and specific task.
- **Report-Only Return**: Instruct the subagent to return only its short "Done" report (which MUST start with `Status: PASS` or `Status: FAIL`). Do NOT have it return file contents.

---

## Core principles (non-negotiable)

1. **Existing project conventions win.** `AGENTS.md` (and `CLAUDE.md` if present) at the project root is the source of truth.
2. **No overengineering.** Clean and extensible, never overkill.
3. **Context isolation.** Each subagent reads only the artifacts it needs.
4. **Handoff via files.** All inter-agent communication happens through `.spec/<feature-slug>/`.
5. **Atomic tasks, sequential execution.** One logical concern per task. Tasks run one after another.
6. **Never auto-merge.** The Verifier opens a PR on PASS. A human merges.

## Folder layout

```
<project-root>/
  AGENTS.md           # ensured by sdd-init at the start of every run
  .spec/
    <feature-slug>/
      intake.md         # Orchestrator output
      scope.md          # Init output
      design.md         # Tech Lead output
      tasks.index.md    # Tech Lead output
      tasks/
        001-<slug>.md   # Tech Lead output, dev appends Implementation log
        002-<slug>.md
      verify.md         # Verifier output
      fixes/            # Tech Lead output on failure loops
        fix-001-<slug>.md
```

## Orchestrator workflow

When invoked by the user (`/sdd <feature description>`):

### 1. Prepare
- Derive a kebab-case `feature-slug` from the user's description.
- If git repo, create and checkout branch `feature/<feature-slug>`.

### Resume mode
`sdd-init` (Phase 1) is idempotent and **always runs**. After Phase 1, detect progress by artifacts present in `.spec/<feature-slug>/`:
- `verify.md` with `Status: PASS` → feature already complete.
- `verify.md` with `Status: FAIL` → jump to **Failure loop**.
- `tasks.index.md` AND `design.md` exist → skip Design+Tasks; go to Phase 3.
- `scope.md` exists but neither `design.md` nor `tasks.index.md` → go to Phase 2.
- Only `intake.md` → go to Phase 1.

### 2. Phase 0 — Triage (Orchestrator-only, no subagent)

**Step A — Resolve PR target branch:**
1. Read project rules at the root for a declared PR target.
2. If unresolved, check for `dev` or `develop` branches on origin.
3. If still unresolved, ask the user.

Record the resolved branch in `intake.md` under `## PR target branch`.

**Step B — Scope triage:**
Ask the user ONLY about scope boundary, surface, primary user, or critical integrations if they are genuinely unclear. If the user says "just infer it," proceed with defaults.

**Step C — Initialize Spec Artifacts:**
Create `.spec/<feature-slug>/` and write `intake.md` as the first persistent act.

---

### 3. Phase 1 — Init & Preparer (delegated to `sdd-init`)

**Always run, idempotent.** Guarantees `AGENTS.md` and produces `scope.md`.

Delegate to `sdd-flow:sdd-init`. Provide:
- Project root, feature slug, and spec path.
- Raw prompt and path to `intake.md`.
- Instruction to ensure `AGENTS.md` and produce `scope.md`.

Wait and read only the short report.

---

### 4. Phase 2 — Design + Tasks (delegated to `sdd-tech-lead`)

Produces `design.md`, `tasks.index.md`, and task files.

Delegate to `sdd-flow:sdd-tech-lead`. Provide:
- Project root, feature slug, and spec path.
- Path to `scope.md`.
- Instruction to produce design and tasks.

Wait. Read `tasks.index.md` only to extract the ordered task list.

### 5. Phase 3 — Implement (sequential, one call per task)

For each task in order:
Delegate to `sdd-flow:sdd-developer`. Provide:
- Project root, task file path, and `design.md` path.
- Instruction to implement exactly this one task and commit.

Wait and read only the short report. If it starts with `Status: FAIL` or indicates a blocker, stop and go to **Failure loop**.

### 6. Phase 4 — Verify (delegated to `sdd-verifier`)

Delegate to `sdd-flow:sdd-verifier`. Provide:
- Project root, spec path, and feature branch name.
- Resolved PR target branch.
- Instruction to run verification and open PR on PASS.

Wait and read only the short report.

## Failure loop

Max 3 cycles total per feature. On each cycle:

1. **Delegate to `sdd-flow:sdd-tech-lead`** to create a fix task under `fixes/`.
2. **Delegate to `sdd-flow:sdd-developer`** on that fix task.
3. **Delegate to `sdd-flow:sdd-verifier`** to re-verify.

## Language

All artifacts are written in **English**. Reports to the user match the user's language.
