# Plan: SDD-Flow Audit Remediation

## Objective
Apply every validated finding from `AUDIT-REPORT.md` (R1, C1–C2, H1–H5, M1–M10, T1–T4) so the `init → design → implement → verify` loop is deterministic, resume-safe, and free of the `agents-md` MCP and `create-agentsmd` skill — with agents retrieving their own context.

## Acceptance Criteria
- [ ] No reference to `agents-md`, `agents-md-generator`, `uvx`, or `generate_agents_md` exists anywhere except `AUDIT-REPORT.md` (historical) and `.spec/audit-remediation/`.
- [ ] The `skills/create-agentsmd/` directory is deleted.
- [ ] SDD never writes/updates `AGENTS.md` — it is a user-provided precondition. `sdd-init` fails fast if it is missing and verifies Reference-File paths exist (anti-hallucination gate).
- [ ] `tasks.index.md` carries a `Status` column; resume skips `done` tasks.
- [ ] Orchestrator rule #2 has a narrow `verify.md` status-read exception for resume.
- [ ] Failure loop threads the verifier report to the Tech Lead and derives the cycle count from the `## Fixes` table; cap enforced at 3.
- [ ] Fix tasks cite the failing criterion, offending commit, and a regression test.
- [ ] Mini-SDD Bootstrap is a hard gate; plan.md is never overwritten on resume; repair capped at 3; audit committed.
- [ ] No stray/corrupted tokens remain in any agent file.
- [ ] All replacements preserve the existing tone, structure, and harness-neutral wording.

## Bootstrap

> No MCP tools or specialized skills are required for this remediation — every change is a markdown/config edit. Reference tools by name only where the audit demands it.

## Confirmed Feature Behavior
- **Inputs:** `AUDIT-REPORT.md` + the live skill/agent/config files (authoritative).
- **Outputs:** Patched files in place; `skills/create-agentsmd/` removed; 3 manifests + README cleaned.
- **Edge cases handled:** half-states on resume (stop + ask); non-git / dirty-tree (warn / ask); harness-neutral MCP naming (no hardcoded identifiers reintroduced).
- **Out of scope:** the `agents-md` MCP server *internals*; the `writing-skill` itself (stays in repo; only its nondeterministic `MAY` references are removed — T4).

## Technical Design

### Approach
Seven atomic tasks, each scoped to one file (or one cohesive file-group) to avoid merge churn. Every patch is a localized, drop-in replacement block sourced from the validated cross-verification. No new state files: task completion reuses the already-readable `tasks.index.md` (`Status` column), and the failure-cycle count is derived from the existing `## Fixes` table rows.

### Patterns & Conventions honored
- Harness-neutral wording (`skills/mini-sdd-planner/SKILL.md:207`) — no `mcp__plugin_*` identifiers reintroduced.
- "Orchestrator reads only short reports + `tasks.index.md`" (`skills/sdd/SKILL.md:17-37`) preserved and sharpened.
- Context isolation per phase preserved; the one new Developer write (`Status` cell) is a targeted edit that never reads other rows.
- `design.md`-protection during failure recovery stays intact.

### Reference Files (Gold Standards — confirmed by user)
- `AUDIT-REPORT.md` — the source of every finding + line reference.
- The existing skill/agent files — match their tone, section order, and "HARD rule" style.

### Reused (do NOT recreate)
- `tasks.index.md` as the orchestrator-readable status surface (C1/H3).
- The existing `## Fixes` table as the persisted cycle counter (H3).
- The verifier's "commit spec artifacts on PASS" step as the sink for status/audit edits.

## Assumptions & Blind Spots

### Confirmed with user
- Delete both the `agents-md` MCP **and** the `create-agentsmd` skill.
- `AGENTS.md` is a **user-provided precondition** — SDD never creates, bootstraps, refreshes, or updates it. It is assumed present. `sdd-init` only checks for it (fail-fast) and reads it.

### Inferred from codebase (verified by reading)
- `plugin.json` / `marketplace.json` do **not** reference `agents-md` — no edit needed there (verified via grep).
- `writing-skill` is referenced only at `README.md:21` + 3 agent lines; the skill itself is retained, only the `MAY` lines are removed.

### Unverified assumptions (RISK — Developer must confirm first)
- `writing-skill` is intentionally retained. If the user wants it deleted too, expand Task 1 to remove `skills/writing-skill/` and the README row before proceeding.

---

## Tasks

