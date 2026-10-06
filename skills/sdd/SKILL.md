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
2. **Reading limits.** Phase 0 reads `AGENTS.md` (and `CLAUDE.md`) and the codebase for triage. From Phase 1 on, you MUST NOT read `scope.md`, `design.md`, individual task files, fix files, `verify.md`, or `AGENTS.md` — only the **short report string** each subagent returns, plus `tasks.index.md`. You may list file names under `tasks/` and `fixes/` without opening them. **One exception:** read the short output of the checker (see **Checker**). It is the only way you learn the state of `verify.md`.
3. **You MUST NOT create or modify `AGENTS.md`.** It is a user-provided precondition. `sdd-init` (Phase 1) checks for it and fails fast if it is missing.
4. **The ONLY file the Orchestrator ever writes is `intake.md`** — always in Phase 0, even when triage asked no questions, because it records the base commit. Everything else is written by subagents.
5. **Self-check after each phase:** "Did I just delegate this to a subagent? If no → I am violating the contract."

### Subagent Delegation Protocol

Delegate via your environment's native subagent tool. Every prompt MUST be self-contained:
- **Agent Identifier**: the role name exactly as your harness registered it. Harnesses that namespace plugin agents use `<namespace>:<role>` (Claude Code plugin: `sdd-flow:sdd-tech-lead`); harnesses that register the agent's own `name` use the bare role (Codex TOML, copied agent files: `sdd-tech-lead`). Roles are written bare below.
- **Cold-Start Context**: every absolute path, file, and instruction the subagent needs — it starts cold and cannot rely on prior conversation.
- **Structured Prompt**: project root, feature slug, spec folder path, specific task.
- **Report-Only Return**: short "Done" report starting with `Status: PASS` or `Status: FAIL`. Never file contents.

### Checker

`sdd check` validates the mechanical contract of `.spec/<feature-slug>/` without writing anything (grammar, phases, and output in `references/check-contract.md`). It ships in this skill as `scripts/sdd.py`. Resolve its absolute path from the folder that contains this `SKILL.md`; the **checker command** is `python3 <that path>` (`python` on Windows). Never look for it in the project. Pass the exact checker command to `sdd-init`, `sdd-tech-lead`, and `sdd-verifier` in every delegation. Below, `<checker>` stands for it.

If the checker cannot run (no Python 3.11+, file missing), STOP and tell the user. Never replace it with your own judgment.

---

## Core principles (non-negotiable)

1. **Existing project conventions win.** `AGENTS.md` (and `CLAUDE.md` if present) at the project root is the source of truth.
2. **No overengineering.** Clean and extensible, never overkill.
3. **Context isolation.** Each subagent reads only the artifacts it needs.
4. **Handoff via files.** All inter-agent communication happens through `.spec/<feature-slug>/`.
5. **Atomic tasks, sequential execution.** One logical concern per task. Tasks run one after another.
6. **Local closure only.** SDD ends after local verification. No role pushes, opens or updates pull requests, merges, or modifies remotes — not even when resuming a PASS. Publishing is a separate action the user takes outside this flow.

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
- **Git precondition:** if the project is not a git repository, or it has no commit yet (`git rev-parse --verify HEAD` fails), STOP before writing any artifact. SDD commits every task and reviews the feature against a local base commit. No remote, upstream, or hosting CLI is required.
- **Checker available:** run `<checker> check <feature-slug>` once. If the command cannot start or exits 2, STOP and relay its output (see **Checker**). Exit 0 or 1 only proves it runs; routing comes later.
- **Base commit:** the full hash the feature's diff is reviewed against, recorded under `## Base commit` in `intake.md`. Resolve it before the branch check:
  - `feature/<feature-slug>` does not exist yet → capture `git rev-parse HEAD` now; the branch check below creates the branch from this commit.
  - The branch exists and `intake.md` has no base commit (new run or older spec) → ask the user for an explicit local commit or ref. Resolve it with `git rev-parse --verify <ref>^{commit}` and require `git merge-base --is-ancestor <hash> feature/<feature-slug>`. Never infer it from `origin` or an upstream. On resume, add the resolved `## Base commit` section to the existing `intake.md` without changing anything else.
- **Branch check (new run and resume, before any routing):** the feature branch is `feature/<feature-slug>`. Uncommitted changes under `.spec/<feature-slug>/` are this flow's own progress; any other uncommitted change is foreign. Never stash, reset, or discard anything yourself.
  - Already on `feature/<feature-slug>` → continue.
  - On another branch with foreign changes → STOP and ask the user to commit or stash them; switching would carry them onto the feature branch.
  - On another branch otherwise → check out `feature/<feature-slug>`, creating it if missing. If git refuses, STOP and report its error.

