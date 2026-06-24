# SDD-Flow Orchestrator Audit Report

| | |
|---|---|
| Repository | `sdd-flow` |
| Branch / version | `main` / `0.5.2` |
| Date | 2026-06-24 |
| Scope | Orchestrator skills + subagents: `sdd`, `mini-sdd`, `mini-sdd-planner`, `sdd-init`, `sdd-tech-lead`, `sdd-developer`, `sdd-verifier`, `mini-sdd-developer`. The `agents-md` MCP **server** internals are excluded; its **coupling** into prompts/config is in scope (see Required Change #1). |
| Method | Read-only scan of skills, agent prompts, harness configs. |

> This report documents **errors, where they live, and why they matter**. It does
> **not** propose solutions, patches, or replacement code, per the brief.

---

## Executive summary

The `init → design+tasks → implement → verify` skeleton is sound and the
context-isolation model is well-conceived. The defects cluster in four areas:

1. **Resume / state synchronization is broken in two load-bearing ways** — the
   Orchestrator both forbids and requires reading `verify.md`, and there is no
   task-completion state, so resume silently re-implements finished tasks.
2. **The failure loop is under-specified** — the failure payload is not threaded
   to the Tech Lead, regression-fix discipline is absent, and the cycle counter
   is not persisted.
3. **The `agents-md` MCP dependency must be removed** but is wired into the Init
   agent, two harness manifests, and the README. Removing it leaves a
   responsibility gap in `sdd-init` (open design question).
4. **Harness-neutrality and determinism leaks** — a non-neutral MCP identifier, a
   "guidance, not a gate" clause that re-permits the drift Bootstrap exists to
   prevent, and mini-SDD having neither resume nor a repair cap.

Severity legend: **C** = Critical (flow mis-routes / data loss / silent wrong
behavior), **H** = High (wasted cycles / wrong output), **M** = Medium
(correctness/quality risk under common conditions).

---

## Required change #1 — Remove the `agents-md` MCP dependency entirely

Decision: the `agents-md` MCP server is no longer wanted in this project. Every
reference must be removed. This is a cross-cutting change that touches the Init
agent, both harness manifests, the README, and a Claude settings file.

### R1.1 — `agents/sdd-init.md` (the primary coupling)
- **Where:** `Step 1 — Guarantee AGENTS.md exists` (`agents/sdd-init.md:28-37`),
  specifically:
  - `:34` — the hardcoded MCP call
    `mcp__plugin_sdd-flow_agents-md__generate_agents_md` with
    `project_path = <project root>` and the `scan_codebase → read_payload_chunk
    → concatenate data → write` workflow.
  - `:35` — the "refresh via the same flow" path.
  - `:37` — the `bootstrapped via MCP` / `refreshed via MCP` report states.
- **Why it must change:** this is the only mechanism `sdd-init` has to satisfy
  its stated responsibility ("guarantee `AGENTS.md` exists"). Removing the MCP
  call deletes that mechanism. The report states and the dependency on the MCP
  workflow (`scan_codebase`, `read_payload_chunk`, `has_more`) must be deleted
  from the agent's process.
- **Open design gap (no solution here):** after removal, `sdd-init` has **no**
  documented way to create/refresh `AGENTS.md` when it is missing or stale. This
  must be resolved as a separate design decision. Note the existing
  `create-agentsmd` skill (`skills/create-agentsmd/SKILL.md`) is advertised in
  the README as "fallback used by `sdd-init`" but is **never referenced** by the
  agent today (confirmed by search) — so it is currently an orphan, not an
  active path.

### R1.2 — `.mcp.json`
- **Where:** `.mcp.json:1-8` — the entire `mcpServers` block defines only
  `agents-md` (`uvx agents-md-generator`).
- **Why it must change:** this is the MCP registration. Removing the server means
  this file has no remaining servers and must be deleted or emptied.

### R1.3 — `gemini-extension.json`
- **Where:** `gemini-extension.json:5-9` — `mcpServers.agents-md`
  (`uvx agents-md-generator`).
- **Why it must change:** duplicate MCP registration for the Gemini harness; same
  server being removed.

### R1.4 — `.claude/settings.local.json`
- **Where:** `.claude/settings.local.json:1-5` — `disabledMcpjsonServers: ["agents-md"]`.
- **Why it must change:** the server is already disabled here, which is itself a
  signal the dependency was fragile; with the server gone, this disable entry is
  dead config. Note: this also proves that even in the project's own Claude
  config, the MCP `sdd-init` depends on was already switched off — so the
  "guarantee AGENTS.md" path has been silently non-functional locally.

### R1.5 — `README.md`
- **Where:**
  - `:19` — table row advertising `create-agentsmd` as *"fallback used by
    `sdd-init`"* (currently false; see R1.1 open gap).
  - `:26` — table row for the `agents-md` MCP server.
  - `:33` — prerequisite `uv` *"required for the bundled `agents-md` MCP server"*
    plus the install snippets (`:36-43`).
  - `:63` — *"the `agents-md` MCP register automatically."*
- **Why it must change:** documentation must stop advertising a dependency that
  no longer exists, and the `uv` prerequisite exists solely for this server.

### R1.6 — Harness-neutrality corollary (informs the removal)
- **Where:** `agents/sdd-init.md:34` uses the identifier
  `mcp__plugin_sdd-flow_agents-md__generate_agents_md`, which is the
  **Claude-Code-specific** plugin-scoped namespace
  (`mcp__plugin_<plugin>_<server>__<tool>`). The project's own canonical rule
  (`skills/mini-sdd-planner/SKILL.md:207`) mandates `mcp__<server>__<tool>`, and
  the README (`:5`) advertises harness-neutrality.
- **Why it matters:** the identifier would not resolve under Gemini CLI / Codex,
  so the dependency was already non-portable — reinforcing that it should not be
  replaced with another hardcoded MCP identifier.

---

## Critical findings

### C1 — Resume cannot skip completed tasks: no completion state anywhere
- **Where:**
  - Orchestrator resume matrix — `skills/sdd/SKILL.md:76-81`.
  - `tasks.index.md` format — `agents/sdd-tech-lead.md:77-94` (columns are only
    `ID | Title`; explicitly *"No `Files touched` column"* and **no Status
    column**).
  - Orchestrator read restriction — `skills/sdd/SKILL.md:24` forbids reading
    task files.
  - Developer writes the Implementation log **into the task file**
    (`agents/sdd-developer.md:48-60`), never into `tasks.index.md`.
- **What is wrong:** when resume routes to Phase 3 (`tasks.index.md` +
  `design.md` exist), the Orchestrator has **zero** signal for which tasks are
  already committed. `tasks.index.md` carries no status; task files (the only
  place completion is recorded) are off-limits.
- **Why it matters (correctness):** resume re-delegates task `001` even if it is
  already committed → **duplicate implementation / duplicate commit / rework
  conflict**. This directly breaks the documented contract
  (`README.md:91` *"resumes where it left off"*).

### C2 — Orchestrator read-rule contradicts its own resume logic (`verify.md`)
- **Where:**
  - Hard rule #2 — `skills/sdd/SKILL.md:24`: *"You MUST NOT read …
    `verify.md` …"*.
  - Resume matrix — `skills/sdd/SKILL.md:78`: *"`verify.md` with `Status: FAIL`
    → jump to Failure loop"* (and `:77` PASS).
- **What is wrong:** the resume router is built entirely on reading `verify.md`'s
  status, but a hard rule forbids reading `verify.md` at all. There is no
  clause reconciling the two.
- **Why it matters (correctness):** a rule-following model either refuses to read
  `verify.md` (resume detection silently fails / mis-routes) or reads it and
  self-flags a protocol violation. Resume behavior becomes nondeterministic.

---

## High findings

### H1 — Failure loop does not thread the failure payload to the Tech Lead
- **Where:** Failure loop — `skills/sdd/SKILL.md:217-224` ("On each cycle:
  Delegate to tech-lead to create a fix task under `fixes/`"). Tech-Lead inputs —
  `agents/sdd-tech-lead.md:21-26` (no input is "the failure report").
- **What is wrong:** the loop never instructs the Orchestrator to forward the
  verifier's failure details (failing acceptance criteria, commit/file
  mismatches) or the `verify.md` path. The Tech Lead is cold-started and cannot
  see what failed.
- **Why it matters (quality):** the Tech Lead is asked to author a fix for a
  failure it cannot observe → blind or invented fix tasks → wasted cycles and
  fixes that miss the actual regression.

### H2 — Regression-fix discipline is unspecified
- **Where:** Failure recovery — `agents/sdd-tech-lead.md:192-207`. The only
  constraints are "reuse the same task-file format", "not appended to
  `tasks.index.md`", a `## Fixes` traceability row, and *"Do NOT trigger a
  redesign. `design.md` stays."*
- **What is wrong:** there is no requirement that a fix (a) cite the exact
  failing acceptance criterion, (b) cite the offending commit, (c) include a
  regression test that reproduces the failure, or (d) stay minimal.
- **Why it matters (quality):** fix tasks are free to balloon into mini-redesigns
  or to ship without coverage, so the **same** failure recurs and burns cycles.
  The `design.md`-protection clause is the only sound part.

### H3 — Failure-cycle counter is neither persisted nor threaded
- **Where:** `skills/sdd/SKILL.md:219` *"Max 3 cycles total"*. The Orchestrator
  cannot read fix files (`:24`); it may read `tasks.index.md`, whose `## Fixes`
  table (`agents/sdd-tech-lead.md:200-207`) could be counted — but nothing
  instructs it to do so.
- **What is wrong:** there is no cycle-counter artifact and no instruction to
  derive the count. On compaction/restart the count is lost.
- **Why it matters (correctness):** the loop can exceed 3 cycles or restart at
  cycle 1, re-running identical fixes.

### H4 — "Bootstrap is guidance, not a gate" re-permits the drift Bootstrap exists to prevent
- **Where:** `agents/mini-sdd-developer.md:32` — *"Missing/unavailable skills or
  MCP tools get logged … and the run continues."*
- **What is wrong:** this allows any declared MCP re-fetch or skill load to be
  skipped with a log note. That is precisely the silent-context-drift failure
  mode Bootstrap was built to prevent (`skills/mini-sdd/SKILL.md:17`,
  `skills/mini-sdd-planner/SKILL.md:23`). It also collides with the planner's
  hard rule (`skills/mini-sdd-planner/SKILL.md:184-198`) that Bootstrap entries
  are mandatory, literal, complete contracts.
- **Why it matters (quality):** the safeguard is hollowed out — the developer can
  honor the Bootstrap "in spirit" and skip the actual loads/re-fetches, which is
  the exact regression the cold-context design was meant to block.

### H5 — Developer skips DI / Clean-Architecture wiring (gate misses it)
- **Where:**
  - Developer quality clause — `agents/sdd-developer.md:79-83` (generic
    Clean Code / SOLID / GRASP, no integration rule).
  - The only enforcement gate — `agents/sdd-tech-lead.md:139`: a Reference file
    is required for tasks *"that create or significantly modify logic/UI."*
- **What is wrong:** DI/composition-root registration is **neither "logic" nor
  "UI"**, so a task can ship with no reference to the wiring convention.
- **Why it matters (quality):** in Clean-Architecture / DI-driven repos
  (registration in a composition root, module barrels, route tables), the new
  code is added but never wired → services registered in the wrong layer or not
  registered at all. This is the architectural-pattern-skip risk.

---

## Procedure / quality bugs (Medium, affect correct flow or output quality)

### M1 — `scope.md` acceptance vs. task acceptance can drift, unreconciled
- **Where:** Developer treats `scope.md` as optional
  (`agents/sdd-developer.md:28`) and implements against the **task file's**
  `Acceptance` (`:119-122`). Verifier checks **`scope.md`'s** acceptance criteria
  first (`agents/sdd-verifier.md:27,41`). No rule ties the two together.
- **Why it matters (procedure):** Developer satisfies its own task acceptance,
  then Verifier FAILs on a scope criterion the task never encoded → a
  failure-loop cycle spent on a non-bug.

### M2 — Commit-retry inconsistency between full and mini flows
- **Where:** Full developer step 12 — `agents/sdd-developer.md:46` (on a
  pre-commit-hook rejection: *report the failure* → burns a failure cycle). Mini
  developer — `agents/mini-sdd-developer.md:45` (self-recovers: *fix, re-stage,
  new commit, continue*).
- **Why it matters (procedure):** the full-SDD developer is **less** robust than
  mini and wastes a scarce failure cycle on a trivial hook rejection.

### M3 — Resume matrix has undefined half-states
- **Where:** `skills/sdd/SKILL.md:76-81`. Defined only for clean combinations.
- **What is wrong:** undefined for: `tasks.index.md` present but `design.md`
  missing (or vice-versa); `scope.md` missing while `design.md` exists;
  `verify.md` absent but some Implementation logs already filled.
- **Why it matters (procedure):** a model facing a half-state will **guess** a
  phase — e.g., re-running Phase 2 overwrites `design.md`, destroying the design
  of record.

### M4 — Mini-SDD has no resume mode and overwrites the plan
- **Where:** `skills/mini-sdd/SKILL.md` and `skills/mini-sdd-planner/SKILL.md:31-34`
  (no idempotency). Audit log appended by the developer —
  `agents/mini-sdd-developer.md:62-68`.
- **What is wrong:** re-running `/mini-sdd` re-creates `.spec/<slug>/` and the
  branch and **overwrites `plan.md`**, destroying the `## Audit` log and
  per-task commit hashes.
- **Why it matters (procedure):** loss of audit trail and execution history on
  any interrupted/re-run mini flow.

### M5 — Mini-SDD has no failure/repair cap
- **Where:** `agents/mini-sdd-developer.md:52` and `:54` (fix with another commit
  and re-tick, repeatedly).
- **What is wrong:** unlike full SDD's 3-cycle cap, the mini developer can loop
  indefinitely fixing tests/acceptance.
- **Why it matters (procedure):** unbounded retry on a flow that is supposed to
  be the "lean" option.

### M6 — Mini `plan.md` execution/audit edits are never committed
- **Where:** Developer checks boxes, appends commit hashes, and writes `## Audit`
  into `plan.md` (`agents/mini-sdd-developer.md:46,62-68`) but stages *"only the
  files each task touched"* (`:117-119`). There is no mini verifier to commit
  spec artifacts.
- **Why it matters (procedure):** the entire audit trail stays uncommitted in the
  working tree — lost on branch switch or if the user never opens a PR.

### M7 — Verifier "never modify" vs. its commit/push mandate
- **Where:** Role — `agents/sdd-verifier.md:12` (*"You never fix code"*). Step 9
  — `:46-50` (commit spec artifacts, push, open PR).
- **Why it matters (clarity):** the verifier is told it never modifies anything,
  yet it writes commits and pushes. Defensible (spec artifacts, not code) but
  unstated as the single allowed write surface → a model anchored on "never
  modify" may refuse to commit the spec files.

### M8 — Verifier cross-check trusts the unverifiable "files read" list
- **Where:** `agents/sdd-verifier.md:33` cross-checks the commit's file list vs.
  the log's `Files modified` (solid). But the log's `Context & Reference files
  read` (`agents/sdd-developer.md:56`) is never validated.
- **Why it matters (quality):** a developer can claim it read a Gold Standard it
  never opened; the verifier has no signal for skipped Reference reads beyond
  the developer's word.

### M9 — Corrupted instruction tail in the Developer agent
- **Where:** `agents/sdd-developer.md:128` — the file ends with a stray token:
  ```
  - Any surprise, warning, or follow-up.
  otes").
  ```
- **Why it matters (quality):** the `Done` section defines the developer's return
  contract to the Orchestrator and now terminates with malformed text; a model
  may treat `otes").` as an unterminated template field.

### M10 — Git-state assumptions are unchecked
- **Where:** Orchestrator branch step — `skills/sdd/SKILL.md:71-74`. Developer
  commit step — `agents/sdd-developer.md:34`. Verifier push/PR —
  `agents/sdd-verifier.md:46-50`.
- **What is wrong:** no handling for: branch already exists with uncommitted
  changes (checkout fails); non-git projects (the whole implement/verify chain
  assumes git); detached/misnamed HEAD on resume.
- **Why it matters (procedure):** the flow hard-assumes git but never validates
  it before delegating.

---

## Context / token-balance observations (quality, lower severity)

### T1 — Verifier is the token-heaviest agent with no sampling discipline
- **Where:** `agents/sdd-verifier.md:21,29` (read **every** task and fix file)
  plus scope + design + tasks.index + AGENTS/CLAUDE + a 4-axis review.
- **Why it matters (quality):** for a 6-task / 2-fix feature this is the densest
  context in the pipeline, with no guidance to review the branch diff as the
  primary artifact → attention dilution and shallow review on medium features.

### T2 — No cap on per-task Context/Reference files
- **Where:** Developer must read *every* Context + Reference file with *"no
  exceptions"* (`agents/sdd-developer.md:29`) plus `design.md` in full (`:26`)
  plus AGENTS/CLAUDE (`:27`). Tech Lead sets the counts with no hard cap
  (`agents/sdd-tech-lead.md` task-file rules).
- **Why it matters (quality):** an upstream over-listing forces a fat read per
  task.

### T3 — "Thin Orchestrator" is fat after Phase 0
- **Where:** Phase 0 silent research — `skills/sdd/SKILL.md:94-101` loads
  AGENTS+CLAUDE + codebase search + reference candidates into the long-lived
  Orchestrator context; that working memory is never offloaded.
- **Why it matters (quality):** orchestrator attention dilution across all
  subsequent phases.

### T4 — `"MAY load /writing-skill"` is non-deterministic
- **Where:** `agents/sdd-init.md:15`, `agents/sdd-tech-lead.md:15`,
  `agents/sdd-verifier.md:15`.
- **Why it matters (quality):** identical runs produce differently-structured
  documents depending on whether the model decides to load the skill.

---

## Severity index

| ID | Severity | One-line | Primary location |
|----|----------|----------|------------------|
| R1 | Required | Remove `agents-md` MCP dependency (6 sites) | `agents/sdd-init.md:28-37` + manifests + README |
| C1 | Critical | Resume re-implements done tasks (no completion state) | `skills/sdd/SKILL.md:76-81`, `agents/sdd-tech-lead.md:77-94` |
| C2 | Critical | Orchestrator forbids yet requires reading `verify.md` | `skills/sdd/SKILL.md:24` vs `:77-78` |
| H1 | High | Failure payload not threaded to Tech Lead | `skills/sdd/SKILL.md:217-224` |
| H2 | High | No regression-fix discipline on fix tasks | `agents/sdd-tech-lead.md:192-207` |
| H3 | High | Failure-cycle counter not persisted/threaded | `skills/sdd/SKILL.md:219` |
| H4 | High | "Bootstrap is guidance, not a gate" re-permits drift | `agents/mini-sdd-developer.md:32` |
| H5 | High | DI / Clean-Architecture wiring gate misses it | `agents/sdd-tech-lead.md:139`, `agents/sdd-developer.md:79-83` |
| M1 | Medium | scope vs. task acceptance drift | `agents/sdd-developer.md:28`, `agents/sdd-verifier.md:27` |
| M2 | Medium | Full vs. mini commit-retry inconsistency | `agents/sdd-developer.md:46` |
| M3 | Medium | Resume matrix has undefined half-states | `skills/sdd/SKILL.md:76-81` |
| M4 | Medium | Mini-SDD no resume; overwrites plan/audit | `skills/mini-sdd-planner/SKILL.md:31-34` |
| M5 | Medium | Mini-SDD no repair cap | `agents/mini-sdd-developer.md:52,54` |
| M6 | Medium | Mini `plan.md` audit edits never committed | `agents/mini-sdd-developer.md:117-119` |
| M7 | Medium | Verifier "never modify" vs. commit/push | `agents/sdd-verifier.md:12,46-50` |
| M8 | Medium | Verifier trusts unverifiable "files read" list | `agents/sdd-verifier.md:33` |
| M9 | Medium | Corrupted instruction tail in Developer | `agents/sdd-developer.md:128` |
| M10 | Medium | Git-state assumptions unchecked | `skills/sdd/SKILL.md:71-74` |
| T1 | Low | Verifier token load, no diff anchoring | `agents/sdd-verifier.md:21,29` |
| T2 | Low | No cap on per-task context/reference files | `agents/sdd-developer.md:29` |
| T3 | Low | Orchestrator fat after Phase 0 | `skills/sdd/SKILL.md:94-101` |
| T4 | Low | Non-deterministic `MAY load /writing-skill` | `agents/*:15` |

---

## Notes on what is working well (for balance)

- Context isolation per phase and the "Orchestrator reads only short reports +
  `tasks.index.md`" principle are well-articulated
  (`skills/sdd/SKILL.md:17-37`).
- `design.md` is correctly kept file-path-free and protected from edits during
  failure recovery (`agents/sdd-tech-lead.md:52,197`).
- Developer commit-verification discipline (`agents/sdd-developer.md:46`) and
  "match surrounding code / never invent signatures"
  (`agents/sdd-developer.md:93-97`) are strong anti-hallucination guards.
- Verifier log-vs-git cross-check on `Files modified`
  (`agents/sdd-verifier.md:33`) is a solid integrity check.
- PR-only / never-auto-merge invariant is consistently enforced
  (`skills/sdd/SKILL.md:46`, `agents/sdd-verifier.md:92`).

*End of report. No solutions or replacement code are included, per scope.*
