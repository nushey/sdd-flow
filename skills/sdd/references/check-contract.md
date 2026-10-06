# `sdd check` contract

`sdd check` validates the mechanical contract of ONE Full SDD feature folder. It reads files and the local git repository only: no writes, no network, no models, no judgment on design quality. It never proves that an acceptance criterion is met — only that declarations are consistent.

## Usage

```
sdd check <feature-slug> [--phase resume|scope|plan|verify]
```

- Run from anywhere inside the project's git work tree. The checker resolves the repository root and validates only `<root>/.spec/<feature-slug>/`.
- `<feature-slug>` is kebab-case (`[a-z0-9]+(-[a-z0-9]+)*`), never a path.
- `--phase` defaults to `resume`.
- Requires Python 3.11+ and `git` on `PATH`.

## Output and exit codes

| Exit | Meaning | Output |
|---|---|---|
| 0 | Contract holds for the phase. | One line: `OK <phase>` or, for `resume`, `OK resume: <state>`. |
| 1 | Contract violated. | One line per finding: `CODE path:line: explanation`, sorted by path, line, code. `path` is relative to the repository root; `line` is `0` when the finding concerns a whole file. |
| 2 | Invalid usage, unsupported format, or unavailable environment. | One line: `ERROR <explanation>`. |

Output never includes timestamps, temporary paths, or file bodies. Identical inputs produce identical output.

## Phases

| Phase | Requires |
|---|---|
| `scope` | `intake.md` with a valid base commit; `scope.md` with a non-empty `## Objective` and well-formed, unique AC IDs. |
| `plan` | `scope` plus non-empty `design.md`, `tasks.index.md`, and task files: sections, row↔file correspondence, full AC coverage, no unknown AC, Context/Reference caps, valid statuses. A `done` task must have a matching commit. |
| `verify` | `plan` plus every main task `done (<hash>)` with consistent commits, and a coherent `## Fixes` table with no `pending` or `in-progress` fix. The last fix may be `done (<hash>)` awaiting re-verification. If `verify.md` exists it must be well-formed. |
| `resume` | Infers the state from the files present and checks the invariants of that state. |

`resume` states (printed after `OK resume:`):

| State | Files present |
|---|---|
| `intake` | `intake.md` only. |
| `scope` | `intake.md`, `scope.md`; no `design.md`, no `tasks.index.md`, no `tasks/`. |
| `plan` | Plan complete (validated as `plan`); no `verify.md`. Tasks may be `pending`. |
| `verify-fail` | Plan complete and `verify.md` with `FAIL`. |
| `verify-pass` | Plan complete and `verify.md` with `PASS`, no code change after its verified commit. |
| `verify-pass-stale` | As above, but files outside `.spec/<feature-slug>/` changed after the verified commit, or uncommitted changes (including untracked files and other specs) exist outside it. Re-verification is required. |
| `verify-reconcile` | `verify.md` (PASS or FAIL) was written but the last fix is still `done (<hash>)`, its commit is contained in the verified commit, and nothing outside `.spec/<feature-slug>/` changed since. The Verifier only updates that fix row. Without that evidence, PASS with an open fix is `VERIFY_INCONSISTENT`. |

Errors in `resume`: a missing or empty feature folder; `design.md` or task files without `tasks.index.md` (`PLAN_INCOMPLETE`: interrupted planning blocks execution); fix files or `tasks.index.md` without the artifacts that precede them; `verify.md` without a complete plan.

A git query whose failure would hide changes (`git diff`, `git status`) exits 2 with `ERROR git <command> failed …`; it never yields a success state.

A folder that contains `plan.md` but no `intake.md` is a Mini-SDD or standalone plan: exit 2, `ERROR unsupported format: plan.md (Full SDD only)`.

## Text rules

