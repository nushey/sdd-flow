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

SDD's value is **context isolation**. Each phase MUST run in a separate subagent context — if the Orchestrator does the work itself, SDD collapses to a monolithic prompt.

**Hard rules for the Orchestrator:**

1. **Every subagent phase below MUST be executed by delegating to a subagent.** Writing `scope.md`, `design.md`, task files, or production code yourself is a protocol violation — stop and delegate.
2. **You MUST NOT read `scope.md`, `design.md`, individual task files, fix files, `verify.md`, or `AGENTS.md`.** You only read the **short report string** each subagent returns, plus `tasks.index.md`. **One exception:** during resume, read ONLY the `## Status` line of `verify.md` to route (PASS → complete; FAIL → failure loop). Read no other field of `verify.md`.
3. **You MUST NOT create or modify `AGENTS.md`.** It is a user-provided precondition. `sdd-init` (Phase 1) checks for it and fails fast if it is missing.
4. **The ONLY file the Orchestrator ever writes is `intake.md`** — and only when Phase 0 triage actually asked questions. Everything else is written by subagents.
5. **Self-check after each phase:** "Did I just delegate this to a subagent? If no → I am violating the contract."

### Subagent Delegation Protocol

Delegate via your environment's native subagent tool. Every prompt MUST be self-contained:
- **Agent Identifier**: full name (e.g., `sdd-flow:sdd-tech-lead`).
- **Cold-Start Context**: every absolute path, file, and instruction the subagent needs — it starts cold and cannot rely on prior conversation.
- **Structured Prompt**: project root, feature slug, spec folder path, specific task.
- **Report-Only Return**: short "Done" report starting with `Status: PASS` or `Status: FAIL`. Never file contents.

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
  AGENTS.md           # user-provided; read by every agent
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
- **Git state check:** if the project is not a git repo, warn the user that SDD commits and the PR gate require git, and proceed with local-only artifacts (the Verify phase will skip push/PR). If it is a git repo with a dirty working tree, ask the user to commit or stash before proceeding. Then create and checkout `feature/<feature-slug>` (if it already exists and is clean, just check it out).

### Resume mode
`sdd-init` (Phase 1) is idempotent and **always runs**. After Phase 1, detect progress by artifacts present in `.spec/<feature-slug>/` (in priority order):
- `verify.md` `Status: PASS` → feature already complete. Stop.
- `verify.md` `Status: FAIL` → jump to **Failure loop**.
- `tasks.index.md` AND `design.md` both exist → skip Design+Tasks; go to Phase 3, **skipping any task whose `Status` is `done`** (resume only `pending` tasks).
- `scope.md` exists but neither `design.md` nor `tasks.index.md` → go to Phase 2.
- Only `intake.md` → go to Phase 1.
- **Any inconsistent state** (e.g. `tasks.index.md` without `design.md`, or `design.md` without `tasks.index.md`) → STOP and ask the user. Do NOT re-run a phase, which could overwrite the design of record.

### 2. Phase 0 — Triage (Orchestrator-only, no subagent)

Phase 0 is where the Orchestrator does ALL user-facing grilling. Subagents cannot ask questions — every ambiguity left here costs a failure-loop cycle. Goal: produce an `intake.md` rich enough that `sdd-init` becomes a near-mechanical transcriber.

**Step A — Resolve PR target branch:**
1. Read project rules at the root for a declared PR target.
2. If unresolved, check for `dev` or `develop` branches on origin.
3. If still unresolved, ask the user.

Record the resolved branch in `intake.md` under `## PR target branch`.

**Step B — Silent research (BEFORE asking anything):**
1. Read `AGENTS.md` (and `CLAUDE.md` if present).
2. Search the affected area of the codebase with precise queries.
3. Identify Reference File candidates (base classes, shared hooks, existing services, prior similar features) — 2–5 with one-line purpose each.
4. Detect the dominant architecture pattern in the affected module (container/presentational, hexagonal, layered, etc.).
5. Note reuse opportunities (existing helpers, utils, components the feature should consume rather than recreate).

