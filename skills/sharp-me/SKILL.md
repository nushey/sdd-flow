---
name: sharp-me
description: >
  Grill an idea or proposal with the user until it becomes a refined,
  well-defined concept, saved as a brief. Use when the user wants to explore
  better approaches, find blind spots, correct weaknesses, simplify scope, or
  sharpen an idea through questions and recommendations, or asks to be
  grilled on an idea before planning it. Preserve the
  intended outcome while improving how to achieve it. Refinement only; use
  sdd-plan to turn a brief into an implementation plan, sdd-debug to diagnose
  a failure, sdd-code-review for technical quality, and sdd-acceptance-review
  for requirements compliance.
---

# sharp-me

Help the user find a better way to accomplish what they want. Combine relevant
research, constructive recommendations, and conversation until the important
decisions are settled and the idea becomes a coherent, well-defined concept.

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
to obtain the evidence needed. If its result determines the approach, keep the
dependent decisions open and name the one to revisit; do not present the idea as
ready to plan.

## Deliver the brief

Finish when the decisions that shape the idea are settled and remaining
uncertainties have an agreed resolution path. Do not try to explore every
conceivable branch, require a fixed number of rounds, or keep interviewing after
the concept is clear.

Deliver a self-contained brief proportional to the idea. Include the following
where relevant, without empty sections or a transcript of the conversation:

- **Goal and scope:** the outcome, how success is recognized, and agreed
  constraints.
- **Refinements:** consequential changes to the original idea and why they
  improve it. If the original approach holds up, say so.
- **Decisions:** agreed choices, important tradeoffs, and their reasons.
- **Remaining uncertainty:** agreed evidence-gathering actions and the decisions
  they must resolve.

The brief states what to achieve and why; ordered steps and acceptance criteria
belong to `sdd-plan`, which reads the brief as input. Write in the user's
language. Save it to `.spec/<name>/brief.md` in the workspace, using a name that
identifies the idea and creating the folder when needed. Return its path. Stop
after the brief. Do not implement changes, execute proposed experiments, create
branches, commit, or start another flow.
