---
name: sdd-plan
description: >
  Create a proportional implementation plan without writing code. Use when
  the user asks to plan a change, design an approach before coding, or break
  an epic into reviewable tasks. Stop after the plan. Also loaded by
  mini-sdd as its planner.
---

# sdd-plan

Turn a request into a plan that someone can execute without guessing. Plan only: never implement code, create branches, commit, push, or delegate to subagents.

## Modes

- **Standalone** (the user asks for a plan): deliver the plan in the chat and stop. Write it to `.spec/<slug>/plan.md` only when the user asks for a file.
- **Mini-SDD** (loaded by `mini-sdd`): write the plan to the `.spec/<slug>/plan.md` path the flow provides, using the Mini-SDD contract below, and return control to `mini-sdd`. Approval and execution belong to that flow.

## 1. Research first

Before asking anything, read what answers questions for you:

1. `AGENTS.md` and `CLAUDE.md` at the project root — conventions, testing setup, forbidden patterns, and skills the project declares for specific paths.
2. The affected area only, with precise searches. Do not scan the whole repository.
3. Existing implementations to reuse or imitate: helpers, base classes, similar features already shipped. Note the dominant pattern of the module and plan inside it.
4. Current documentation through any available MCP tool when the change depends on a library or external system.

## 2. Ask only what changes the plan

A question is warranted only when its answer changes scope, acceptance, or approach, and research cannot settle it. Skip everything the request or the code already answers — there is no mandatory interview.

Ask one question at a time, with your recommendation and the reason, so the user can confirm instead of invent:

```
**<the specific question>**
Recommendation: <your answer and why>. Alternative: <the option you ruled out and why>.
```

- If the user names a file you did not read, read it before continuing.
- If the user says "just infer it", adopt your recommendations and record each one as an assumed decision in the plan.
- A plan is ready only when no blocking decision is open. Known risks may stay documented; blocking decisions never pass to the implementer.
- In Mini-SDD mode, if the change needs more than a handful of questions or more than ~5 tasks to become unambiguous, say so and recommend the full `/sdd` flow instead.

## 3. Verify before writing

- Every path you list as modified or as a reference exists and you read it. Every new file is marked as created.
- Every library you plan to use is already a project dependency, or the plan says it adds one.
- Every claim about existing code is grounded in a file you read.

If a check fails, fix the plan or ask one more question.

## 4. Write the plan

Depth follows the request: a one-file fix fits in a few lines; an epic gets tasks that can each be reviewed on their own. Include only sections with content — no empty headers or ritual confirmations.

- **Objective and scope** — the goal, and what is explicitly out of scope when that is not obvious.
- **Acceptance** — observable, testable criteria, each with a stable ID: `AC-001`, `AC-002`, … (three digits, never renumbered or reused).
- **Approach** — how it fits the existing architecture, what it reuses, and the reference files to imitate.
- **Steps** — ordered, each one a reviewable unit with the files it touches and the AC IDs it covers. Every AC is covered by at least one step.
- **Decisions and risks** — decisions taken (and whether the user confirmed them or they were assumed), plus known non-blocking risks. Omit when there are none.

### Mini-SDD contract

The `mini-sdd-developer` starts cold and reads only the plan, so a Mini-SDD plan uses these headings:

```markdown
# Plan: <Feature Name>

## Objective
## Acceptance Criteria
- [ ] AC-001: <observable criterion>
## Bootstrap
## Approach
## Tasks
1. [ ] **<Task title>**: <what to do>
   - Covers: AC-001
   - Files: path/to/file (modify | create)
   - Reference: path/to/reference.ext
## Decisions and Risks
```

Each task is one committable unit; the developer checks its box and appends the commit hash. Name a `Reference:` per task when one exists. Every task lists the AC IDs it covers; every AC is covered by at least one task, and no task covers an unknown ID. A Mini-SDD plan stays a single `plan.md` — no `scope.md`, `design.md`, or `tasks.index.md`.

`## Bootstrap` tells the developer what to load before coding. Include only the subsections that have entries, and omit the whole section when none do:

```markdown
### Skills to load
- `<skill-name>` — the paths or decisions this skill governs.

### MCP tools to (re-)invoke before coding
- Tool: `mcp__<server>__<tool>`
  Args: `{ "param": "value" }`
  Reason: why the developer must re-fetch instead of trusting a snapshot.

### Post-implementation validations
- Tool: `mcp__<server>__<tool>`
  Args: `{ "param": "value" }`
  Compare against: what aspect of the implementation it validates.
```

- Every MCP tool you used for context the developer needs goes under `MCP tools to (re-)invoke` with the same literal args. An embedded snapshot is no substitute: the re-fetch detects drift.
- Every skill that `AGENTS.md` or `CLAUDE.md` ties to the affected paths goes under `Skills to load`.
- Args are literal JSON the developer can copy. No placeholders — if you lack a value, research is incomplete.

Refer to skills by name and to MCP tools by full identifier, never by the UI of a specific harness.

## Done

- Standalone: the plan in the chat, or the saved path when asked, and nothing else happens.
- Mini-SDD: the saved path, a two-sentence summary of the approach, the number of tasks, the open risks, and what `Bootstrap` declares.
