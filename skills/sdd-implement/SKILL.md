---
name: sdd-implement
description: >
  Implement an existing plan, in full or by selected points, after resolving
  ambiguities and technical decisions with the user. Use when the user asks
  to execute a plan from a file or the conversation. Supports the current
  session or an isolated subagent, keeps cumulative execution history, and
  never commits. Planning, debugging, and refinement belong to sdd-plan,
  sdd-debug, and sharp-me.
---

# sdd-implement

Follow the existing plan and the user's agreed clarifications. Resolve what is
needed to implement it, then execute the selected points. Do not write a new
plan, use the original as an execution log, or create commits. Do not ask whether
to commit. Full SDD and Mini-SDD keep their own execution workflows; this skill
is an independent way to implement a plan.

In either execution mode, load and apply `writing-agents` in the writer's own
context before drafting history entries, delegation prompts, or execution
reports. A delegated developer must load it itself. Preserve the original plan,
history format, and delivery contract defined here.

## Prepare the execution with the user

Read the supplied plan in full. Accept any format, from a file or the
conversation; no particular template, criterion IDs, or task numbering is
required. Identify the plan from the request and ask when its source is unclear.

Keep the plan and its history under `.spec/<plan-name>/` in the target workspace:

- For a plan already there, keep its original file and content.
- For an external file or a plan in the conversation, create the folder and
  save the supplied content as `plan.md`, without rewriting or expanding it.
- Read `history.md` if it exists. Otherwise create it for this execution.
  Reuse that same file across runs, preserving earlier entries.

Establish the following from the user's request, asking for what is missing:

- **Points:** if the plan has no clear points, clarify with the user what to
  implement. If points are clear but the user did not select any, ask whether
  to implement all or a selection. Preserve their labels or wording when
  identifying the selection; do not turn clarification into a replacement plan.
- **Execution mode:** ask whether to implement in the current session or in an
  isolated subagent. Respect an already stated choice. A fresh chat can execute
  in that same session; a subagent is optional.

Read the applicable project instructions, selected implementation area, and
referenced files. Load the skills and invoke the context tools required by the
project or the plan. Investigate existing contracts and reusable implementations
before asking the user for facts the code already establishes.

Identify ambiguities, missing technical direction, and dependencies affecting
the selected points. When the plan does not explain how to implement the
expected result, discuss the approach with the user using the investigated
context. Explain relevant alternatives and tradeoffs rather than silently
choosing functional behavior.

When a selected point depends on unselected work, communicate that dependency
and agree with the user how to proceed before expanding the selection. The
`Tasks` line of the latest history entry establishes what is already done.

Ask concise questions and wait for answers. Implement only after the necessary
decisions are resolved. Start this run's history entry before implementation,
with the selected points pending and the agreed clarifications. Never edit the
plan.

## Choose the agreed execution mode

### Current session

Implement directly using the workflow below. No subagent is required.

### Isolated subagent

Use the harness's native delegation mechanism. No registered developer role is
required; the subagent loads this skill. Pass concrete values for:

```text
Role: Developer executing this delegated request. Read the skill below and
implement the agreed points yourself; do not delegate again or ask the user
to choose the execution mode or points again.
Project root: <absolute path>
Skill path: <absolute path to this SKILL.md>
Plan path: <absolute path to the original or imported plan>
History path: <absolute path to history.md>
Selected points: <the agreed selection, using the plan's labels or wording>
Agreed clarifications: <the decisions resolved with the user>
Relevant context: <reference paths and project constraints needed for execution>
Commits: do not create commits.
Report destination: return the outcome to the invoking agent.
```

The delegated developer reads the plan and history and follows the implementation
workflow below. It does not repeat preparation choices or delegate recursively.
Questions discovered during implementation go to the invoking agent, which asks
the user, waits, and relays the answer. The developer records the resulting
decisions in the same history.

If delegation is unavailable, inform the user and ask how to proceed; do not
silently change their chosen execution mode. The invoking agent delivers the
developer's result after it finishes.

## Implement, verify, and record

Implement the agreed points following the plan, clarifications, and applicable
project rules. Use the existing architecture and referenced patterns. Keep work
within the selected scope; technical clarification does not authorize additional
features or unrelated refactors.

If implementation reveals a missing decision, contradiction, or dependency that
changes the agreed work, consult the user before continuing the affected work.
Record the agreement in the history instead of rewriting the plan.

Verify the selected work against the expected results using the smallest relevant
executable checks allowed by the project. Honor the plan's applicable validation
requirements. Never build when project rules forbid it. Report what was actually
checked and its result; distinguish completed work from failed or unverified
behavior.

`history.md` is the only record of progress. Each run appends one entry in this
shape, preserving earlier entries and omitting empty lines:

```markdown
## Run <n> — <YYYY-MM-DD> — sdd-implement
- Tasks: <plan label> done, <plan label> pending
- ACs: AC-001 met — <evidence>; AC-002 unverified — <why>
- Decisions: <agreed with the user during the run>
- Checks: <command or validation> → <result>
```

Update the entry as points complete, so a stopped run still shows what is done.
Mention blockers on the line they affect.

Finish with the plan and history paths, points completed, verification results,
and any pending decisions or blockers. Do not create commits, including commits
of the history or commits requested by the source plan.
