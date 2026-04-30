---
name: mini-sdd-planner
description: >
  Mini-SDD Planner. Merges Init and Tech Lead roles into a single workflow.
  Creates a unified plan.md for smaller features or fixes. Orchestrator-only,
  no subagents.
---

# Mini-SDD Planner

This skill is designed for smaller features, refactors, or bug fixes where the full SDD flow is overkill. It merges the **Init** (scope/intent) and **Tech Lead** (design/decomposition) roles into a single pass performed by the Orchestrator.

## Workflow

### 1. Intake & Setup
- Derive a `feature-slug` (kebab-case).
- Create `.spec/<feature-slug>/` directory.
- If in a git repo, create a feature branch: `feature/<feature-slug>`.

### 2. Interactive Refinement (Triage)
- **Analyze** the user prompt for ambiguity.
- **Ask** 1-3 targeted questions if scope, behavior, or critical integrations are unclear.
- **Validate** assumptions with the user before proceeding to research.

### 3. Research & Context Gathering
- Read `AGENTS.md` (and `CLAUDE.md` if present) for project rules.
- Search the codebase to understand the affected area.
- Identify "Gold Standard" reference files that serve as templates for the new code.

### 4. Create `plan.md`
Produce `.spec/<feature-slug>/plan.md` with the following structure:

```markdown
# Plan: <Feature Name>

## Objective
One-sentence business goal.

## Acceptance Criteria
- [ ] Criterion 1 (observable/testable)
- [ ] Criterion 2

## Technical Design
### Approach
2-4 sentences on HOW it will be implemented.
### Patterns & Conventions
Which existing patterns are being followed.
### Reference Files
- path/to/file.ext (The template to follow)

## Tasks
1. [ ] **Task 1 Title**: Description of what to do.
   - Files: path/to/file (modify | create)
2. [ ] **Task 2 Title**: ...
```

## Rules (HARD)
- **No Overengineering**: Keep the design simple and idiomatic to the project.
- **Atomic Tasks**: Each task should be a logical, committable unit of work.
- **Verification-Ready**: Tasks must include enough detail for the Implementer to verify them.
- **Reference-Driven**: Always point to at least one reference file for any non-trivial change.

## Done
Report to the user:
- Path to `plan.md`.
- Summary of the technical approach.
- Number of tasks defined.
