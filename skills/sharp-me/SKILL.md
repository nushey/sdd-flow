---
name: sharp-me
description: >
  Collaboratively refine an idea or existing plan into an actionable plan.
  Use when the user wants to explore better approaches, find blind spots,
  correct weaknesses, simplify scope or execution, or sharpen a proposal
  through questions and recommendations. Preserve the intended outcome
  while improving how to achieve it. Planning only; use sdd-plan for a
  straightforward implementation breakdown, sdd-debug to diagnose a failure,
  and sdd-review to review code or acceptance compliance.
---

# sharp-me

Help the user find a better way to accomplish what they want. Combine relevant
research, constructive recommendations, and conversation until the important
decisions are settled and the result is a coherent action plan.

Preserve the user's intended outcome. Their initial approach can change; explain
why another approach serves that outcome better and agree on the change with
them. Keep a viable path forward rather than turning refinement into a verdict
on whether the user should pursue their idea.

Work with loose ideas and developed plans, in software or other domains. No
repository or fresh conversation is required. Use the existing
conversation and respect decisions the user has already made.

## Understand and investigate

Identify the desired outcome, the proposed approach, known constraints, and
confirmed decisions. Distinguish what the user wants to achieve from the means
they initially suggested. Clarify that distinction when it is ambiguous.

Read supplied material and investigate relevant context before asking the user
for information you can establish yourself. For repository work, read applicable
project instructions and the affected flow, callers, and existing solutions.
Consult available documentation or other sources when they can resolve a
material uncertainty. Keep research focused on the proposal; this is not a
general audit.

Ground factual claims in what you inspected. Separate demonstrated problems
from hypotheses and missing information. If a source or tool is unavailable,
make that limitation clear without guessing its contents.

## Refine through conversation

Look for opportunities as well as weaknesses: reuse, fewer steps, simpler
approaches, missing dependencies, better sequencing, and clearer ways to verify
success. Keep what already works. Do not manufacture criticism, alternatives,
or disagreement to make the session appear useful.

For a meaningful improvement, explain what would change, how it helps the
intended outcome, and its costs or tradeoffs. Recommend an approach when the
evidence supports one. Give the user enough context to decide rather than
merely asking them to design the solution.

Ask questions whose answers materially affect scope, acceptance, or approach
and cannot be resolved from the available context:

- Ask in brief rounds when the questions are independent and their prerequisites
  are settled. Ask a single question when its answer determines the direction.
- Wait for the user's response before continuing the round or acting on its
  answers. Do not ask a dependent question based on an answer you have not heard.
- Build the next round on what the user actually said. Incorporate corrections
  and reconsider affected recommendations rather than following a fixed checklist.
- Treat recommendations as proposals until agreed. Do not silently add business
  rules, defaults, scope, or acceptance criteria. Agreement on a general approach
  does not settle a separate functional decision.
- Keep consequential decisions and their reasons clear as the conversation
  evolves. Resolve conflicting answers with the user rather than choosing one.

The user owns the scope and may challenge a question, reject a recommendation,
or say they do not know. Progress comes from better decisions, not the number of
questions or the amount of disagreement. Do not repeat questions the context
already answers.

## Resolve uncertainty without guessing

Recognize questions that discussion alone cannot answer. If a decision needs
usage data, a prototype, an experiment, or another concrete comparison, explain
what evidence is missing and propose a focused way to obtain it. Agree with the
user on what to observe and how it will inform the decision. Do not repeatedly
rephrase the same question or present a speculative answer as settled.

An unresolved point must become either an agreed decision or an agreed action
to obtain the evidence needed. Put that action before work that depends on its
result. If its result determines the approach, keep downstream steps conditional
and identify the decision to revisit; do not claim the implementation is ready.

## Deliver the refined action plan

Finish when the decisions needed for the next actions are settled and remaining
uncertainties have an agreed resolution path. Do not try to explore every
conceivable branch, require a fixed number of rounds, or keep interviewing after
the plan is clear.

Deliver a self-contained plan proportional to the request. Include the following
where relevant, without empty sections or a transcript of the conversation:

- **Goal and scope:** the outcome and agreed constraints.
- **Refinements:** consequential changes to the original proposal and why they
  improve it. If the original approach holds up, say so.
- **Decisions:** agreed choices, important tradeoffs, and their reasons.
- **Actions:** concrete ordered steps, their dependencies, and the next action.
- **Verification:** observable results that show the goal has been achieved.
- **Remaining uncertainty:** agreed evidence-gathering actions and the decisions
  they must resolve before dependent work begins.

Write in the user's language. Save the refined plan to
`.spec/<plan-name>/plan.md` in the workspace, using a name that identifies the
plan and creating the folder when needed. Return its path. Stop after the plan.
Do not implement changes, execute proposed experiments, create branches, commit,
or start another flow.
The user may carry the refined plan into an implementation workflow separately.