### Resume mode
`sdd-init` (Phase 1) **always runs**: it creates `scope.md` once and, when `scope.md` already exists, only validates the preconditions and returns its path without modifying it. After Phase 1, run `<checker> check <feature-slug>` and route by its output:
- Exit 2 (environment or unsupported format) → STOP and relay the `ERROR` line to the user.
- Exit 1 (contract violated, including interrupted planning or a spec in an older format) → STOP and relay the findings to the user. Never re-run a phase, which could overwrite the design of record, and never create a fix: a structural error consumes no fix attempt.
- `OK resume: scope` → go to Phase 2.
- `OK resume: plan` → go to Phase 3, **skipping any task whose `Status` is `done`** (resume only `pending` tasks).
- `OK resume: verify-fail` → jump to **Failure loop**.
- `OK resume: verify-reconcile` → a previous Verifier run wrote `verify.md` but was interrupted before updating the last fix: go to **Phase 4 in reconcile mode**. Never re-run the developer or create a fix for it.
- `OK resume: verify-pass-stale` → code changed after the verified commit: go to **Phase 4** for a full verification.
- `OK resume: verify-pass` → if `git status --porcelain -- .spec/<feature-slug>/` prints anything, the local closure is pending: go to **Phase 4 in closure mode** (never create a fix for it). Otherwise the feature is complete. Stop.

### 2. Phase 0 — Triage (Orchestrator-only, no subagent)

Phase 0 is where the Orchestrator does ALL user-facing grilling. Subagents cannot ask questions — every ambiguity left here costs a failure-loop cycle. Goal: produce an `intake.md` rich enough that `sdd-init` becomes a near-mechanical transcriber.

**Step A — Base commit:** use the base commit resolved in Prepare. It goes under `## Base commit` in `intake.md`.

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

## Base commit
<full commit hash>

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

Wait and read only the short report. On PASS, continue with **Resume mode** routing; on FAIL, STOP and relay it.

---

### 4. Phase 2 — Design + Tasks (delegated to `sdd-tech-lead`)

Produces `design.md`, the task files, and finally `tasks.index.md`.

Delegate to `sdd-tech-lead`. Provide:
- Project root, feature slug, and spec path.
- Path to `scope.md`.
- Instruction to produce design and tasks, and the checker command.

Wait for the short report. Then run `<checker> check <feature-slug> --phase plan`; Phase 3 starts only on exit 0. Otherwise STOP and relay the findings — the index alone never proves the plan is complete. Read `tasks.index.md` only to extract the ordered task list.

### 5. Phase 3 — Implement (sequential, one call per task)

For each task whose `Status` is not `done`, in order:
Delegate to `sdd-developer`. Provide:
- Project root, feature slug, task file path, and `design.md` path.
- Instruction to reconcile any interrupted attempt, then implement exactly this one task and commit on `feature/<feature-slug>`.

Wait and read only the short report. If it starts with `Status: FAIL` or reports a blocker, that is an **implementation blocker, not a verification failure**: STOP and relay the developer's report verbatim to the user with the task ID. Do not enter the Failure loop, do not create a fix, and do not run later tasks. The task stays `pending`; once the user resolves the blocker, re-running `/sdd <feature-slug>` resumes at that task and then continues with the following ones.

### 6. Phase 4 — Verify (delegated to `sdd-verifier`)

Delegate to `sdd-verifier`. Provide:
- Project root, spec path, feature branch name, and the checker command.
- Instruction to run verification and close locally on PASS — or, in **closure mode** (resume with `Status: PASS` and closure pending), to skip re-verification and only complete the local closure — or, in **reconcile mode**, to update the last fix from the existing `verify.md` and then close or report.

Wait and read only the short report, matching the most specific line first:
- `Status: PASS — closure pending` → tell the user the local closure is pending and why; re-running `/sdd <feature-slug>` resumes it. The feature is not finished.
- `Status: PASS` with no qualifier → done. Tell the user the feature is verified locally; publishing it is their separate action.
- `Status: FAIL — blocked` → a local precondition or a checker run failed. STOP and relay the report verbatim. Do not enter the Failure loop.
- `Status: FAIL` → **Failure loop**.

## Failure loop (Verifier FAIL only)

Entered only when the Verifier reports `Status: FAIL`, in this session or recorded in `verify.md`. Developer blockers never enter it (see Phase 3).

**Budget: 3 fix attempts per feature**, tracked in the `Status` column of the `## Fixes` table in `tasks.index.md`:
`pending` (created, not started) → `in-progress` (developer started) → `done (<hash>)` (committed, awaiting re-verification) → `passed` | `failed` (set by the Verifier). Only `failed` rows consume the budget; creating a `pending` row consumes nothing.

Each time you enter the loop, look at the last row of `## Fixes`:

1. **An open fix** (`pending`, `in-progress`, or `done (<hash>)`) → resume it, never create another. Unless it is `done`, delegate `sdd-developer` on that fix file first (it reconciles an interrupted attempt); then delegate `sdd-verifier` to re-verify.
2. **No open fix** (no rows, or every row is `passed` or `failed`) → if 3 rows are `failed`, STOP and report to the user that the fix cap was reached. Otherwise delegate `sdd-tech-lead` to create the next fix task under `fixes/` (row `pending`). Pass the Verifier's failure report verbatim when you have it from this session, always the path to `verify.md`, and the checker command. Then continue as in step 1.

The Verifier's result routes as in Phase 4. If the Tech Lead flags the failure as a fundamental design gap, STOP and escalate to the user. A developer blocker on a fix follows the Phase 3 rule: stop and report; the row keeps its status and resumes on the next run.

## Language

All artifacts are written in **English**. Reports to the user match the user's language.