### 1. [x] Remove agents-md MCP + delete create-agentsmd skill + precondition-gate sdd-init — 767541d
Files: `.mcp.json`, `gemini-extension.json`, `.claude/settings.local.json`, `README.md`, `agents/sdd-init.md`, **DELETE** `skills/create-agentsmd/` (whole directory).

**`.mcp.json` — full file:**
```json
{
  "mcpServers": {}
}
```

**`gemini-extension.json` — full file:**
```json
{
  "name": "sdd-flow",
  "version": "0.5.2",
  "description": "Spec-Driven Development orchestrator — Init, Tech Lead, Developer, Verifier subagents (full SDD) plus a Mini-SDD planner + developer subagent for smaller tasks. Harness-neutral so it works with Claude Code, Gemini CLI, Codex, and any agent that reads AGENTS.md."
}
```

**`.claude/settings.local.json` — full file:**
```json
{
  "disabledMcpjsonServers": []
}
```

**`README.md` edits:**
- Line 19 — **DELETE** the `create-agentsmd` table row entirely.
- Line 21 — replace the `writing-skill` row with:
  ```markdown
  | `writing-skill` | Skill | Standard for structured technical documentation, loaded when a plan declares it in Required Skills |
  ```
- Line 26 — **DELETE** the `agents-md` MCP server table row entirely.
- Lines 30–43 (Prerequisites) — replace with:
  ```markdown
  ## Prerequisites

  - **Claude Code** (latest).
  - **Git + GitHub CLI (`gh`)** — the Verifier opens PRs via `gh pr create`.
  ```
- Line 63 — replace with:
  ```markdown
  Restart Claude Code. The `sdd` skill and four subagents register automatically.
  ```
- Line 9 (bullet under the intro) — `AGENTS.md` is no longer "ensured up-to-date by `sdd-init`". Replace that bullet with:
  ```markdown
  - **Convention-first** — `AGENTS.md` is law; assumed present (user-provided) and read by every agent.
  ```
- Line 86 (workflow step 1) — replace with:
  ```markdown
  1. **Init & Scope** — `sdd-init` checks `AGENTS.md` is present (user-provided precondition), verifies Reference Files exist, and writes `scope.md`. This file centralizes business intent, acceptance criteria, and style references.
  ```

**`agents/sdd-init.md` — Skill Usage line (15) → replace with:**
```markdown
**Skill Usage**: No external skills are required — `scope.md` follows the inline template in Step 4.
```

**`agents/sdd-init.md` — Step 1 (lines 28–37) → replace with:**
```markdown
## Step 1 — Precondition check: AGENTS.md

`AGENTS.md` (and `CLAUDE.md` if present) is the source of truth for every downstream agent. It is a **user-provided precondition** — SDD never creates, bootstraps, refreshes, or updates it.

1. Verify `AGENTS.md` exists and is non-empty at the project root.
2. If it is missing or empty → STOP and return `Status: FAIL — AGENTS.md missing`. Tell the user it is their responsibility to provide one before running SDD. Do NOT create or scaffold it.
3. If present → read it for domain terminology and naming conventions used in the scope wording. Proceed to Step 2.

Record AGENTS.md status (`found` | `missing`) in your final report.
```

**`agents/sdd-init.md` — add an anti-hallucination check to Step 3 (Reference Files).** After the existing `### Reference Files (Gold Standards)` refinement rule (`VERBATIM from intake...`), append:
```markdown
**Verify every Reference File path exists** — open each one. If a path does not exist, STOP and return `Status: FAIL — reference file not found: <path>`. The Orchestrator must correct `intake.md`; do not transcribe a path you cannot open. This stops a stale or typo'd Gold Standard from reaching the Tech Lead.
```

**`agents/sdd-init.md` — Done report status line (142) → replace with:**
```markdown
- AGENTS.md status: `found` | `missing` (FAIL).
```

**Delete:** the entire `skills/create-agentsmd/` directory.

---

### 2. [x] Orchestrator: resume state, git-state, failure loop, Phase 0 offload — ac339ef
File: `skills/sdd/SKILL.md`

