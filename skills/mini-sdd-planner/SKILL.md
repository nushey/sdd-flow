---
name: mini-sdd-planner
description: >
  Mini-SDD Planner. Merges Init and Tech Lead roles into a single workflow.
  Creates a unified plan.md for smaller features or fixes. Orchestrator-only,
  no subagents. Drives a structured grilling protocol to eliminate
  feature ambiguity, surface reference files, and lock architecture fit
  before any plan is written.
---

# Mini-SDD Planner

This skill is for smaller features, refactors, or bug fixes where the full SDD flow is overkill. It merges **Init** (scope/intent) and **Tech Lead** (design/decomposition) into a single Orchestrator pass.

The Planner exists to PREVENT three failure modes:
1. **Hallucinated features** — implementing behavior the user never asked for.
2. **Reinvented wheels** — rebuilding components, hooks, services, or base classes that already exist.
3. **Architecture drift** — ignoring patterns the surrounding code already enforces.

The grilling protocol below is the mechanism that prevents them. Skipping it is a protocol violation.

---

## Workflow

### 1. Intake & Setup
- Derive a `feature-slug` (kebab-case).
- Create `.spec/<feature-slug>/` directory.
- If in a git repo, create a feature branch: `feature/<feature-slug>`.

### 2. Phase A — Silent Research (do this BEFORE asking anything)

Asking the user questions you could have answered yourself is the fastest way to lose their patience and to bias their answers with your own gaps. Read first.

**You MUST complete this phase before asking the first question.**

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

Recommending an answer is mandatory. It exposes your assumptions and reduces the cognitive load on the user. A user who only has to validate or correct beats a user who has to invent.

#### Category 1 — Feature behavior (zero ambiguity)

Do not leave this category until ALL of these are unambiguous:
- Inputs (sources, types, validation)
- Outputs (shape, side effects, where they land)
- Edge cases (empty, error, loading, partial, unauthorized)
- Out of scope (what the user explicitly does NOT want)

If the user's prompt already covers one of these dimensions, do not ask again. If it doesn't, ask — even if the answer feels obvious. Obvious assumptions are how features get hallucinated.

#### Category 2 — Reference files (no reinvention)

Show the user the candidates you found in Phase A and ask which is the Gold Standard:

> "I found `path/to/BaseTable.tsx`, `path/to/useFetchList.ts`, and `path/to/EntityForm.tsx` as candidates that match the shape of this feature. Which should I treat as the Gold Standard to imitate? Is there another file I missed?"

If the user says "there is no reference, just build it" — this becomes an explicit `Unverified assumption` in the plan, flagged as risk. Do not silently proceed without recording it.

If the user names a file you didn't find in Phase A, **read it before continuing** to confirm it exists and you understand its shape.

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

### Unverified assumptions (RISK — Implementer must confirm first)
- <thing> — why it could not be verified, and what to check before relying on it.
```

---

## Rules (HARD)

- **Research before asking.** Phase A is mandatory and runs before the first question.
- **One question at a time.** No batched lists. No "while we're at it".
- **Always recommend an answer.** Every question carries your recommended answer and reasoning.
- **Reference Files are not optional.** Either name one, or record its absence as risk.
- **Architecture is detected, not invented.** Confirm the existing pattern; never propose a new one for a small feature.
- **No overengineering.** Reuse > create. Edit > add file. Simpler > clever.
- **Atomic tasks.** Each task is one committable unit, with at least one Reference File.
- **No claim without grounding.** Every path, library, or pattern in `plan.md` traces back to a file you read or an answer the user gave.

## Done

Report to the user:
- Path to `plan.md`.
- Summary of the technical approach (2 sentences).
- Number of tasks defined.
- Number of unverified assumptions flagged (so the user knows the risk surface).
