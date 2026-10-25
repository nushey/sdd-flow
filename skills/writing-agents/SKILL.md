---
name: writing-agents
description: >
  Evaluate and correct agent instructions in AGENTS.md, CLAUDE.md, SKILL.md,
  prompts, and other Markdown files. Use when reviewing, clarifying,
  simplifying, condensing, or deduplicating these texts while preserving
  their behavior. Evaluate first, then apply corrections. For texts intended
  for people, use writing-humans.
---

# Writing agents

Make instructions concise, clear, and executable. Preserve what the agent
must do, when it must do it, and under which constraints. Reduce wording only
when it preserves that precision.

## Evaluate

Read the current version of the complete text and the context needed to
understand its references. Preserve each passage's language, including
mixed-language texts; do not translate.

Inventory each directive with its location: action, condition, scope,
obligation or permission, prohibition, exception, default value, sequence,
and output format. Record the reason when the text provides one. If the
request spans multiple files, the inventory must cover all of them.

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

## Correct

Apply corrections after evaluating; diagnosis does not replace editing.
Reread files immediately before changing them to work on their current version.

- Write direct instructions in the imperative. Keep prohibitions when they
  express the boundary more precisely.
- Replace roundabout wording and vague references with explicit actions and
  referents when the text itself establishes them.
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
ask the user for the necessary decision in the report.

## Verify and deliver

Rebuild the inventory from the result and compare it with the original. Each
directive must remain represented, separately or merged, with the same scope,
conditions, exceptions, and strength. Also check the sequence, output formats,
and references. Restore any lost detail and remove directives introduced
during editing.

If you received files, apply corrections to them and return their paths.
If you received text in the chat, deliver the corrected version.

Accompany the result with a brief report: problems found and changes applied,
verification results, and word counts before and after. If ambiguities or
contradictions remain, quote the passages and ask which instruction should
govern. Do not include the complete inventory in the report.