- Files are UTF-8. Lines end in LF or CRLF.
- Fenced blocks (lines opening with ```` ``` ```` or `~~~` until the matching close) are ignored: examples inside them are never data.
- A section is a line `## <Title>` and runs until the next line starting with `# ` or `## `. Titles are matched by the exact text listed below (a task file heading matches when it starts with the listed text).
- A list entry is a line starting with `- ` inside a section. Nested lines (indented) belong to the entry above.
- A list containing only `- none` is an explicit empty list.
- A table is a run of lines starting with `|`. Cells are split on unescaped `|`; `\|` is a literal pipe. Cells are trimmed. The second line must be a separator with one `---` cell (optionally `:`-aligned) per header cell. A missing or malformed separator, or a row with a different cell count than its header, is `BAD_TABLE`.

## Identifiers

| Kind | Pattern | Notes |
|---|---|---|
| Acceptance criterion | `AC-NNN` | `001`–`999`. Unique in `scope.md`. |
| Task | `NNN` | `001`–`999`. File `tasks/NNN-<slug>.md`, heading `# NNN — <Title>`. Not necessarily contiguous. |
| Fix | `fix-NNN` | `001`–`999`. File `fixes/fix-NNN-<slug>.md`, heading `# fix-NNN — <Title>`. Separate sequence. |
| Commit hash | `[0-9a-f]{7,64}` | Must resolve unambiguously to a local commit (`git rev-parse --verify --quiet <hash>^{commit}`), descend from the base commit, and be an ancestor of HEAD. Never fetched. |

A `Covers` value is a comma-separated list of AC IDs, at least one, no duplicates.

## Files

### `intake.md`
- `## Base commit`: first non-empty line is a commit hash that resolves locally and is an ancestor of HEAD.

### `scope.md`
- `## Objective`: non-empty.
- `## Acceptance criteria`: every list entry is `- [ ] AC-NNN: <text>` or `- [x] AC-NNN: <text>` with non-empty text. At least one entry.

### `design.md`
- Non-empty.

### `tasks.index.md`
- Main table: the first table before `## Fixes`, with header `ID | Title | Covers | Status`.
  - `ID`: task ID, unique. Each row has exactly one file `tasks/<ID>-*.md`; each task file has exactly one row.
  - `Covers`: equals the set in the task file's `## Covers`.
  - `Status`: `pending` or `done (<hash>)`.
- `## Fixes` (optional): table with header `Fix ID | Title | Covers | Triggered by failure in | Files (suggested) | Status`.
  - `Fix ID`: fix ID, unique, with exactly one file `fixes/<Fix ID>-*.md` (and vice versa).
  - `Status`: `pending`, `in-progress`, `done (<hash>)`, `passed`, or `failed`.
  - At most one open fix (`pending`, `in-progress`, `done`), and only as the last row.
  - At most three `failed` rows; no row after the third `failed`.
- Every AC of `scope.md` appears in the `Covers` of at least one main task. No `Covers` (tasks or fixes) names an unknown AC.

### Task and fix files
- Heading on the first non-empty line matches the file ID.
- Sections (by title prefix): `Covers`, `Context files`, `Reference files`, `Acceptance`, `Implementation log`.
- `Context files`: at most 5 entries. `Reference files`: at most 3 entries. `- none` counts as zero.
- `Acceptance`: at least one entry; every entry reads `- [ ] AC-NNN: <result>` (or `- [x]`) with non-empty text; the set of IDs equals the file's `Covers`. One ID may have several entries.
- `Implementation log`: the entry `- Commit: <hash> — <subject>`. The template value `<hash>` means not filled.
  - Main task `done (<hash>)`: log filled; both hashes resolve to the same commit.
  - Main task `pending`: a filled log is allowed (interrupted attempt; the developer reconciles it), but its hash must be valid.
  - Fix `done (<hash>)`: as a done task. Fix `passed` or `failed`: log filled with a valid hash. Fix `pending` or `in-progress`: log may be unfilled.

### `verify.md` (optional)
- `## Status`: first non-empty line is `PASS` or `FAIL`.
- `## Acceptance criteria`: entries `- [x] AC-NNN…` or `- [ ] AC-NNN…`; every AC of `scope.md` appears exactly once and no unknown AC appears.
- `## Local closure`: entries `- Base commit: <hash>` (same commit as `intake.md`) and `- Verified commit: <hash>` (valid).
- `PASS` additionally requires every main task `done`, every AC entry ticked, and no open fix (except the `verify-reconcile` evidence above).
- A well-formed `FAIL` is not a contract violation; it may coexist with the last fix open.

## Finding codes

| Code | Meaning |
|---|---|
| `MISSING_FILE` | A required file or folder is absent. |
| `EMPTY_FILE` | A required file is empty. |
| `MISSING_SECTION` | A required section or entry is absent or empty. |
| `BAD_ID` | An ID or `Covers` value is malformed or `000`. |
| `DUPLICATE_ID` | An AC, task, or fix ID appears twice (rows or files). |
| `HEADING_MISMATCH` | A task or fix heading does not match its file ID. |
| `BAD_TABLE` | A table header or row is malformed. |
| `ROW_WITHOUT_FILE` | An index row has no matching file. |
| `ORPHAN_FILE` | A task or fix file has no index row. |
| `UNKNOWN_AC` | A reference to an AC ID that `scope.md` does not define. |
| `UNCOVERED_AC` | An AC with no covering main task. |
| `COVERS_MISMATCH` | Index `Covers` differs from the file's `## Covers`. |
| `CAP_EXCEEDED` | More than 5 Context or 3 Reference entries. |
| `BAD_STATUS` | Unknown status, or a status not allowed in the phase. |
| `BAD_COMMIT` | A hash does not resolve to a unique local commit of the feature's history. |
| `HASH_MISMATCH` | Index and Implementation log name different commits. |
| `LOG_MISSING` | A status requires a filled Implementation log that is absent. |
| `FIX_SEQUENCE` | More than one open fix, an open fix that is not last, or a row after the third `failed`. |
| `PLAN_INCOMPLETE` | Planning artifacts without `tasks.index.md`. |
| `BAD_STATE` | Files present that no valid state allows (e.g. index without design, verify without plan). |
| `VERIFY_INCONSISTENT` | `verify.md` disagrees with the current artifacts. |

## Out of scope

The checker does not repair, migrate, commit, or rewrite files. Older specs (AC without IDs, index without `Covers`) fail with their findings; the user decides whether to update them by hand. Mini-SDD and standalone `plan.md` files are not validated in this version.