**Hard rule #2 (line 24) → replace with (C2):**
```markdown
2. **You MUST NOT read `scope.md`, `design.md`, individual task files, fix files, `verify.md`, or `AGENTS.md`.** You only read the **short report string** each subagent returns, plus `tasks.index.md`. **One exception:** during resume, read ONLY the `## Status` line of `verify.md` to route (PASS → complete; FAIL → failure loop). Read no other field of `verify.md`.
```

**Prepare (lines 71–73) → replace with (M10):**
```markdown
### 1. Prepare
- Derive a kebab-case `feature-slug` from the user's description.
- **Git state check:** if the project is not a git repo, warn the user that SDD commits and the PR gate require git, and proceed with local-only artifacts (the Verify phase will skip push/PR). If it is a git repo with a dirty working tree, ask the user to commit or stash before proceeding. Then create and checkout `feature/<feature-slug>` (if it already exists and is clean, just check it out).
```

**Resume mode (lines 76–81) → replace with (C1 + M3):**
```markdown
### Resume mode
`sdd-init` (Phase 1) is idempotent and **always runs**. After Phase 1, detect progress by artifacts present in `.spec/<feature-slug>/` (in priority order):
- `verify.md` `Status: PASS` → feature already complete. Stop.
- `verify.md` `Status: FAIL` → jump to **Failure loop**.
- `tasks.index.md` AND `design.md` both exist → skip Design+Tasks; go to Phase 3, **skipping any task whose `Status` is `done`** (resume only `pending` tasks).
- `scope.md` exists but neither `design.md` nor `tasks.index.md` → go to Phase 2.
- Only `intake.md` → go to Phase 1.
- **Any inconsistent state** (e.g. `tasks.index.md` without `design.md`, or `design.md` without `tasks.index.md`) → STOP and ask the user. Do NOT re-run a phase, which could overwrite the design of record.
```

**Phase 0 Step D — append after the `intake.md` authority line (171) (T3):**
```markdown
`intake.md` is now AUTHORITATIVE for `sdd-init`. Anything not captured here must not appear in `scope.md`.

**Offload the working memory:** the raw research from Step B is now SPENT — it lives in `intake.md`. From here on, treat `intake.md` as the only record of Phase 0. Do not carry the raw search results, candidate lists, or code excerpts forward into later phases; they only dilute attention.
```

**Failure loop (lines 217–224) → replace with (H1 + H3):**
```markdown
## Failure loop

Max 3 cycles total per feature. **Derive the current cycle count from the number of rows in the `## Fixes` section of `tasks.index.md`** (0 rows = not yet started). If the count is already 3, STOP and report to the user that the fix cap was reached. On each cycle:

1. **Delegate to `sdd-flow:sdd-tech-lead`** to create a fix task under `fixes/`. Pass the Verifier's failure report verbatim (failing acceptance criteria, file/commit mismatches, test failures) and the path to `verify.md`.
2. **Delegate to `sdd-flow:sdd-developer`** on that fix task.
3. **Delegate to `sdd-flow:sdd-verifier`** to re-verify.

If the Tech Lead flags the failure as a fundamental design gap, STOP and escalate to the user. Do not run another cycle.
```

---

### 3. [x] Tech Lead: status column + traceability, wiring gate + caps, failure discipline, writing-skill removal — e7eca4a
File: `agents/sdd-tech-lead.md`

**Skill Usage (lines 15–17) → replace with (T4):**
```markdown
**Skill Usage**:
- If `scope.md` contains `Required Skills`, you MUST load them before defining the technical design to ensure your architecture honors those specialized standards.
```

**tasks.index.md format (lines 77–94) → replace with (C1 + M1):**
```markdown
## tasks.index.md format

```markdown
# Tasks: <Feature Name>

Project has tests: yes | no
Test tool: <vitest | jest | pytest | go test | none>

| ID  | Title                          | Status          |
|-----|--------------------------------|-----------------|
| 001 | Implement AuthService core     | pending         |
| 002 | Wire login form to AuthService | pending         |
| 003 | Add session token persistence  | pending         |
```

Tasks run in ID order. The Orchestrator executes them one at a time. The order IS the dependency.

**No `Files touched` column.** Files are task-specific and live inside each task file.

**`Status` column:** every task starts as `pending`. The Developer flips its own row to `done (<hash>)` after a successful commit. The Orchestrator reads this column on resume to skip completed tasks.

