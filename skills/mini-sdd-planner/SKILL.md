---
name: mini-sdd-planner
description: >
  Mini-SDD Planner. Merges Init and Tech Lead roles into a single workflow.
  Creates a unified plan.md for smaller features or fixes. Runs in the
  Orchestrator; the resulting plan is then handed to the mini-sdd-developer
  subagent for implementation. Drives a structured grilling protocol to
  eliminate feature ambiguity, surface reference files, lock architecture
  fit, and declare a Bootstrap (skills + MCP calls) that the developer
  loads before coding.
---

# Mini-SDD Planner

For smaller features, refactors, or bug fixes where the full SDD flow is overkill. Merges **Init** (scope/intent) and **Tech Lead** (design/decomposition) into a single Orchestrator pass. Once `plan.md` is approved, the Orchestrator hands it to the `mini-sdd-developer` subagent.

## Core principles (non-negotiable)

1. **Zero assumptions.** When context is missing, ASK. Never suppose file paths, signatures, or behavior. Every claim must be grounded in a file you read.
2. **Existing architecture wins.** Detect the dominant pattern in the affected module and propose inside it. Never invent a new pattern when one already lives there.
3. **Reuse > create.** Edit > add file. Simpler > clever.

The Planner prevents four failure modes: hallucinated features, reinvented wheels, architecture drift, and silent context drift in the Developer. The grilling protocol (Phase B) prevents the first three; the `Bootstrap` section (Phase D) prevents the fourth. Skipping either is a protocol violation.

> **Harness-neutral output.** Refer to *what* to load (`load the <name> skill`, `invoke MCP tool mcp__<server>__<tool>`), never to harness-specific UI names ("the Skill tool", "the Agent tool"). Each harness has its own loader.

---

## Workflow

### 1. Intake & Setup
- Derive a `feature-slug` (kebab-case).
- **Resume check:** if `.spec/<feature-slug>/plan.md` already exists, do NOT recreate or overwrite it. Skip Phases A–D and hand the existing plan to the Orchestrator — the developer resumes by skipping tasks whose boxes are already checked (those carry a commit hash).
- Otherwise, create `.spec/<feature-slug>/` directory.
- If in a git repo, create a feature branch: `feature/<feature-slug>` (if it already exists and is clean, just check it out).

### 2. Phase A — Silent Research (do this BEFORE asking anything)

**You MUST complete this phase before asking the first question.** Reading first prevents biased questions and avoids burning user patience on things you could resolve yourself.

1. **Conventions** — Read `AGENTS.md` (and `CLAUDE.md` if present) at the project root. Note language, framework, folder layout, naming, testing setup, forbidden patterns.
2. **Affected area scan** — Search the codebase for the area touched by the feature. Use precise queries (semantic + exact match). Do NOT scan the whole repo.
3. **Reference candidates** — From the scan, identify files that look like "Gold Standard" templates: base components, abstract classes, shared hooks, existing services, similar features already shipped. Collect 2–5 candidates with one-line purpose each.
4. **Architecture detection** — Identify the dominant pattern in the affected module (container/presentational, hexagonal, screaming architecture, layered, etc.). Note it explicitly.
5. **Reuse opportunities** — Note any existing helper, util, or component the new code should consume instead of re-creating.

Write nothing yet. Hold this in working memory for Phase B.

### 3. Phase B — Structured Grilling (one question at a time)

You will conduct a focused interview with the user across **three mandatory categories**. Do not skip a category. Do not batch questions. Ask **one question at a time**, wait for the answer, then evaluate whether the answer opened a new branch before moving on.

#### Question format (HARD — every question follows this shape)

```
**Q<n> — <category>:** <the single, specific question>

**Why I'm asking:** <which downstream decision this unblocks>
**My recommendation:** <the answer you would give, with reasoning>
**Alternatives considered:** <1–2 options you ruled out and why>
```

Recommending an answer is mandatory — validating or correcting is far cheaper for the user than inventing.

#### Category 1 — Feature behavior (zero ambiguity)

Do not leave this category until ALL of these are unambiguous:
- Inputs (sources, types, validation)
- Outputs (shape, side effects, where they land)
- Edge cases (empty, error, loading, partial, unauthorized)
- Out of scope (what the user explicitly does NOT want)

Skip dimensions the prompt already covers. For the rest, ask — obvious assumptions are how features get hallucinated.

#### Category 2 — Reference files (no reinvention)

Show your Phase A candidates and ask which is the Gold Standard (e.g. *"Found `BaseTable.tsx`, `useFetchList.ts`, `EntityForm.tsx` — which is the Gold Standard? Any I missed?"*).

- If the user names a file you didn't find in Phase A → **read it before continuing**.
- If the user says "no reference, just build it" → record as explicit `Unverified assumption` in the plan. Never proceed silently.

#### Category 3 — Architecture fit (respect what exists)

Show the user the pattern you detected and confirm:

> "This module follows container/presentational with state in `<store>`. I'd keep the new feature inside that boundary. Confirm, or is this an exception?"

Never ask "what architecture should I use?" — that's an unanchored question. Always show the detected pattern first and ask for confirmation or correction.

#### Closure criteria (when to stop grilling)

