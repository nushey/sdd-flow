---
name: pr-creation
description: >
  Standard for writing PR descriptions in the SDD Verifier phase.
  Defines structure and tone: value-oriented, concise, technical detail
  only when it matters to the reviewer.
---

# PR Creation Standard

## Principles

- Write for the reviewer, not for the machine. The PR is a human document.
- Lead with **what changed for the user or system**, not how the code was rearranged.
- Technical details (refactors, file moves, internal patterns) belong only if they affect the reviewer's ability to evaluate correctness or risk.
- No padding. If a section has nothing useful to say, omit it.

## Body format

```markdown
## Description
<One or two sentences. What does this feature/fix do and why does it exist? Write from the perspective of what the system can now do, not what files were added.>

## Key changes / New features
- <Value-oriented bullet. What the user or system gains. Example: "Agents can now inspect a C# file's structural contract via the `inspect_file` MCP tool.">
- <Another outcome. Example: "DTO types are auto-detected and their properties are omitted from the output, keeping AI context compact.">
- <Technical change only if it's load-bearing for the review. Example: "Roslyn syntax tree only — no SemanticModel, intentionally, to stay stateless and fast.">
```

## Rules

- **Description**: one paragraph maximum. No bullet points. No list of files.
- **Key changes**: 2–5 bullets. Each bullet describes an outcome or a capability, not an implementation step.
- Include a technical bullet only when the reviewer needs that context to assess correctness, risk, or future implications. "Added `MemberExtractor.cs`" is never a bullet. "Uses syntax-only parsing — no compilation step, intentionally stateless" is, because it answers a question a reviewer would have.
- Do not mention task IDs, commit hashes, or spec file paths in the PR body.
- Do not include a test plan checklist — tests ran in CI and the result is in `verify.md`.
- Write in the same language the project uses (default: English).

## Example

```markdown
## Description
Adds the `inspect_file` MCP tool, which returns a deterministic JSON contract for a single C# file — types, members, attributes, and constructor dependencies — without loading full source into AI context.

## Key changes / New features
- AI agents can call `inspect_file` with a `.cs` path and receive a structured JSON describing the file's public contract.
- DTO-shaped types are auto-classified and their properties omitted, reducing output size for data-carrier types.
- Records, enums, interfaces, structs, and delegates are all represented with their correct `kind` field.
- Error cases (missing file, wrong extension, unreadable, invalid C#) return a structured JSON error instead of crashing the server.
- Roslyn syntax tree only — no `CSharpCompilation` or `SemanticModel` constructed, keeping the server stateless and fast.
```