**Acceptance traceability (HARD):** every criterion in `scope.md`'s `## Acceptance criteria` MUST be realized by at least one task's `Acceptance` list. Never leave a scope criterion without an owning task.
```

**Reference-file rule (line 139) → replace with (H5):**
```markdown
- You MUST assign at least one `Reference file (STRICT STYLE MATCH)` from `scope.md` or `AGENTS.md` to every task that creates or significantly modifies logic, UI, or integration wiring (DI registration, composition roots, route tables, module barrels).
```

**Caps (HARD) — insert immediately after the broadened Reference-file rule above (T2):**
```markdown
- **Caps (HARD):** at most 5 `Context files` and 3 `Reference files` per task. If more are genuinely needed, justify in the task `Description`. An over-listed task signals over-splitting — reconsider the boundary.
```

**Failure recovery (lines 192–207) → replace with (H1 input + H2 discipline):**
```markdown
# Failure recovery

**Input for failure recovery:** the Orchestrator passes the Verifier's failure report verbatim (failing criteria, mismatches, test failures) and the path to `verify.md`. You MAY read `verify.md` for full detail; the report is your starting point. In recovery you produce ONLY the fix task — you do not re-read or re-derive `design.md`.

When the Orchestrator invokes you with a Verifier failure report, you create a fix task under `.spec/<feature-slug>/fixes/fix-NNN-<slug>.md` using the same task-file format. Fix tasks:
- Are NOT appended to the main `tasks.index.md` task table.
- DO get a row in a clearly delimited `## Fixes` section at the bottom of `tasks.index.md` for traceability.
- Do NOT trigger a redesign. `design.md` stays as the original design of record. If the failure indicates a fundamental design problem, flag that in your Done report.

**Fix-task discipline (HARD):**
- Cite the exact failing acceptance criterion (quote from the failure report) in the task `Description`.
- List the offending commit hash and file(s) under `Context files`.
- Include a regression test that reproduces the failure in `Acceptance`, and set `Needs tests: yes` (unless the project has no test tool).
- Stay minimal: fix only the reported regression. No adjacent refactors, no scope expansion.

`## Fixes` section format:

```markdown
## Fixes

| Fix ID  | Title            | Triggered by failure in | Files (suggested)    |
|---------|------------------|-------------------------|----------------------|
| fix-001 | Patch auth guard | Verifier cycle 1        | src/api/auth.ts      |
```
```

---

### 4. [x] Developer: status bookkeeping, context isolation, commit retry, corrupted tail — 9ad71cd
File: `agents/sdd-developer.md`

**Staging rule (line 44) → replace with (C1):**
```markdown
    Do NOT stage the task file or `tasks.index.md` in this commit (both are spec artifacts the Verifier commits).
```

**Commit-verify step (line 46) → replace with (M2):**
```markdown
12. **Verify the commit landed.** Use your environment's git tools to check the hash and subject. If the commit silently failed (e.g. a pre-commit hook rejected it) or the hash didn't change: read the hook's error, fix the underlying issue (lint/format/typecheck), re-stage, create a NEW commit, and verify again. Do NOT report a fake hash. If the second attempt also fails, THEN report the failure with the actual error output.
```

**Step 13 (lines 48–60) → replace with (C1):**
```markdown
13. **Post-commit bookkeeping.** ONLY if the commit verified successfully in step 12:

    a. **Fill the Implementation log** in the task file — replace the placeholder block with the real values:

    ```markdown
    ## Implementation log (filled by dev after successful commit)
    - Commit: <hash> — <subject>
    - Files modified:
      - path/to/file.ext (created | modified)
    - Tests added: <count> (<tool>) | none required
    - Context & Reference files read: <list every file from the task's Context/Reference sections, one per line>
    - Notes: <surprises, follow-ups, files touched outside the suggested list with reason; "none" if there is nothing to flag>
    ```

    The list of files MUST match exactly what git reports for that commit. Do not embellish, do not omit. If you touched a file outside the suggested list, list it AND explain why in `Notes`. `Context & Reference files read` MUST list every file from the task's `Context files` and `Reference files` sections — omitting one is a hard violation.

    b. **Mark the task done in `tasks.index.md`.** Via a targeted edit on your task's row only, set `Status` from `pending` to `done (<hash>)`. Do NOT read other rows.

    Both the task file and `tasks.index.md` are spec artifacts — do NOT stage either in your code commit (the Verifier commits spec artifacts on PASS).
```

**Context isolation (lines 103–105) → replace with (C1):**
```markdown
## Context isolation
- You may edit ONLY your task's `Status` cell in `tasks.index.md` (after commit). Do NOT read other rows or use other tasks as context. You only know about YOUR task.
- Do NOT read other task files or other developers' commits looking for related work.
```

**Done tail (lines 127–128) → replace with (M9):**
```markdown
- Any surprise, warning, or follow-up.
```
(Remove the orphaned `otes").` line entirely.)

