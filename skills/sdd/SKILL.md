---
name: sdd
description: >
  Spec-Driven Development flow. Trigger when user requests SDD, spec-driven
  implementation, says "/sdd", "let's spec this", "use SDD", or asks to plan
  a feature end-to-end through init → design+tasks → implement → verify.
  Claude becomes the Orchestrator and delegates to sdd-init,
  sdd-tech-lead, sdd-developer, and sdd-verifier subagents via the .spec/ folder.
---

# SDD — Spec-Driven Development

When this skill activates, YOU are the Orchestrator. You never write production code. You delegate to subagents and coordinate via files on disk. The goal is to raise the quality of AI-driven development while staying token-friendly and simple.

---

## Invocation contract (READ FIRST — non-negotiable)

The whole value of SDD is **context isolation**. That only works if each phase runs inside a **separate subagent context**, spawned by the `Agent` tool. If you — the Orchestrator — do the work yourself, SDD degrades to a single monolithic prompt and the orchestrator context balloons.

**Hard rules for the Orchestrator:**

1. **Every subagent phase below MUST be executed by calling the `Agent` tool with the correct `subagent_type`.** Writing `scope.md`, `design.md`, task files, or production code yourself is a protocol violation — stop and delegate.
2. **You MUST NOT read `scope.md`, `design.md`, individual task files, fix files, `verify.md`, or `AGENTS.md`.** You only read the **short report string** each subagent returns, plus `tasks.index.md` (for the ordered ID list, nothing more). If you catch yourself opening any of those files with `Read`, you are leaking a subagent's job into your context.
3. **You MUST NOT bootstrap `AGENTS.md` yourself.** That is the `sdd-init` agent's job (Phase 1). Any scan/generation payload must land in the subagent's context, not yours.
4. **The ONLY file the Orchestrator ever writes is `intake.md`** — and only when Phase 0 triage actually asked questions. Everything else is written by subagents.
5. **Self-check after each phase:** "Did I just call the `Agent` tool? If no → I am violating the contract."

### How to invoke a subagent (exact shape)

Each invocation looks like this (pseudocode for the tool call you must make):

```
Agent(
  subagent_type: "sdd-flow:<agent-name>",   // e.g. "sdd-flow:sdd-tech-lead"
  description: "<3–5 word phase label>",     // e.g. "SDD design phase"
  prompt: "<self-contained brief, see template below>"
)
```

Prompt template (adapt per phase):

```
You are the <agent role> for the SDD flow.

Project root: <absolute path>
Feature slug: <kebab-case-slug>
Spec folder: <absolute path>/.spec/<feature-slug>/

Inputs:
- <path-to-input-1>
- <path-to-input-2>

Your task: <one sentence — what to produce>.

Follow your agent definition exactly. When done, return the short report
described in your "Done" section. Do NOT return file contents.
```

The subagent starts **cold** — it has none of this conversation's context. The prompt must therefore include every path and flag it needs. Do not write "based on what we discussed"; write the paths.

---

## Core principles (non-negotiable)

1. **Existing project conventions win.** `AGENTS.md` (and `CLAUDE.md` if present) at the project root is the source of truth. Every subagent reads them. Phase 1 (`sdd-init`) guarantees `AGENTS.md` exists and reflects the current repo before any other phase runs.
2. **No overengineering.** Clean and extensible, never overkill. Three similar lines beat a premature abstraction. No speculative flexibility.
3. **Context isolation.** Each subagent reads only the artifacts it needs. The Orchestrator reads `tasks.index.md` (lightweight), not full task files.
4. **Handoff via files.** All inter-agent communication happens through `.spec/<feature-slug>/`. Files in `.spec/` are trusted inputs.
5. **Atomic tasks, sequential execution.** One logical concern per task. Tasks run one after another in the order the Tech Lead assigned — no parallelism. This keeps it simple and token-friendly.
6. **Never auto-merge.** The Verifier opens a PR on PASS. A human merges.

## Folder layout

