---
name: sdd-code-review
description: >
  Delegate technical code review of files, changes, or a diff to an isolated
  subagent. Evaluate code and test quality, reuse, project conventions, bugs,
  security, and data integrity without fixing the implementation. Save
  code-review.md under .spec/. Use sdd-acceptance-review to verify requirements.
---

# sdd-code-review

Review technical quality in context; no ticket or plan is required, and this
review does not certify requirements compliance. When invoked directly, follow
the Invoking agent workflow. When assigned the delegated reviewer role, follow
the Reviewer workflow instead.

Neither role fixes the implementation, creates branches, commits, or publishes
changes. Writing the report is part of the review.

## Invoking agent: prepare and delegate

1. Establish the exact review target: files, uncommitted changes, or the requested
   diff/commit range. Resolve ambiguous scope with the user before delegation;
   ask one question at a time and wait for the answer.
2. Resolve the report destination. When a plan exists for this work, use its
   folder under `.spec/`; otherwise create `.spec/<topic>/` for the review,
   including `.spec/` when absent. The report is always `code-review.md`.
3. Prepare a self-contained review prompt without changing intent, adding
   requirements, or prescribing findings. Preserve the original query alongside
   the refined request. Do not pass the implementer's conclusions as evidence.
4. Delegate to one reviewer using the harness's native mechanism, with a fresh
   context containing only this prompt. Require it to read this skill. No
   registered reviewer role is required. If isolated delegation is unavailable,
   report the limitation and stop; do not review in the invoking agent's context.
5. Wait for the reviewer, then deliver its findings, coverage limitations, and
   saved report path. Do not silently drop findings or turn unverified behavior
   into a success claim. If information is missing, ask the user, wait, and relay
   the answer to the reviewer.

Pass concrete values in the delegation prompt:

```text
Role: Reviewer executing this delegated request. Load the skill below and follow
its Reviewer workflow yourself; do not spawn another reviewer.
Project root: <absolute path>
Skill path: <absolute path to this SKILL.md>
Original user query: <verbatim query>
Refined review request: <clear request preserving intent>
Review target: <absolute file paths, uncommitted changes, or exact diff/commit range>
Relevant context: <applicable constraints and reference paths, when supplied>
Report destination: <absolute path to code-review.md in the resolved folder>
```

Omit `Relevant context` when inapplicable. The prompt does not replace inspection
of actual files and behavior.

## Reviewer workflow

Perform the review yourself; do not delegate again. If scope or required
information is unclear, return the specific question to the invoking agent and
wait instead of assuming an answer or asking the user directly.

### Research the implementation

Read applicable `AGENTS.md` and `CLAUDE.md`, load the skills and invoke the
context tools they require for the reviewed paths. Inspect the target and the
relevant callers and dependencies to understand changed behavior in context.
Keep research proportional; do not scan unrelated areas or report unrelated
pre-existing issues.

Search the affected area for existing components, helpers, and business logic
covering the same need. Read the candidates before claiming reimplementation.
A reuse finding must cite the existing implementation and explain why it applies;
similar-looking code alone is insufficient.

### Evaluate technical quality

| Area | Evaluation |
|---|---|
| Clean Code | Abstraction quality, simplicity, DRY, readable names and control flow, focused methods, method size, and parameter count. Explain concrete complexity rather than imposing arbitrary numerical limits. |
| SOLID | Evaluate SRP and whether the actual scenario warrants OCP or ISP. Identify the mixed responsibility, extension scenario, or interface obligation affected. Do not demand abstractions, layers, or speculative extensibility solely to satisfy a principle. |
| Tests | Evaluate meaningful behavioral assertions and FIRST: fast, independent, repeatable, self-validating, and timely. Check setup clarity, isolation, mocks, and whether tests detect the relevant failure instead of mirroring implementation details. Do not claim when a test was written without evidence. |
| Reuse and conventions | Verify reuse of applicable existing logic/components and adherence to system patterns, standards, formatting, and practices. |
| Bugs, security, and data integrity | Report demonstrated defects within the target's affected flow, with the input, caller, or execution evidence and its consequence. Do not expand into a general audit or invent hypothetical defenses. |

Distinguish meaningful literals from unexplained numbers or strings encoding
domain rules or repeated contracts; do not demand a constant for every literal.
Evaluate comments against explicit project or review instructions, including
documentation requirements, rather than assuming a universal no-comments rule.

Use the smallest relevant executable checks allowed by the project when needed
to verify a finding. Never build when forbidden. Record commands and results;
static inspection is not proof of successful execution. Do not add acceptance
criteria.

### Save the report and stop

Write the report in the user's language to the supplied `code-review.md` path,
creating its parent folder when needed. Use the following report structure and
section order. Keep headings, column names, severity labels, and field names as
shown; write their content in the user's language.

#### Severity

Use the same impact scale in both review skills:

| Severity | Meaning |
|---|---|
| Critical | A demonstrated defect causes system-wide failure, catastrophic data loss, or broad security compromise. |
| High | A demonstrated defect breaks a core flow or materially compromises security or data integrity. |
| Medium | A confirmed problem has localized behavioral impact or materially impairs maintainability or test reliability. |
| Low | A confirmed readability, convention, or maintainability issue has limited impact and no demonstrated functional failure. |

Assign severity from the evidenced impact, not hypothetical consequences.

#### Report template

```markdown
# Code review

## Scope

<Exact files, uncommitted changes, or diff/commit range reviewed; technical scope.>

## Findings

| # | Severity | File | What's wrong |
|---|---|---|---|
| F-001 | <severity> | <file:line> | <concise confirmed problem> |

## Evidence

### F-001 — <finding title>

- Area: <technical quality area>
- Expected: <applicable rule or convention and its source>
- Observed: <actual implementation or behavior>
- Evidence: <concrete code, input, caller, or execution result demonstrating the problem>
- Impact: <concrete consequence>
- Suggested correction: <smallest change addressing the problem>

## Checks and limitations

### Checks

<Executed commands and results.>

### Limitations and open questions

<Material coverage limitations, missing evidence, and unresolved questions.>
```

Order findings by severity: `Critical`, `High`, `Medium`, `Low`. Number them
`F-001`, `F-002`, and so on in report order. Each Findings row must have one matching
Evidence subsection with the same ID. Cite existing implementations or project
rules where relevant. Avoid generic advice such as "improve SOLID".

If no findings are supported, replace the Findings table with
`No confirmed findings` and leave Evidence without finding entries. Still report
checks and limitations; do not claim the entire system is correct. Missing
evidence and unresolved questions belong in Limitations and open questions,
not in the confirmed findings table.

Return the findings, limitations, and saved path to the invoking agent. Stop;
corrections require a separate implementation request.
