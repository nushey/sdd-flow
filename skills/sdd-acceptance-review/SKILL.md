---
name: sdd-acceptance-review
description: >
  Delegate verification of an implementation against a ticket, plan, or supplied
  acceptance criteria to an isolated subagent. Prioritize the ticket when it
  conflicts with the plan; ask for missing criteria when neither exists. Save
  acceptance-review.md under .spec/ without fixing the implementation.
  Use sdd-code-review for technical quality.
---

# sdd-acceptance-review

Verify fulfillment of requirements using actual implementation and behavior as
evidence. When invoked directly, follow the Invoking agent workflow. When
assigned the delegated reviewer role, follow the Reviewer workflow instead.

Neither role fixes the implementation, creates branches, commits, or publishes
changes. Writing the report is part of the review.

In each role's own context, load and apply `writing-agents` before drafting
delegation prompts or the review report. The delegated reviewer must load it
itself. Preserve this skill's report template, evidence rules, and delivery contract.

## Invoking agent: prepare and delegate

1. Establish the review target and requirements sources. Read the ticket and its
   acceptance criteria when available, and the plan when available. Review both
   if supplied; the ticket takes precedence where they conflict. If neither
   exists, use criteria already supplied by the user; if none were supplied,
   ask for them and wait before proceeding. Never invent criteria or infer them
   from code. Resolve ambiguous scope or missing requirements one question at a
   time, waiting for each answer.
2. For Mini-SDD, use `plan.md` and its `AC-NNN` IDs as the acceptance source and
   an explicit `<base>..<end>` commit range as the implementation target. Read
   the persisted base from `history.md` and establish the end commit explicitly
   with the user. The base alone does not define the range or trigger a review.
   A supplied ticket retains precedence over conflicting plan points.
3. Resolve the report destination. When a plan exists, use its folder under
   `.spec/`; otherwise create `.spec/<topic>/` for this review, including
   `.spec/` when absent. The report is always `acceptance-review.md`.
4. Prepare a self-contained prompt preserving the original query alongside the
   refined request. Make the target, sources, and constraints explicit without
   changing intent, adding requirements, or prescribing findings. Do not pass
   the implementer's conclusions as evidence. Use the harness's native mechanism
   to start one reviewer with a fresh context containing only this prompt and
   require it to read this skill. No registered reviewer role is required.
   If isolated delegation is unavailable, report that limitation and stop;
   do not review in the invoking agent's context.
5. Wait for the reviewer, then deliver its findings, compliance results,
   limitations, and saved report path. Do not silently drop findings or turn
   unverified behavior into a success claim. If information is missing, ask the
   user, wait, and relay the answer to the reviewer.

Pass concrete values in the delegation prompt:

```text
Role: Reviewer executing this delegated request. Load the skill below and follow
its Reviewer workflow yourself; do not spawn another reviewer.
Project root: <absolute path>
Skill path: <absolute path to this SKILL.md>
Original user query: <verbatim query>
Refined review request: <clear request preserving intent>
Review target: <absolute file paths, uncommitted changes, or exact diff/commit range>
Acceptance sources: <ticket, plan paths, and/or user-supplied criteria>
Relevant context: <applicable constraints and reference paths, when supplied>
Report destination: <absolute path to acceptance-review.md in the resolved folder>
```

Omit `Relevant context` when inapplicable. Sources define requirements;
implementation and tests provide evidence. Inspect both rather than relying on
the prompt alone.

## Reviewer workflow

Perform the review yourself; do not delegate again. If the target, requirements,
or other required information are unclear or missing, return the specific question
to the invoking agent and wait instead of assuming an answer or asking the user
directly.

### Establish requirements and inspect behavior

Read the supplied ticket, plan, or user criteria. Review ticket and plan when both
exist. Preserve their IDs; for prose requirements, cite the relevant passage
without inventing additional criteria. Document conflicting plan points and
evaluate compliance against the ticket for those conflicts. Do not treat a
conflicting plan point as an additional binding requirement. Never infer
requirements from the implementation.

