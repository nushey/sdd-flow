---
name: sdd-review
description: >
  Delegate code review, acceptance review, or both to an isolated subagent
  that applies this skill without implementing changes. Use when the user
  asks to review files or a diff, or check an implementation against the
  original request or acceptance criteria.
---

# sdd-review

The invoking agent prepares the review request and delegates it to one isolated
subagent. That subagent loads this same skill and performs the review. Neither
agent fixes code, creates branches, commits, or pushes as part of the review.

## Invoking agent: prepare and delegate

1. Establish the scope using the table below. Resolve ambiguity and missing
   acceptance requirements with the user before delegation; ask one question
   at a time and wait for the answer.
2. Improve the user's query into a self-contained review prompt: make the target,
   selected checks, and supplied context explicit without changing intent, adding
   requirements, or prescribing findings. Preserve the original query alongside
   the refined request. Do not pass the implementer's conclusions as evidence.
3. Use the harness's native subagent mechanism to start one reviewer with a fresh
   context containing only the review prompt. Pass the absolute project root and
   this skill's absolute path, and require it to read the skill before reviewing.
   No registered reviewer role is required; the skill supplies its instructions.
   If isolated delegation is unavailable, stop and report that requirement;
   never perform the review in the invoking agent's context.
4. Wait for the reviewer's report and deliver its findings and coverage limitations
   to the user. Do not silently drop findings or turn unverified behavior into a
   success claim. If the reviewer needs missing information, ask the user and
   wait, then relay the answer to the reviewer.

The delegation prompt must identify the recipient as the **reviewer executing
this delegated request**, so loading this skill does not cause recursive delegation.
Include the following context with concrete values:

```text
Role: Reviewer executing this delegated request. Load the skill below and follow
its Reviewer workflow. Perform the review yourself; do not spawn another reviewer.
Project root: <absolute path>
Skill path: <absolute path to this SKILL.md>
Original user query: <verbatim query>
Refined review request: <clear request preserving the user's intent>
Selected checks: <code | acceptance | both>
Review target: <absolute file paths, or the exact diff/commit range requested>
Acceptance source: <original implementation request or criteria, only when applicable>
Relevant context: <user-supplied constraints and reference paths, when applicable>
Report destination: <return to invoking agent; file path only when requested>
```

Omit inapplicable fields. The reviewer must inspect the actual files and behavior;
the refined prompt is context, not a substitute for evidence.

## Reviewer workflow

When explicitly assigned the delegated reviewer role, apply the steps below
yourself. Do not delegate again. Return missing-information questions to the
invoking agent instead of assuming answers or asking the user directly.

## 1. Establish the review scope

Use the user's request to select the checks:

| Requested review | Required checks |
|------------------|-----------------|
| Code | Standards and reuse; code quality |
| Acceptance compliance | Acceptance and behavior |
| Both | All three |

Do not add acceptance checks to a code-only review or code-quality checks to an
acceptance-only review. If the delegated scope or target is ambiguous, return
the specific missing information to the invoking agent and stop until resolved.

For acceptance review, identify the original request or supplied acceptance
criteria. Request them through the invoking agent when missing; never infer
requirements from the code.

## 2. Research the actual implementation

- Read the project's applicable `AGENTS.md` and `CLAUDE.md` when present. Load
  the skills and invoke the context tools those rules require for the paths
  being reviewed.
- Read the requested files or diff, then the relevant callers and dependencies
  needed to understand the actual behavior. For a diff, review the changed
  behavior in context, rather than treating changed lines as the entire flow.
- For code review, search the affected area for existing components, helpers,
  and business logic that the implementation should reuse. Read the candidates
  before claiming that something was reimplemented.
- For acceptance review, trace each requested behavior through its implementation
  and relevant tests. Tests and implementation are evidence, not new requirements.

Keep research proportional to the requested target. Do not scan unrelated areas
or report unrelated pre-existing issues.

## 3. Apply the selected checks

### Standards and reuse

Verify the implementation follows the applicable project conventions and uses
existing system components and logic where they cover the same need. A duplication
finding must name the existing implementation, its location, and why it applies.
Do not recommend reuse merely because two pieces of code look similar.

### Code quality

Check Clean Code: readable method and variable names, understandable control flow,
focused methods, comments, and magic strings. Flag comments against the requested
no-comments standard, honoring explicit documentation requirements in project rules.
Distinguish meaningful literals from unexplained strings encoding domain rules or
repeated contracts; do not demand a constant for every string.

Apply SOLID to concrete problems, including mixed responsibilities (SRP) and
changes that expose an actual extension problem (OCP). Explain the responsibility,
dependency, or change scenario affected. Do not prescribe abstractions, layers, or
extensibility solely to satisfy a principle by name.

### Acceptance and behavior

Compare the actual behavior with the original request and supplied criteria:

- Identify requested behavior that is missing or implemented incorrectly.
- Identify added business decisions without support in the request, criteria,
  or confirmed existing rules: calculations, rounding, filters, defaults,
  caps, fallbacks, and edge-case behavior.
- Verify functionality with the smallest relevant executable check allowed by
  project rules. Never build when the project forbids it. Report the command and
  result; code inspection alone is not proof of successful execution.

Preserve supplied criterion IDs. When the source is prose, cite the relevant
requirement without inventing additional criteria. Mark behavior as not verified
when evidence is insufficient, rather than declaring it functional or defective.

## 4. Report evidence and stop

State the reviewed target and selected checks. Present findings by severity,
most consequential first. Each finding includes:

- **Criterion:** standards and reuse, code quality, or acceptance and behavior.
- **Location:** file and line, plus the existing implementation or requirement
  when relevant.
- **Evidence and impact:** the concrete code, input, caller, or execution result
  demonstrating the problem and its consequence.
- **Suggested correction:** the smallest change that addresses the problem.

Keep unresolved questions and missing evidence separate from confirmed findings.
Avoid generic observations such as "improve SOLID" and hypothetical defenses with
no demonstrated scenario.

For acceptance review, show each supplied criterion or requested behavior as met,
not met, or not verified, with evidence. End with checks executed and material
coverage limitations. If no findings are supported, say so within the reviewed
scope; do not claim the entire system is correct.

Return the report to the invoking agent in the user's language. Save it to a file
only when the user requested one, at the path provided in the delegation. Stop
after the report; corrections require a separate implementation request.
