# Installing sdd-flow in other IDEs

sdd-flow works in any agent harness that reads [Agent Skills](https://agentskills.io).
It is **not** an MCP server — there is no process to spawn, no `command`/`args`/`env`,
and nothing to register in an `mcpServers` block. sdd-flow ships two things:

- **Skills** (`skills/<name>/SKILL.md`) — the orchestrator (`sdd`, `mini-sdd`) plus
  standards (`pr-creation`, `writing-skill`, `mini-sdd-planner`).
- **Subagent prompts** (`agents/<name>.md`) — the five roles:
  `sdd-init`, `sdd-tech-lead`, `sdd-developer`, `sdd-verifier`, `mini-sdd-developer`.

The installer below drops these into the right directory for each client.

> Already on **Claude Code** or **Gemini CLI**? You don't need this page — use the
> native commands in the main [README](./README.md#install).

---

## Quick install

Run **one command** from the root of your project. Replace `<client>` with
`codex`, `opencode`, `kilo`, `cursor`, `windsurf`, or `antigravity`.

**macOS / Linux / WSL / git-bash**

```bash
curl -fsSL https://raw.githubusercontent.com/nushey/sdd-flow/main/scripts/install.sh \
  | bash -s -- --client <client>
```

**Windows (PowerShell)** — save and run:

```powershell
irm https://raw.githubusercontent.com/nushey/sdd-flow/main/scripts/install.ps1 -OutFile install.ps1
.\install.ps1 -Client <client>
```

> Prefer to inspect first? Clone and run locally — the script auto-detects a local
> checkout and skips the network:
> ```bash
> git clone https://github.com/nushey/sdd-flow
> sdd-flow/scripts/install.sh --client <client>   # or install.ps1 -Client <client>
> ```

| Client | One-liner install | Native alternative | Skills land at | Subagents land at |
|--------|-------------------|--------------------|----------------|-------------------|
| [Codex](#codex) | installer | `codex plugin marketplace add` + `codex plugin add` | `.agents/skills/` | `.codex/agents/*.toml` |
| [Opencode](#opencode) | installer | — | `.agents/skills/` | `.opencode/agents/*.md` |
| [Kilo Code](#kilo-code) | installer | — | `.agents/skills/` | `.kilo/agent/*.md` |
| [Cursor](#cursor) | installer | Customize → Rules → Remote Rule (GitHub) | `.agents/skills/` | `.cursor/agents/*.md` |
| [Windsurf / Devin Desktop](#windsurf--devin-desktop) | installer | — | `.agents/skills/` | `.devin/rules/sdd.md` (rules-driven) |
| [Antigravity](#antigravity) | installer | — | `.agents/skills/` | n/a (orchestrator-only) |

### Before you start (all clients)

1. Your project **must have an `AGENTS.md`** at the root. SDD treats it as law and
   never creates it for you. (Optional companion `CLAUDE.md` is also read if present.)
   **This is still required per-project even if you install globally** — a global
   install only skips re-copying skills/agents into every project, it does not
   supply `AGENTS.md`.
2. Install the [GitHub CLI](https://cli.github.com/) and run `gh auth login` — the
   Verifier opens pull requests with it.

---

## Project vs. global install

By default the installer targets **one project** — the directory you run it from
(or `--target <dir>` / `-Target <dir>` to point elsewhere). Add `--global`
(bash) / `-Global` (PowerShell) instead to install once into the client's
**user-level directory**, so every project on the machine picks it up without
re-running the installer.

```bash
# One project (default: current directory)
scripts/install.sh --client kilo --target /path/to/project

# Every project on this machine
scripts/install.sh --client kilo --global
```

```powershell
# One project
scripts\install.ps1 -Client kilo -Target "C:\path\to\project"

# Every project on this machine
scripts\install.ps1 -Client kilo -Global
```

`--global` and `--target`/`-Target` are mutually exclusive — `--global` ignores
`--target` if both are passed.

**Global paths per client** (only where the client actually has a confirmed
user-level directory — installer skips anything unconfirmed and tells you so
on the spot, it never guesses a path):

| Client | Skills (global) | Agents (global) |
|--------|------------------|------------------|
| Codex | `~/.agents/skills/` | `~/.codex/agents/*.toml` |
| Opencode | `~/.config/opencode/skills/` | `~/.config/opencode/agents/*.md` |
| Kilo Code | `~/.kilo/skills/` | `~/.kilo/agent/*.md` |
| Cursor | *(none confirmed — skipped)* | `~/.cursor/agents/*.md` |
| Windsurf / Devin Desktop | `~/.codeium/windsurf/skills/` | *(none confirmed — skipped, install per-project instead)* |
| Antigravity | `~/.gemini/config/skills/` | n/a (no subagent support on this client) |

On Windows, `~` above is `%USERPROFILE%` (PowerShell's `$HOME`).

> **PowerShell note:** `$HOME` in `install.ps1` is PowerShell's built-in
> automatic variable, not `$env:HOME` — setting `$env:HOME` before running the
> script has **no effect**. There is no way to sandbox/redirect a `-Global`
> install on Windows; running it writes to your real user profile immediately.
> If you want to test without touching your real machine, use `-Target` to a
> throwaway directory instead of `-Global`.

---

## Codex

Codex (CLI, IDE extension, and app) reads Agent Skills from `.agents/skills/` and
custom agents from `.codex/agents/*.toml`.

```bash
curl -fsSL https://raw.githubusercontent.com/nushey/sdd-flow/main/scripts/install.sh \
  | bash -s -- --client codex
```

**What lands:** 5 skills in `.agents/skills/` and 5 custom agents in `.codex/agents/`
(as TOML with `name`, `description`, `developer_instructions`).

**Global (every project on this machine):** `scripts/install.sh --client codex --global`
(or `-Client codex -Global`) → `~/.agents/skills/` + `~/.codex/agents/`.

**Native alternative (if sdd-flow is published as a Codex marketplace/plugin):**

```bash
codex plugin marketplace add nushey/sdd-flow
codex plugin add sdd-flow
```

**Invoke:** type `/skills` or `$sdd` to load the orchestrator, then `/sdd <feature>`.
Subagents (`sdd-init`, `sdd-tech-lead`, …) are spawned by Codex when the orchestrator
delegates a phase.

---

## Opencode

Opencode reads Agent Skills from `.agents/skills/` (also `.opencode/skills/`,
`.claude/skills/`) and subagents from `.opencode/agents/*.md`.

```bash
curl -fsSL https://raw.githubusercontent.com/nushey/sdd-flow/main/scripts/install.sh \
  | bash -s -- --client opencode
```

**What lands:** 5 skills in `.agents/skills/` and 5 subagents in `.opencode/agents/`
(each with `mode: subagent` injected into its frontmatter).

**Global (every project on this machine):** `scripts/install.sh --client opencode --global`
(or `-Client opencode -Global`) → `~/.config/opencode/skills/` + `~/.config/opencode/agents/`.

**Invoke:** the agent auto-loads the `sdd` skill; say `/sdd <feature>` for full SDD,
or `@sdd-developer …` to address a subagent directly. Use `/mini-sdd <change>` for
small fixes.

---

## Kilo Code

Kilo Code reads Agent Skills from `.agents/skills/` (also `.claude/skills/`) and
agents from `.kilo/agent/*.md`.

```bash
curl -fsSL https://raw.githubusercontent.com/nushey/sdd-flow/main/scripts/install.sh \
  | bash -s -- --client kilo
```

**What lands:** 5 skills in `.agents/skills/` and 5 agents in `.kilo/agent/`.

**Global (every project on this machine):** `scripts/install.sh --client kilo --global`
(or `-Client kilo -Global`) → `~/.kilo/skills/` + `~/.kilo/agent/`.

**Invoke:** use the `sdd` skill; say `/sdd <feature>`. Kilo reads `AGENTS.md` and
`.kilo/` automatically.

---

## Cursor

Cursor reads Agent Skills from `.agents/skills/` (also `.cursor/skills/`,
`.claude/skills/`, `.codex/skills/`) and custom subagents from `.cursor/agents/*.md`.

```bash
curl -fsSL https://raw.githubusercontent.com/nushey/sdd-flow/main/scripts/install.sh \
  | bash -s -- --client cursor
```

**What lands:** 5 skills in `.agents/skills/` and 5 subagents in `.cursor/agents/`.

**Global (every project on this machine):** `scripts/install.sh --client cursor --global`
(or `-Client cursor -Global`) → `~/.cursor/agents/` only. Cursor has no confirmed
global skills directory, so the `sdd`/`mini-sdd` **skills are not installed globally**
— the installer prints a skip note. `/sdd` won't be discoverable until you also run
the per-project install (`--target <dir>`, no `--global`) in each project, which
puts skills in `.agents/skills/` for that project.

**Native alternative:** open **Customize → Rules → Add Rule → Remote Rule (GitHub)**
and point it at `https://github.com/nushey/sdd-flow`.

**Invoke:** type `/sdd` in Agent chat, or ask Cursor to "spec this feature" and it
will load the `sdd` skill. You can also run `/create-subagent` to inspect the
installed subagents.

---

## Windsurf / Devin Desktop

Windsurf has been rebranded to **Devin Desktop** (the local agent is "Devin Local").
It does not load Agent Skills the same way the others do, so sdd-flow installs as a
**rules-driven orchestrator**: the flow lives in a rules file, and the agent reads
the vendored skills as needed.

```bash
curl -fsSL https://raw.githubusercontent.com/nushey/sdd-flow/main/scripts/install.sh \
  | bash -s -- --client windsurf
```

**What lands:**

- `.devin/rules/sdd.md` (preferred) **and** `.windsurfrules` (legacy fallback for
  pre-rebrand installs).
- The 5 skills in `.agents/skills/` (best-effort; the rules file is the source of truth).

**Global (every project on this machine):** `scripts/install.sh --client windsurf --global`
(or `-Client windsurf -Global`) → `~/.codeium/windsurf/skills/` only. The rules file
(`.devin/rules/sdd.md` / `.windsurfrules`) has no confirmed global location, so it is
**not** installed globally — the installer prints a skip note. Install per-project
(`--target <dir>`, no `--global`) to get the rules file, which is what actually
drives the orchestrator on this client.

**Invoke:** say `/sdd <feature>` or "use SDD to plan `<feature>`".

**Limitation:** Devin Local does support subagents, but their file format is not
part of sdd-flow's verified adapters yet. Per-phase context isolation is therefore
weaker here than on Claude Code / Codex / Opencode / Cursor / Kilo. **Prefer
`/mini-sdd`** (one delegated subagent) on this client.

---

## Antigravity

Google Antigravity reads Agent Skills from `.agents/skills/` (project) or
`~/.gemini/config/skills/` (global). It has no native multi-agent orchestration, so
sdd-flow runs as an **orchestrator-only** flow on this client.

```bash
curl -fsSL https://raw.githubusercontent.com/nushey/sdd-flow/main/scripts/install.sh \
  | bash -s -- --client antigravity
```

**What lands:** the 5 skills in `.agents/skills/` (no subagent files).

**Global (every project on this machine):** `scripts/install.sh --client antigravity --global`
(or `-Client antigravity -Global`) → `~/.gemini/config/skills/`. No subagent files
either way — Antigravity has no native multi-agent orchestration to install into.

**Invoke:** ask the agent to use the `sdd` skill, or say "use SDD for `<feature>`".

**Limitation:** without discrete subagents, the init/design/implement/verify phases
run inside one agent context rather than isolated subagent threads. Use **Mini-SDD**
for best results here; full SDD works but trades away the context isolation that is
SDD's main value.

---

## How it works

sdd-flow conforms to the open [Agent Skills](https://agentskills.io) standard: each
skill is a folder with a `SKILL.md` (YAML frontmatter `name` + `description`, then
instructions). Clients discover skills via **progressive disclosure** — only the
name/description load at startup; the full `SKILL.md` loads when the agent activates
the skill.

Five of the six clients above (Codex, Opencode, Kilo, Cursor, Antigravity) read
`.agents/skills/` natively, so the skills need no transformation. Subagent prompts
adapt to each client's format:

- **Codex** — `.codex/agents/*.toml` (pre-generated; see
  [`integrations/codex/`](./integrations/codex)).
- **Opencode** — `.opencode/agents/*.md` with `mode: subagent`.
- **Kilo / Cursor** — `.md` copied as-is (frontmatter is compatible).
- **Windsurf/Devin** — a rules file drives the orchestrator.

The canonical agent prompts live once in [`agents/`](./agents). To regenerate the
Codex TOML adapters after editing them:

```bash
scripts/generate-adapters.sh
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `error: --client is required` | Pass `--client <name>` (one of the six). |
| Skill not discovered after install | Restart the client so it re-scans skill directories. |
| `Status: FAIL — AGENTS.md missing` | Add an `AGENTS.md` at your project root; SDD never creates it. |
| Verifier can't open a PR | Install `gh` and run `gh auth login`. |
| `gh pr create` fails on permissions | Ensure the branch is pushed and you have repo write access. |
| Want the newest skills/agents | Re-run the same install command; it refreshes in place. |
| Wrong project targeted | Add `--target /path/to/project` (bash) or `-Target` (PowerShell). |
| `skip: global agents/skills — no confirmed ...` printed after `--global` | Expected for Cursor (skills), Windsurf (agents/rules), and previously Kilo before its global agent path was confirmed. Not an error — install the missing piece per-project instead (`--target <dir>`, no `--global`). See the [per-client global paths table](#project-vs-global-install). |
| `--global` on Windows wrote to the wrong place / can't sandbox it | Expected — PowerShell's `$HOME` automatic variable ignores `$env:HOME` overrides. `-Global` on Windows always targets your real user profile; there's no redirect. Use `-Target <throwaway-dir>` if you just want to test the installer. |
| Skills/agents installed globally but `/sdd` still not found | Restart the client — global directories are scanned at startup same as project ones. If the client has no confirmed global skills path (Cursor, and rules for Windsurf), a project-level install is required for that piece regardless of `--global`. |

---

## Uninstall

**Project install** — remove the directories the installer created in that project:

```bash
rm -rf .agents/skills/sdd .agents/skills/mini-sdd .agents/skills/mini-sdd-planner \
       .agents/skills/pr-creation .agents/skills/writing-skill .codex/agents   # Codex
# Opencode: also .opencode/agents   |  Kilo: .kilo/agent   |  Cursor: .cursor/agents
# Windsurf: .devin/rules/sdd.md .windsurfrules
```

**Global install** — remove the user-level directories instead (paths per client,
`~` = `%USERPROFILE%` on Windows):

```bash
rm -rf ~/.agents/skills/sdd ~/.agents/skills/mini-sdd ~/.agents/skills/mini-sdd-planner \
       ~/.agents/skills/pr-creation ~/.agents/skills/writing-skill ~/.codex/agents   # Codex
# Opencode: ~/.config/opencode/skills, ~/.config/opencode/agents
# Kilo:     ~/.kilo/skills, ~/.kilo/agent
# Cursor:   ~/.cursor/agents  (no global skills to remove)
# Windsurf: ~/.codeium/windsurf/skills  (no global rules file to remove)
# Antigravity: ~/.gemini/config/skills
```

Or simply re-run the installer for a different client after cleaning up.