For Mini-SDD, keep plan criteria and the supplied commit range separate;
developer reports and recorded AC statuses do not prove compliance.

Read applicable `AGENTS.md` and `CLAUDE.md`, load the skills and invoke the context
tools they require for the reviewed paths. Inspect the requested target, relevant
callers and dependencies, and trace each requirement through implementation and
tests. For a diff, inspect changed behavior in context. Keep research proportional
and do not report unrelated pre-existing issues.

### Verify fulfillment

- Identify requested behavior that is missing or implemented incorrectly and
  plan points that were not implemented correctly.
- Identify added business decisions unsupported by the request, criteria, or
  confirmed existing rules: calculations, rounding, filters, defaults, caps,
  fallbacks, and edge-case behavior.
- Use tests as evidence of required behavior. Do not turn this into an evaluation
  of internal test quality, Clean Code, or SOLID; those belong to code review.
- Verify functionality with the smallest relevant executable check allowed by
  project rules. Never build when forbidden. Record commands and results; code
  inspection alone is not proof of successful execution.

Mark insufficiently evidenced behavior as not verified, rather than declaring it
functional or defective. Tests and implementation do not create requirements.

### Save the report and stop

Write the report in the user's language to the supplied `acceptance-review.md`
path, creating its parent folder when needed. Use the following report structure
and section order. Keep headings, column names, severity labels, status values,
and field names as shown; write their content in the user's language.

#### Severity

Use the same impact scale in both review skills:

| Severity | Meaning |
|---|---|
| Critical | A demonstrated defect causes system-wide failure, catastrophic data loss, or broad security compromise. |
| High | A demonstrated defect breaks a core flow or materially compromises security or data integrity. |
| Medium | A confirmed problem has localized behavioral impact or materially impairs maintainability or test reliability. |
| Low | A confirmed readability, convention, or maintainability issue has limited impact and no demonstrated functional failure. |

Assign severity from the evidenced impact, not hypothetical consequences. This
scale classifies acceptance findings; it does not add technical quality checks.

#### Report template

```markdown
# Acceptance review

## Scope

<Exact files, uncommitted changes, or diff/commit range reviewed; requirements
sources; ticket/plan conflicts and their resolution.>

## Coverage

| Criteria | Status | Evidence |
|---|---|---|
| <source ID or relevant passage> | <Met, Not met, or Not verified> | <supporting reference, finding ID, or missing evidence> |

## Findings

| # | Severity | Criteria | File | What's wrong |
|---|---|---|---|---|
| F-001 | <severity> | <source ID or relevant passage> | <file:line when available> | <concise confirmed mismatch> |

## Evidence

### F-001 — <finding title>

- Expected: <requirement, its source, and criterion ID or relevant passage>
- Observed: <actual implementation or behavior>
- Evidence: <concrete code, input, caller, or execution result demonstrating the mismatch>
- Impact: <concrete consequence>
- Suggested correction: <smallest change addressing the mismatch>

## Checks and limitations

### Checks

<Executed commands and results.>

### Limitations and open questions

<Material coverage limitations, missing evidence, and unresolved questions.>
```

Coverage must include every supplied requirement or requested behavior, preserving
its ID or citing its passage. Use only `Met`, `Not met`, or `Not verified` as status
values. Provide supporting evidence for `Met`, link the confirmed finding for
`Not met`, and state the missing evidence for `Not verified`. Explain ticket
precedence for conflicting plan points in their coverage evidence.

Order findings by severity: `Critical`, `High`, `Medium`, `Low`. Number them
`F-001`, `F-002`, and so on in report order. Each Findings row must have one matching
Evidence subsection with the same ID.

If no findings are supported, replace the Findings table with
`No confirmed findings` and leave Evidence without finding entries. Still report
coverage, checks, and limitations; do not claim the entire system is correct.
Missing evidence and unresolved questions belong in Coverage and Limitations and
open questions, not in the confirmed findings table.

Return the compliance results, findings, limitations, and saved path to the
invoking agent. Stop; corrections require a separate implementation request.