---

### 5. [x] Verifier: role clarity, files-read validation, diff anchoring, writing-skill removal — 2c36913
File: `agents/sdd-verifier.md`

**Role (line 12) → replace with (M7):**
```markdown
QA and PR gate. You are the LAST check before code reaches a shared branch. You never modify production code — you verify and report. You DO write spec artifacts (`verify.md`) and perform git operations (commit spec files, push the branch, open a PR) on PASS. You never merge — a human does.
```

**Skill Usage (lines 14–16) → replace with (T4):**
```markdown
**Skill Usage**:
- On PASS, you MUST load any relevant PR creation skill to generate a high-quality PR body.
```

**Cross-check step (line 33) → replace with (M8):**
```markdown
4. **Cross-check the developer's claims against git reality.** Use git tools to verify the files modified in each claimed commit hash. The file list reported by git MUST match the files claimed in the Implementation log. Any mismatch is a FAIL signal. Then verify the `Context & Reference files read` list is COMPLETE: it must contain every file from the task's `Context files` and `Reference files` sections — a missing declared file is a FAIL signal (skipped read). Any claimed file that does not exist in the repo is a FAIL signal (hallucination).
```

**Code-review step (line 40) → replace with (T1):**
```markdown
7. **Code review.** Start from the branch diff against the target branch (`git diff <target>...HEAD`) — the diff is your primary artifact; task files exist to explain intent, not to be re-read line by line. Group your review into 4 checks:
```

---

### 6. [x] Mini-SDD Planner: resume guard (never overwrite plan.md) — 1542b19
File: `skills/mini-sdd-planner/SKILL.md`

**Intake & Setup (lines 31–34) → replace with (M4):**
```markdown
### 1. Intake & Setup
- Derive a `feature-slug` (kebab-case).
- **Resume check:** if `.spec/<feature-slug>/plan.md` already exists, do NOT recreate or overwrite it. Skip Phases A–D and hand the existing plan to the Orchestrator — the developer resumes by skipping tasks whose boxes are already checked (those carry a commit hash).
- Otherwise, create `.spec/<feature-slug>/` directory.
- If in a git repo, create a feature branch: `feature/<feature-slug>` (if it already exists and is clean, just check it out).
```

---

### 7. [x] Mini-SDD Developer: Bootstrap gate, repair cap, audit commit — 88b9296
File: `agents/mini-sdd-developer.md`

**Bootstrap step 4 (line 32) → replace with (H4):**
```markdown
4. **Bootstrap is a gate.** Every declared skill and MCP tool is a hard requirement. If a skill fails to load or an MCP re-fetch errors, STOP and report a blocker — that failure is the exact drift signal Bootstrap exists to catch. Embedded snapshots are stale by definition — re-fetch every tool listed under `### MCP tools to (re-)invoke before coding`.
```

**Final Verification (lines 48–54) → replace with (M5 + M6):**
```markdown
### 2. Final Verification

After the last task:

1. **Run tests** if the project has a test suite that can be invoked from a script (e.g. `npm test`, `dotnet test`, `pytest`). Light pass — failures here are blockers and you fix them with a new commit.
2. **Check Acceptance Criteria** in `plan.md`. Each box must be visibly satisfied by the implementation. Tick the boxes you can attest to.
3. **Refine if needed (hard cap: 3 fix attempts).** Any acceptance criterion that isn't met → fix it with one more commit and re-tick. If a criterion still fails after 3 total fix attempts, STOP and report the blocker to the Orchestrator — do not loop further.
4. **Commit the audit trail.** Stage and commit `plan.md` (now holding checked boxes, per-task commit hashes, and the `## Audit` section) with `docs(<feature-slug>): record execution audit in plan.md`. Stage only `plan.md`.
```

**Git-hygiene rule (line 118) → replace with (M6):**
```markdown
- One commit per task. Final verification fixes get their own commit. The final `plan.md` audit commit is the one allowed exception to "only task-touched files."
```

**Harness-neutrality rule (line 124) → replace with (H4):**
```markdown
- If a declared skill or MCP tool genuinely does not exist in your harness, STOP and report it as a blocker. Do NOT silently skip a Bootstrap contract item — the Orchestrator must revise the plan.
```
