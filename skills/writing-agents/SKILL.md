---
name: writing-agents
description: >
  Create and revise instructions and operational content that agents use to
  execute or coordinate work: AGENTS.md, CLAUDE.md, SKILL.md, prompts, plans,
  briefs, diagnoses, tasks, histories, and reports. Apply proactively during
  relevant writing tasks, without requiring an explicit invocation or an
  existing draft. Preserve requirements, behavior, and evidence. For content
  intended for people to understand, use writing-humans.
---

# Writing agents

Make instructions and operational content concise, clear, and usable by agents.
Preserve what the agent must do, when it must do it, and under which constraints,
along with the context and evidence it needs. Reduce wording only when it
preserves that precision.

## Choose by purpose

Use this skill for instructions agents execute and for context, decisions,
evidence, and state they consume to continue work. This includes this plugin's
plans, briefs, diagnoses, specifications, tasks, histories, and operational
reports, even when a person also reviews or approves them.

Choose by the content's consumer and purpose, not its author, file extension,
or technical vocabulary. A README explaining a system to people or an explanation
about agents belongs to `writing-humans`. In mixed documents, apply each skill
to the sections serving its purpose. Apply this skill within the requested
writing task; it does not authorize additional documents or work.

## Prepare

Identify whether the task is creation or revision, its purpose, consumer, scope,
requirements, and output contract. Use the language specified by the request or
producing workflow. When revising, preserve each passage's language, including
mixed-language texts; do not translate.

### Create

Read the request and available source material, including the context needed to
understand references. No existing draft is required. Identify the requested
directives: action, condition, scope, obligation or permission, prohibition,
exception, default value, sequence, and output format. Record the reason when
provided. Identify the context, decisions, evidence, and state the consumer needs.
For multiple outputs, cover the requirements of all of them.

Separate confirmed decisions and demonstrated facts from hypotheses, missing
evidence, and open questions. Do not turn descriptive material into commands.
Organize the content so the agent can use it without unstated context.

### Revise

Read the current version of the complete text and the context needed to
understand its references.

Inventory each directive with its location: action, condition, scope,
obligation or permission, prohibition, exception, default value, sequence,
and output format. Record the reason when the text provides one. If the
request spans multiple files, the inventory must cover all of them.
Also identify the operational context, decisions, evidence, state, and uncertainty
that must survive the revision.

Identify concrete problems before editing:

| Problem | What to check |
|---|---|
| Repetition | Two passages give the same instruction with the same scope and conditions. |
| Fragmentation | A rule, its conditions, or its exceptions are separated. |
| Specific case | A general rule already covers it; check whether it adds a nuance before merging. |
| Ambiguity | It is unclear who acts, on what, when, or with what result. |
| Inconsistent terminology | Several names refer to the same thing, or one name refers to different things. |
| Filler | Preambles, emphasis, or justifications merely restate a directive. |
| Contradiction | Two instructions require incompatible behavior under the same conditions. |

The frontmatter description, templates copied verbatim, and examples showing
how to apply a rule may need to repeat content. Evaluate their purpose before
removing them.

## Write or correct

For creation, draft from the established requirements and sources. For revision,
apply corrections after evaluating; diagnosis does not replace editing. Reread
existing files immediately before changing them to work on their current version.

- Write directives in the imperative. Keep prohibitions when they express the
  boundary more precisely. Keep facts, hypotheses, decisions, and evidence in
  their respective roles rather than rewriting them as directives.
- Replace roundabout wording and vague references with explicit actions and
  referents when the request or sources establish them.
- Place each rule where it is first needed, and general rules in the shared
  section. Keep conditions and exceptions next to their rule.
- Merge equivalent directives without losing details. Group parallel
  instructions only when they share the action, scope, and conditions.
- Define terms before using them and keep their names consistent.
- Keep a justification if it helps apply a rule to unlisted cases; remove
  justifications that merely repeat the rule.
- Use headings, lists, tables, or code blocks according to what the agent
  needs to consult or copy. Preserve frontmatter and template syntax.

When deduplicating across files, check that the agent can access the rule's
remaining location when needed. Moving it out of a file loaded independently
can change behavior.

Do not invent directives or fill in conditions by intuition. Preserve ambiguous
passages that the text does not let you clarify and instructions in conflict;
ask the user for the necessary decision in the report. During creation, ask for
missing decisions that prevent faithful drafting instead of inventing them.
Do not add unsupported facts or treat hypotheses as confirmed decisions.

## Verify and deliver

For creation, compare the result with the request and sources. Check that it
covers the required directives and operational content without unsupported
additions. No original text or before/after inventory is required.

For revision, rebuild the inventory from the result and compare it with the
original. Each directive must remain represented, separately or merged, with the
same scope, conditions, exceptions, and strength. Preserve operational context,
decisions, evidence, state, and uncertainty. Restore any lost detail and remove
unsupported additions introduced during editing.

In both modes, check sequence, output formats, references, and the distinction
between facts, hypotheses, decisions, and instructions. Preserve required
templates, headings, fields, IDs, status values, verbatim passages, languages,
read/write limits, and report lengths. Writing quality does not authorize
rewriting artifacts that the producing workflow requires preserving.

Deliver the requested document in its specified file or in chat; return file
paths when writing files. For a standalone revision, accompany the result with
a brief report: problems found and changes applied, verification results, and
word counts before and after. Do not include the complete inventory. For
creation, deliver the document without a correction report or before/after
counts. When integrated into another workflow, follow that workflow's output
contract without appending a separate style report.

If ambiguities or contradictions remain, quote the passages and ask which
instruction should govern, using the producing workflow's question channel
and report format when integrated.