Write nothing yet. Hold this for Step C.

**Step C — Structured grilling (one question at a time):**

Conduct a focused interview across three mandatory categories. **Ask one question at a time** with this format:

```
**Q<n> — <category>:** <the single, specific question>

**Why I'm asking:** <which downstream decision this unblocks>
**My recommendation:** <your recommended answer with reasoning>
**Alternatives considered:** <1–2 options ruled out and why>
```

Recommending an answer is mandatory — it exposes your assumptions and reduces user cognitive load.

**Category 1 — Feature behavior (zero ambiguity):** inputs, outputs, edge cases (empty/error/loading/unauthorized), explicit out-of-scope. Do not leave this category with any dimension unresolved.

**Category 2 — Reference files (no reinvention):** show the user the candidates you found in Step B and ask which is the Gold Standard. If the user names a file you did not find, READ IT before continuing. If the user says "no reference, just build it" — record as risk in intake.

**Category 3 — Architecture fit (respect what exists):** show the detected pattern and ask for confirmation or correction. Never ask "what architecture should we use?" — always anchor in what you observed.

**Closure criteria** (stop only when ALL hold):
- Feature behavior unambiguous.
- At least one Reference File named, OR absence recorded as risk.
- Architecture fit confirmed.
- No remaining technical decision has two viable paths without a chosen one.

**Hard cap:** 8 questions. **Escape hatch:** if the user says "just infer it" / "anda nomás", stop, dump open questions into `Unverified assumptions`, and proceed.

**Step D — Write rich `intake.md`:**

Create `.spec/<feature-slug>/` and write `intake.md` with this structure:

```markdown
# Intake: <Feature Name>

## PR target branch
<resolved branch>

## Raw prompt
<verbatim user prompt>

## Clarifications (Q&A)
### Q1 — <category>: <question>
**Recommended:** <your recommendation>
**User answered:** <answer>

### Q2 — ...

## Confirmed feature behavior
- **Inputs:** ...
- **Outputs:** ...
- **Edge cases handled:** ...
- **Out of scope:** ...

## Reference Files (confirmed by user)
- path/to/file.ext — Gold Standard for <aspect>.

## Architecture constraints (confirmed)
- <pattern> — confirmed in Q<n>.
- State lives in <where>, not <where-not>.

## Reuse (do NOT recreate)
- path/to/util.ext — existing helper to consume.

## Unverified assumptions (RISK)
- <list, or "none">
```

`intake.md` is now AUTHORITATIVE for `sdd-init`. Anything not captured here must not appear in `scope.md`.

**Offload the working memory:** the raw research from Step B is now SPENT — it lives in `intake.md`. From here on, treat `intake.md` as the only record of Phase 0. Do not carry the raw search results, candidate lists, or code excerpts forward into later phases; they only dilute attention.

---

### 3. Phase 1 — Init & Preparer (delegated to `sdd-init`)

**Always run, idempotent.** Checks `AGENTS.md` is present and produces `scope.md`.

Delegate to `sdd-flow:sdd-init`. Provide:
- Project root, feature slug, and spec path.
- Raw prompt and path to `intake.md`.
- Instruction to check `AGENTS.md` and produce `scope.md`.

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

Max 3 cycles total per feature. **Derive the current cycle count from the number of rows in the `## Fixes` section of `tasks.index.md`** (0 rows = not yet started). If the count is already 3, STOP and report to the user that the fix cap was reached. On each cycle:

1. **Delegate to `sdd-flow:sdd-tech-lead`** to create a fix task under `fixes/`. Pass the Verifier's failure report verbatim (failing acceptance criteria, file/commit mismatches, test failures) and the path to `verify.md`.
2. **Delegate to `sdd-flow:sdd-developer`** on that fix task.
3. **Delegate to `sdd-flow:sdd-verifier`** to re-verify.

If the Tech Lead flags the failure as a fundamental design gap, STOP and escalate to the user. Do not run another cycle.

## Language

All artifacts are written in **English**. Reports to the user match the user's language.