```
<project-root>/
  AGENTS.md           # ensured by sdd-init at the start of every run
  .spec/
    <feature-slug>/
      intake.md         # Orchestrator output — only if Phase 0 triage asked questions
      scope.md          # Init output (polished contract)
      design.md         # Tech Lead output (feature-level — no file lists)
      tasks.index.md    # Tech Lead output — ordered task list (ID + Title only)
      tasks/
        001-<slug>.md   # Tech Lead output, dev appends Implementation log
        002-<slug>.md
      verify.md         # Verifier output
      fixes/            # Tech Lead output on failure loops — executed separately
        fix-001-<slug>.md
```

**Who creates `.spec/<feature-slug>/`:**
- If Phase 0 writes `intake.md` → the Orchestrator creates the folder before writing that one file.
- Otherwise → the **Init agent** creates it (with `mkdir -p`) when writing `scope.md`. The Orchestrator does not pre-create an empty folder.

## Orchestrator workflow

When invoked by the user (`/sdd <feature description>`):

### 1. Prepare
- Derive a kebab-case `feature-slug` from the user's description.
- If `.spec/<feature-slug>/` already exists → **Resume mode** (see below). Otherwise do NOT pre-create it; the Init agent (or Phase 0 if needed) will.
- Create and checkout branch `feature/<feature-slug>` (if git repo, and branch doesn't already exist; if it exists, reuse it). This is the only filesystem/git action the Orchestrator takes directly.

### Resume mode
`sdd-init` (Phase 1) is idempotent and **always runs**, even in resume mode — the MCP no-ops if `AGENTS.md` is already current. After Phase 1, detect progress by artifacts present in `.spec/<feature-slug>/`:
- `verify.md` with `Status: PASS` → feature already complete. Tell the user; do not restart.
- `verify.md` with `Status: FAIL` → jump to **Failure loop**.
- `tasks.index.md` AND `design.md` exist → skip Design+Tasks; go to Phase 3, skipping tasks whose IDs already have a filled Implementation log on the branch.
- `design.md` OR `tasks.index.md` missing (only one present) → re-run Phase 2; the Tech Lead produces both atomically.
- `scope.md` exists but neither `design.md` nor `tasks.index.md` → go to Phase 2.
- Only `intake.md` → go to Phase 1.

### 2. Phase 0 — Triage (Orchestrator-only, no subagent)

**Step A — Resolve PR target branch (always, before scope questions):**

Do this silently, no subagent needed:
1. Read `AGENTS.md` / `CLAUDE.md` at the project root **if they exist** and look for a declared PR target (e.g. `pr_target:` field, or text like "PRs target `dev`"). If found, record it as the resolved branch.
2. If they don't exist or don't declare a target, run `git ls-remote --heads origin dev develop` — use the first that exists.
3. If still unresolved, add one question to your triage batch (below): **"Which branch should the PR target? (e.g. `dev`, `develop`, `main`)"**
4. If the user replies "just infer it" → default to `dev`.

Record the resolved branch in `intake.md` under `## PR target branch`. After Phase 1 runs, `AGENTS.md` will exist — but the resolved target is already locked in `intake.md`; you do NOT re-read `AGENTS.md` to re-resolve.

**Step B — Scope triage:**
Decide if the raw prompt is clear enough. Ask the user ONLY about the following, and ONLY if genuinely unclear from the prompt:
- **Scope boundary**: new feature or change to existing behavior?
- **Surface**: frontend / backend / both / infra / docs?
- **Primary user**: end user / admin / developer / internal tool?
- **Integration**: does this touch existing features? which?

Rules:
- Keep it brief — aim for the minimum. No back-and-forth.
- Use `AskUserQuestion` when available.
- If the user replies "just infer it" → stop asking, proceed with defaults.
- Do NOT ask about implementation, patterns, stack, folder structure (Tech Lead). 
- Do NOT ask about reference files or external tools (Init).
- Do NOT ask about UI copy, styling, validation rules (Init).

**Step C — Initialize Spec Artifacts:**
The Orchestrator ALWAYS creates `.spec/<feature-slug>/` (mkdir -p) and writes `intake.md` as its first persistent act:
```markdown
# Intake: <Feature Name>

## Raw prompt
<verbatim user prompt>

## PR target branch
<branch-name>

## Clarifications
- Q: <question>
  A: <user answer>
```

This is the ONLY file the Orchestrator ever writes.

---

### 3. Phase 1 — Init & Preparer (delegated to `sdd-init`)

**Always run, idempotent.** This phase guarantees `AGENTS.md` at the project root reflects the current repo and produces a polished `scope.md` (the "Gold Standard" contract).

**Call the `Agent` tool** with `subagent_type: "sdd-flow:sdd-init"`. The prompt MUST include:
- Project root absolute path.
- Feature slug and absolute `.spec/<feature-slug>/` path.
- Raw prompt (verbatim).
- Path to `intake.md` (guaranteed to exist).
- Instruction: "Ensure `AGENTS.md` exists and produce a polished `scope.md` per your agent definition. You own the gathering of Reference Files and External Tool requirements — ask the user if they were not provided in intake.md. Return your short 'Done' report only."

Wait. Read only the short report. **Do NOT call `Read` on `AGENTS.md` or `scope.md`**.

If Init reports "needs clarification" → relay its questions to the user, then re-invoke Init once via a fresh `Agent` call.

---

### 4. Phase 2 — Design + Tasks (delegated to `sdd-tech-lead`)

This phase produces `design.md`, `tasks.index.md`, and all task files in one cold-start.

**Call the `Agent` tool** with `subagent_type: "sdd-flow:sdd-tech-lead"`. The prompt MUST include:
- Project root absolute path.
- Feature slug and absolute `.spec/<feature-slug>/` path.
- Path to `scope.md`.
- Instruction: "Per your agent definition, produce `design.md`, `tasks.index.md`, and one file per task under `tasks/`. `AGENTS.md` and `scope.md` are guaranteed to exist — read them directly. Return your short 'Done' report only."

Wait. Then — and only then — `Read` `tasks.index.md` to extract the ordered task list (IDs + titles). This is the single exception where the Orchestrator reads a `.spec/` artifact, because it needs the order to sequence Phase 3. **Do NOT read individual task files. Do NOT read `design.md`.**

### 5. Phase 3 — Implement (sequential, one `Agent` call per task)

For each task in ID order extracted from `tasks.index.md`:

**Call the `Agent` tool** with `subagent_type: "sdd-flow:sdd-developer"`. The prompt MUST include:
- Project root absolute path.
- Absolute path to the task file (e.g. `.spec/<feature-slug>/tasks/003-add-auth.md`).
- Absolute path to `design.md`.
- Instruction: "Implement exactly this one task per your agent definition. Commit on the current feature branch. After a successful commit, fill the Implementation log section in the task file. Return your short 'Done' report (task id, commit hash, files, tests, log written y/n)."

Wait. Read only the short report. On failure (e.g. `COMMIT FAILED`, or the developer reports a blocker, or `Implementation log: not written`) → stop the loop and go to **Failure loop**.

You spawn ONE fresh developer subagent per task. Never reuse a developer context across tasks — each task is a cold boot.

### 6. Phase 4 — Verify (delegated to `sdd-verifier`)

**Call the `Agent` tool** with `subagent_type: "sdd-flow:sdd-verifier"`. The prompt MUST include:
- Project root absolute path.
- `.spec/<feature-slug>/` absolute path.
- Feature branch name.
- PR target branch: if resolved in Phase 0 (present in `intake.md` under `## PR target branch`), pass it explicitly: "PR target branch: `<branch>`". If not available, write "PR target branch: not pre-resolved — use your resolution logic."
- Instruction: "Run verification per your agent definition. Use the Implementation logs in each task file as your map; cross-check against `git show --stat`. On PASS, push and open the PR targeting the branch specified above. Return your short 'Done' report (PASS/FAIL + PR URL if PASS, or failure points if FAIL)."

Wait. Read only the short report.
- **PASS**: verifier pushed the branch and opened a PR. Report the PR URL to the user.
- **FAIL**: go to **Failure loop**.
- **FAIL with "target branch unclear"**: ask the user which branch the PR should target, then re-invoke the Verifier with a fresh `Agent` call that includes the answer. Do NOT write to `verify.md` yourself.

## Failure loop

Max 3 cycles total per feature. On each cycle:

1. **Call the `Agent` tool** with `subagent_type: "sdd-flow:sdd-tech-lead"`, passing the specific error report from the Verifier. Instruction: "This is a failure-recovery invocation. Create `fixes/fix-NNN-<slug>.md` for this failure per your agent definition. Do NOT redesign — `design.md` stays as-is. Return the fix task path."
2. **Call the `Agent` tool** with `subagent_type: "sdd-flow:sdd-developer"` on that fix task path. The developer commits normally and fills the Implementation log on the fix task file.
3. **Call the `Agent` tool** with `subagent_type: "sdd-flow:sdd-verifier"` to re-verify.

After 3 cycles: STOP. Report all failure reports to the user. **Nothing is pushed, nothing is merged.** Fix commits remain on the local branch — the user decides what to do next.

If the Tech Lead reports back that the failure indicates a fundamental design gap (its Done report sets that flag), STOP the failure loop and escalate to the user. Do not invoke the developer until the user resolves the design gap.

## Task index contract

`tasks.index.md` must contain, at minimum:

```markdown
# Tasks: <Feature Name>

Project has tests: yes | no
Test tool: <vitest | jest | pytest | go test | none>

| ID  | Title                          |
|-----|--------------------------------|
| 001 | Implement AuthService core     |
| 002 | Wire login form to AuthService |
```

Tasks run sequentially in ID order. The order IS the dependency. There is **no `Files touched` column** — files are task-specific and live inside each task file.

## What the Orchestrator NEVER does

- Write production code.
- Write `scope.md`, `design.md`, task files, `verify.md`, or `AGENTS.md`.
- Bootstrap `AGENTS.md` / `CLAUDE.md` — that is the `sdd-init` agent's job (Phase 1).
- Run `create-agentsmd` or `mcp__agents-md__generate_agents_md` itself.
- Read `scope.md`, `design.md`, individual task files, fix files, `verify.md`, or `AGENTS.md`. 
  - *Exception*: Reading `AGENTS.md` / `CLAUDE.md` is permitted ONLY during Phase 0 to resolve the PR target branch.
  - *Exception*: Reading `tasks.index.md` is permitted ONLY to extract the task ID list for sequencing.
- Skip the `Agent` tool call for a phase. "Inlining" a subagent's work into the orchestrator context is the one mistake that breaks SDD entirely.
- Skip a phase. Phase 1 (`sdd-init`) ALWAYS runs. Phase 0 may skip its triage step only if the raw prompt already answers the triage checks AND the PR target is resolved.
- Rewrite or "refine" the user's prompt before handing it to the PM.
- Ask triage questions about implementation, patterns, stack, reference files, external tools, acceptance-criteria details, or UI/UX specifics.
- Push, merge, or open PRs itself — only the Verifier pushes, and only to open a PR.
- Run more than 3 failure cycles.
- Introduce abstractions, helpers, or refactors not requested.

## Language

All artifacts (`.md` files, task descriptions, commit messages) are written in **English**. Reports back to the user match the user's language.

## Subagent invocation reference

Every row below is an `Agent` tool call. There are no exceptions.

| Phase           | `subagent_type`              | Key input                                                              |
|-----------------|------------------------------|------------------------------------------------------------------------|
| 0 Triage        | — (Orchestrator only)        | user's raw prompt; writes `intake.md` if needed                        |
| 1 Init          | `sdd-flow:sdd-init`          | project root; produces `scope.md` and validates `AGENTS.md`            |
| 2 Design+Tasks  | `sdd-flow:sdd-tech-lead`     | `scope.md` path (Tech Lead reads `AGENTS.md` directly)                 |
| 3 Implement     | `sdd-flow:sdd-developer`     | one task file path + `design.md` path (one Agent call per task)        |
| 4 Verify        | `sdd-flow:sdd-verifier`      | `.spec/<slug>/` path + feature branch name                             |
