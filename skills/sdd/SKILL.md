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

**Capability precondition (check before writing anything):** your harness must be able to delegate to isolated subagents AND have the roles `sdd-init`, `sdd-tech-lead`, `sdd-developer`, and `sdd-verifier` registered. If either is missing, STOP before creating a branch or any `.spec/` file and tell the user which requirement is missing (skills-only installs such as Antigravity or Windsurf are partial — see INSTALL.md). Never run the phases in your own context instead, and never fetch role prompts from another source.

**Hard rules for the Orchestrator:**

1. **Every subagent phase below MUST be executed by delegating to a subagent.** Writing `scope.md`, `design.md`, task files, or production code yourself is a protocol violation — stop and delegate.
2. **Reading limits.** Phase 0 reads `AGENTS.md` (and `CLAUDE.md`) and the codebase for triage. From Phase 1 on, you MUST NOT read `scope.md`, `design.md`, individual task files, fix files, `verify.md`, or `AGENTS.md` — only the **short report string** each subagent returns, plus `tasks.index.md`. You may list file names under `tasks/` and `fixes/` without opening them. **One exception:** to route, read ONLY the `## Status` value of `verify.md` and the `Delivery` line of its `## PR` section. Read no other field of `verify.md`.
3. **You MUST NOT create or modify `AGENTS.md`.** It is a user-provided precondition. `sdd-init` (Phase 1) checks for it and fails fast if it is missing.
4. **The ONLY file the Orchestrator ever writes is `intake.md`** — and only when Phase 0 triage actually asked questions. Everything else is written by subagents.
5. **Self-check after each phase:** "Did I just delegate this to a subagent? If no → I am violating the contract."

### Subagent Delegation Protocol

Delegate via your environment's native subagent tool. Every prompt MUST be self-contained:
- **Agent Identifier**: the role name exactly as your harness registered it. Harnesses that namespace plugin agents use `<namespace>:<role>` (Claude Code plugin: `sdd-flow:sdd-tech-lead`); harnesses that register the agent's own `name` use the bare role (Codex TOML, copied agent files: `sdd-tech-lead`). Roles are written bare below.
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
- **Git precondition:** if the project is not a git repository, STOP before writing any artifact. SDD commits every task and publishes through a pull request; there is no local-only mode.
- **Branch check (new run and resume, before any routing):** the feature branch is `feature/<feature-slug>`. Uncommitted changes under `.spec/<feature-slug>/` are this flow's own progress; any other uncommitted change is foreign. Never stash, reset, or discard anything yourself.
  - Already on `feature/<feature-slug>` → continue.
  - On another branch with foreign changes → STOP and ask the user to commit or stash them; switching would carry them onto the feature branch.
  - On another branch otherwise → check out `feature/<feature-slug>`, creating it if missing. If git refuses, STOP and report its error.

### Resume mode
`sdd-init` (Phase 1) **always runs**: it creates `scope.md` once and, when `scope.md` already exists, only validates the preconditions and returns its path without modifying it. After Phase 1, detect progress by artifacts present in `.spec/<feature-slug>/` (in priority order):
- `verify.md` `Status: PASS`:
  - its `## PR` shows `Delivery: delivered` AND the branch has no commits ahead of its upstream (`git rev-list --count @{u}..HEAD` prints `0`; no upstream counts as ahead) → feature complete. Stop.
  - otherwise → publication is pending: go to **Phase 4 in delivery mode**. Never create a fix for it.
- `verify.md` `Status: FAIL` → jump to **Failure loop**.
- `tasks.index.md` AND `design.md` both exist → skip Design+Tasks. First check that every row of the main task table has its file `tasks/<ID>-*.md` (list the folder; do not open the files). If any is missing, STOP and ask the user — never re-run the Tech Lead over the design of record. Otherwise go to Phase 3, **skipping any task whose `Status` is `done`** (resume only `pending` tasks).
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

**Always run, never destructive.** Checks `AGENTS.md` is present. Creates `scope.md` when it does not exist; when it exists, validates it and leaves it byte-for-byte unchanged.

Delegate to `sdd-init`. Provide:
- Project root, feature slug, and spec path.
- Raw prompt and path to `intake.md`.
- Instruction to check `AGENTS.md`, then create `scope.md` if missing or validate the existing one without modifying it.

Wait and read only the short report.

---

### 4. Phase 2 — Design + Tasks (delegated to `sdd-tech-lead`)

Produces `design.md`, the task files, and finally `tasks.index.md`.

Delegate to `sdd-tech-lead`. Provide:
- Project root, feature slug, and spec path.
- Path to `scope.md`.
- Instruction to produce design and tasks.

Wait. Read `tasks.index.md` only to extract the ordered task list, and run the task-file check from **Resume mode** before Phase 3.

### 5. Phase 3 — Implement (sequential, one call per task)

For each task whose `Status` is not `done`, in order:
Delegate to `sdd-developer`. Provide:
- Project root, feature slug, task file path, and `design.md` path.
- Instruction to reconcile any interrupted attempt, then implement exactly this one task and commit on `feature/<feature-slug>`.

Wait and read only the short report. If it starts with `Status: FAIL` or reports a blocker, that is an **implementation blocker, not a verification failure**: STOP and relay the developer's report verbatim to the user with the task ID. Do not enter the Failure loop, do not create a fix, and do not run later tasks. The task stays `pending`; once the user resolves the blocker, re-running `/sdd <feature-slug>` resumes at that task and then continues with the following ones.

### 6. Phase 4 — Verify (delegated to `sdd-verifier`)

Delegate to `sdd-verifier`. Provide:
- Project root, spec path, and feature branch name.
- Resolved PR target branch.
- Instruction to run verification and publish on PASS — or, in **delivery mode** (resume with `Status: PASS` and publication pending), to skip re-verification and only complete the publication.

Wait and read only the short report:
- `Status: PASS` with the PR URL → done.
- `Status: PASS — delivery pending` → tell the user publication is pending and why; re-running `/sdd <feature-slug>` resumes it. The feature is not finished.
- `Status: FAIL` → **Failure loop**.

## Failure loop (Verifier FAIL only)

Entered only when the Verifier reports `Status: FAIL`, in this session or recorded in `verify.md`. Developer blockers never enter it (see Phase 3).

**Budget: 3 fix attempts per feature**, tracked in the `Status` column of the `## Fixes` table in `tasks.index.md`:
`pending` (created, not started) → `in-progress` (developer started) → `done (<hash>)` (committed, awaiting re-verification) → `passed` | `failed` (set by the Verifier). Only `failed` rows consume the budget; creating a `pending` row consumes nothing.

Each time you enter the loop, look at the last row of `## Fixes`:

1. **An open fix** (`pending`, `in-progress`, or `done (<hash>)`) → resume it, never create another. Unless it is `done`, delegate `sdd-developer` on that fix file first (it reconciles an interrupted attempt); then delegate `sdd-verifier` to re-verify.
2. **No open fix** (no rows, or all `failed`) → if 3 rows are `failed`, STOP and report to the user that the fix cap was reached. Otherwise delegate `sdd-tech-lead` to create the next fix task under `fixes/` (row `pending`). Pass the Verifier's failure report verbatim when you have it from this session, and always the path to `verify.md`. Then continue as in step 1.

The Verifier's result routes as in Phase 4. If the Tech Lead flags the failure as a fundamental design gap, STOP and escalate to the user. A developer blocker on a fix follows the Phase 3 rule: stop and report; the row keeps its status and resumes on the next run.

## Language

All artifacts are written in **English**. Reports to the user match the user's language.
