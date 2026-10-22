---
name: sdd-plan
description: >
  Create a proportional implementation plan without writing code. Use when
  the user asks to plan a change, design an approach before coding, or break
  an epic into reviewable tasks. Reads a sharp-me brief or an sdd-debug
  diagnosis as input when one applies. Stop after the plan. Also loaded by
  mini-sdd as its planner.
---

# sdd-plan

Turn a defined request into a plan that someone can execute without guessing. Plan only: never implement code, create branches, commit, push, or delegate to subagents.

## Modes

- **Standalone** (the user asks for a plan): save the plan to `.spec/<plan-name>/plan.md`, using a name that identifies the plan, then return its path and stop. Create the folder when needed.
- **Mini-SDD** (loaded by `mini-sdd`): write the plan to the `.spec/<slug>/plan.md` path the flow provides and return control to `mini-sdd`. Approval and execution belong to that flow.

Both modes write the same plan format.

## Inputs

A `brief.md` from `sharp-me` or a `diagnosis.md` from `sdd-debug` is input, not a plan. When the user names one, or one was produced earlier in this conversation, read it, treat its decisions as settled, and write `plan.md` in the same `.spec/<name>/` folder. If more than one could apply, ask which.

From a diagnosis, the plan fixes the root cause at every affected point it lists. If an existing contract forces a symptom patch instead, raise it with the user before writing.

## 1. Research first

Before asking anything, read what answers questions for you:

1. `AGENTS.md` and `CLAUDE.md` at the project root — conventions, testing setup, forbidden patterns, and skills the project declares for specific paths.
2. The affected area only, with precise searches. Do not scan the whole repository.
3. Existing implementations to reuse or imitate: helpers, base classes, similar features already shipped. Note the dominant pattern of the module and plan inside it.
4. Current documentation through any available MCP tool when the change depends on a library or external system.

## 2. Ask only what changes the plan

A question is warranted only when its answer changes scope, acceptance, or approach, and research cannot settle it. Skip everything the request, the input, or the code already answers — there is no mandatory interview.

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

Executors start cold and read only the plan. Depth follows the request: a one-file fix is one criterion and one task; an epic gets tasks that can each be reviewed on their own. Every plan uses these headings, omitting `Bootstrap` and `Decisions and Risks` when they have no content:

```markdown
# Plan: <Feature Name>

## Objective
## Acceptance Criteria
- AC-001: <observable criterion>
## Bootstrap
## Approach
## Tasks
1. **<Task title>**: <what to do>
   - Covers: AC-001
   - Files: path/to/file (modify | create)
   - Reference: path/to/reference.ext
## Decisions and Risks
```

- **Objective** — the goal, and what is explicitly out of scope when that is not obvious.
- **Acceptance Criteria** — observable, testable, each with a stable ID: three digits, never renumbered or reused.
- **Approach** — how it fits the existing architecture, what it reuses, and the reference files to imitate.
- **Tasks** — ordered; each one is a committable unit with the files it touches. Name a `Reference:` when one exists. Every AC is covered by at least one task, and no task covers an unknown ID.
- **Decisions and Risks** — decisions taken (and whether the user confirmed them or they were assumed), plus known non-blocking risks.

The plan is the agreed contract: executors never edit it and record progress in `history.md`. It stays a single `plan.md` — no `scope.md`, `design.md`, or `tasks.index.md`.

`## Bootstrap` tells the executor what to load before coding. Include only the subsections that have entries:

```markdown
### Skills to load
- `<skill-name>` — the paths or decisions this skill governs.

### MCP tools to (re-)invoke before coding
- Tool: `mcp__<server>__<tool>`
  Args: `{ "param": "value" }`
  Reason: why the executor must re-fetch instead of trusting a snapshot.

### Post-implementation validations
- Tool: `mcp__<server>__<tool>`
  Args: `{ "param": "value" }`
  Compare against: what aspect of the implementation it validates.
```

- Every MCP tool you used for context the executor needs goes under `MCP tools to (re-)invoke` with the same literal args. An embedded snapshot is no substitute: the re-fetch detects drift.
- Every skill that `AGENTS.md` or `CLAUDE.md` ties to the affected paths goes under `Skills to load`.
- Args are literal JSON the executor can copy. No placeholders — if you lack a value, research is incomplete.

Refer to skills by name and to MCP tools by full identifier, never by the UI of a specific harness.

## Done

- Standalone: the saved `.spec/<plan-name>/plan.md` path, and nothing else happens.
- Mini-SDD: the saved path, a two-sentence summary of the approach, the number of tasks, the open risks, and what `Bootstrap` declares.
