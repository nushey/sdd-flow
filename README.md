<h1 align="center">sdd-flow</h1>

<p align="center">
  <strong>Spec-Driven Development and standalone engineering workflows for AI coding agents.</strong>
</p>

<p align="center">
  <a href="https://agentskills.io">agentskills.io</a>-compliant skills pack · no server to run
</p>

---

sdd-flow gives your coding agent a structured way to work. Before writing code, it saves the spec or plan under `.spec/`, then hands each phase to a subagent that starts with a clean context. Every agent follows your project's `AGENTS.md` (and `CLAUDE.md` if present). Nothing is pushed: every flow ends with local commits or local changes.

## Install

**macOS / Linux / WSL / git-bash**

```bash
curl -fsSL https://raw.githubusercontent.com/nushey/sdd-flow/main/scripts/install.sh | bash
```

**Windows (PowerShell)**

```powershell
irm https://raw.githubusercontent.com/nushey/sdd-flow/main/scripts/install.ps1 -OutFile install.ps1
.\install.ps1
```

The installer asks whether to install for the current project or for your user, and which clients to set up: Claude Code, Gemini CLI, Codex, Opencode, Kilo Code, Cursor, Windsurf/Devin, Antigravity, GitHub Copilot, or any other Agent Skills client.

You can also use the native plugins:

- **Claude Code:** `/plugin marketplace add nushey/sdd-flow`, then `/plugin install sdd-flow@sdd-flow`
- **Gemini CLI:** `gemini extensions install https://github.com/nushey/sdd-flow`
- **Codex:** `codex plugin marketplace add nushey/sdd-flow`, then `codex plugin add sdd-flow`

[INSTALL.md](./INSTALL.md) covers flags, install paths, troubleshooting, and uninstalling.

## Skills

| Command | What it does |
|---------|--------------|
| `/sdd <feature>` | Full flow for large features: scope, design, tasks, implementation, and verification. |
| `/mini-sdd <change>` | Short flow for small features, fixes, and refactors: one plan, one developer subagent. |
| `/sharp-me <idea>` | Questions and refines an idea until it is well defined. Saves `brief.md`. |
| `/sdd-plan <request>` | Writes an implementation plan without touching code. Saves `plan.md`. |
| `/sdd-debug <issue>` | Finds and proves the root cause of a failure. Saves `diagnosis.md`. |
| `/sdd-implement <plan>` | Implements a plan, in full or in part, and logs progress in `history.md`. Does not commit. |
| `/sdd-code-review <request>` | Reviews code quality, tests, conventions, bugs, and security in a separate subagent. Saves `code-review.md`. |
| `/sdd-acceptance-review <request>` | Checks the implementation against the ticket, the plan, or criteria you give it, in a separate subagent. Saves `acceptance-review.md`. |
| `/pr-creation` | Writes a pull request description when you ask for one. |
| `/writing-agents <request or text>` | Writes or improves instructions for agents without changing their behavior. |
| `/writing-humans <request or text>` | Writes or improves text for people without changing its meaning. |

The standalone skills chain together if you want: `sharp-me` or `sdd-debug` → `sdd-plan` → `sdd-implement` → `sdd-code-review` and `sdd-acceptance-review`. All of them save their output under `.spec/<name>/`. Neither review fixes code. The writing skills also apply by themselves during writing tasks, without you calling them.

## How `/sdd` works

1. **Triage**: you agree on scope with the agent (`intake.md`).
2. **Init**: acceptance criteria with stable IDs (`scope.md`).
3. **Design and tasks**: technical design and one file per task (`design.md`, `tasks/`).
4. **Implement**: one subagent per task, one commit per task.
5. **Verify**: tests run and the result is checked against `scope.md`, with up to three fix rounds. On success, the spec is committed locally.

`/mini-sdd` skips most of this: the agent writes a plan, waits for your approval, and a single subagent implements and verifies it. Before starting, it saves the base commit in `history.md`. Mini-SDD doesn't run an acceptance review by itself; to get one, pass the plan and the commit range:

```text
/sdd-acceptance-review Check acceptance against .spec/<slug>/plan.md (all AC-NNN IDs) for <base>..<end>.
```

`<base>` is the hash saved in `history.md`, and `<end>` is the last commit you want reviewed.

## Requirements for `/sdd` and `/mini-sdd`

- An `AGENTS.md` at the project root with your rules and conventions. sdd-flow never creates it.
- A git repository with at least one commit.
- Python 3.11+ for the `/sdd` checker.

## License

MIT
