---
name: mini-sdd-implementer
description: >
  Mini-SDD Implementer. Merges Developer and Verifier roles into a single workflow.
  Executes plan.md sequentially, committing and verifying as it goes.
  Orchestrator-only, no subagents.
---

# Mini-SDD Implementer

This skill is the counterpart to `mini-sdd-planner`. It takes a `plan.md` and executes it to completion. It handles implementation, testing, and verification in a tight loop.

## Workflow

### 1. Sequential Execution
For each task in `plan.md`:
- **Read**: Understand the task and the referenced files.
- **Implement**: Apply surgical changes to the codebase.
- **Verify (Light)**: Run lint or typecheck on affected files if available.
- **Commit**: Create a conventional commit: `<type>(<slug>): <description>`.
- **Log**: Update `plan.md` by checking the task box and adding the commit hash next to it.

### 2. Final Verification
Once all tasks are done:
- **Run Tests**: Execute the project's test suite (if any).
- **Check Acceptance Criteria**: Review the `Acceptance Criteria` section in `plan.md` and verify each one is met.
- **Refinement**: If anything fails, fix it and commit the patch.

### 3. Finalize
- **PR Creation**: If instructed, use the `pr-creation` skill to open a pull request.
- **Cleanup**: Delete the `.spec/<feature-slug>/` folder if the user prefers, or leave it for history.

## Rules (HARD)
- **Convention First**: Follow `AGENTS.md` and `CLAUDE.md` rules above all else.
- **Surgical Changes**: Only modify what is necessary for the task. No unrelated refactors.
- **Verification is Mandatory**: Never skip verification steps. A task is not done until it's verified.
- **Sequential**: Complete one task fully (including commit) before moving to the next.

## Done
Report to the user:
- Total tasks completed.
- Commit history (hashes).
- Final test results.
- PR URL (if created).