Stop and proceed to Phase C **only when ALL of these are true**:
- Feature behavior is unambiguous (Category 1 fully resolved).
- At least one Reference File is named, OR the absence is recorded as risk (Category 2).
- Architecture fit is explicitly confirmed (Category 3).
- No remaining decision has two viable paths without a chosen one.
- All assumptions you would otherwise carry forward are either confirmed by the user or recorded explicitly.

**Hard cap:** 7 questions. If you would need an 8th, stop and tell the user this feature is too ambiguous for `mini-sdd` — recommend the full `/sdd` flow.

**Escape hatch:** If the user says "just infer it" or "anda nomás", stop the grilling, dump every remaining open question into the `Unverified assumptions` section of `plan.md`, and proceed.

### 4. Phase C — Anti-hallucination check (before writing plan.md)

Before writing `plan.md`, verify:
- Every Reference File path EXISTS (read it).
- Every library/import you plan to use is in `package.json` / `pyproject.toml` / equivalent.
- Every file path you list as "modify" EXISTS. Every "create" is explicit.
- Every claim about existing code (a base class, a util, a route) is grounded in a file you actually read, not assumed.

If any check fails, fix the plan or ask one more question. Do not write claims you have not verified.

### 5. Phase D — Create `plan.md`

Produce `.spec/<feature-slug>/plan.md`:

```markdown
# Plan: <Feature Name>

## Objective
One-sentence business goal.

## Acceptance Criteria
- [ ] Criterion 1 (observable/testable)
- [ ] Criterion 2

## Bootstrap (Developer loads this BEFORE writing any code)

> Machine-readable, harness-neutral. Any agent (Claude Code, Gemini CLI, Codex, …)
> reads this and uses its own loader to honor the contract. No UI-specific names.

### Skills to load
- `<skill-name>` — one-line reason (which paths/decisions this skill gates).
- (omit this subsection if no skill applies to the affected paths)

### MCP tools to (re-)invoke before coding
- Tool: `mcp__<server>__<tool>`
  Args: `{ "param1": "value", "param2": "value" }`
  Reason: why re-fetching matters (snapshot from planner may be stale,
  variable defs not yet retrieved, schema may have changed, …).
- (omit this subsection if no MCP context is required)

### Post-implementation validations (optional)
- Tool: `mcp__<server>__<tool>`
  Args: `{ ... }`
  Compare against: what aspect of the implementation this validates
  (visual parity vs Figma, schema diff vs DB, contract vs spec, …).
- (omit this subsection if not applicable)

## Confirmed Feature Behavior
- **Inputs:** ...
- **Outputs:** ...
- **Edge cases handled:** ...
- **Out of scope:** ...

## Technical Design
### Approach
2–4 sentences on HOW it will be implemented.
### Patterns & Conventions honored
- <pattern name> — confirmed in Phase B Category 3.
- <convention from AGENTS.md> — section/quote.
### Reference Files (Gold Standards — confirmed by user)
- path/to/file.ext — what to imitate from it.
### Reused (do NOT recreate)
- path/to/util.ts — existing helper this feature consumes.

## Tasks
1. [ ] **Task 1 Title**: Description.
   - Files: path/to/file (modify | create)
   - Reference: path/to/gold-standard.ext
2. [ ] **Task 2 Title**: ...

## Assumptions & Blind Spots

### Confirmed with user
- <thing> — answered in grilling Q<n>.

### Inferred from codebase (verified by reading)
- <thing> — grounded in path/to/file.ext.

### Unverified assumptions (RISK — Developer must confirm first)
- <thing> — why it could not be verified, and what to check before relying on it.
```

#### Bootstrap section — completeness rules (HARD)

- If you (the Planner) used ANY MCP tool during Phase A to obtain context
  the Developer will need (design tokens, screenshots, schemas, external
  docs, …), you MUST list the same tool + literal args under
  `### MCP tools to (re-)invoke before coding`. Embedding a snapshot in the
  plan is NOT a substitute — the Developer re-fetches to detect drift
  between planner-time and developer-time.
- If the feature touches paths whose convention is owned by a specialized
  skill known to the project (declared in `AGENTS.md` or `CLAUDE.md`),
  list that skill under `### Skills to load`.
- Arguments MUST be literal JSON the Developer can copy-paste directly into
  the tool call. No placeholders like `<fileKey>`. If you don't know the
  value, Phase A is incomplete.
- Omit empty subsections entirely (no empty headers). If all three would be empty, omit the whole `Bootstrap` section — the Developer treats its absence as "nothing to load".

---

## Rules (HARD)

- **One question at a time, with a recommendation.** No batched lists. Every question carries your recommended answer + reasoning.
- **No overengineering.** Reuse > create. Edit > add file. Simpler > clever.
- **Atomic tasks.** Each task is one committable unit. Prefer one Reference File per task; if none exists, record the absence under `Unverified assumptions`.
- **Harness-neutral wording.** Reference tools by full MCP identifier (`mcp__<server>__<tool>`) and skills by name. Never say "use the Skill tool" or "use the Agent tool" — those names exist only in Claude Code.

## Done

Report to the user:
- Path to `plan.md`.
- Summary of the technical approach (2 sentences).
- Number of tasks defined.
- Number of unverified assumptions flagged (so the user knows the risk surface).
- Whether the `Bootstrap` section is populated, and with how many skills / MCP calls / post-validations.
