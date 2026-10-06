# Installing sdd-flow in other IDEs

sdd-flow works in any agent harness that reads [Agent Skills](https://agentskills.io).
It is **not** an MCP server — there is no process to spawn, no `command`/`args`/`env`,
and nothing to register in an `mcpServers` block. sdd-flow ships two things:

- **Skills** (`skills/<name>/SKILL.md`) — the orchestrator (`sdd`, `mini-sdd`) plus
  standards (`pr-creation`, `writing-skill`, `sdd-plan`).
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

**Windows (Windows PowerShell 5.1 or PowerShell 7+)** — save and run:

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
| [Windsurf / Devin Desktop](#windsurf--devin-desktop) | installer (partial) | — | `.agents/skills/` | none — `.devin/rules/sdd.md` only |
| [Antigravity](#antigravity) | installer (partial) | — | `.agents/skills/` | none |

**Partial installs:** `/sdd` and `/mini-sdd` require a harness that can delegate to
isolated subagents with the sdd-flow roles registered. Windsurf/Devin Desktop and
Antigravity receive skills (and rules) but no role subagents, so both flows stop
before writing any `.spec/` artifact and tell you what is missing. They do not run
the phases inline.

### Before you start (all clients)

1. Your project **must have an `AGENTS.md`** at the root. SDD treats it as law and
   never creates it for you. (Optional companion `CLAUDE.md` is also read if present.)
   **This is still required per-project even if you install globally** — a global
   install only skips re-copying skills/agents into every project, it does not
   supply `AGENTS.md`.
2. The project must be a **git repository** — every flow commits on a feature branch
   and stops at the start otherwise.
3. Install the [GitHub CLI](https://cli.github.com/) and run `gh auth login` — the
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
| Cursor | `~/.cursor/skills/` | `~/.cursor/agents/*.md` |
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
(or `-Client cursor -Global`) → `~/.cursor/skills/` + `~/.cursor/agents/`. Cursor reads
`~/.cursor/skills/` natively; the installer does not enable any optional sync.

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
- The 5 skills in `.agents/skills/`.
- **No role subagents.** Devin Local's subagent format is not part of sdd-flow's
  verified adapters, so the installer ships no `sdd-init` / `sdd-tech-lead` /
  `sdd-developer` / `sdd-verifier` / `mini-sdd-developer` files for this client.

**Global (every project on this machine):** `scripts/install.sh --client windsurf --global`
(or `-Client windsurf -Global`) → `~/.codeium/windsurf/skills/` only. The rules file
(`.devin/rules/sdd.md` / `.windsurfrules`) has no confirmed global location, so it is
**not** installed globally — the installer prints a skip note. Install per-project
(`--target <dir>`, no `--global`) to get the rules file.

**Invoke:** say `/sdd <feature>` or "use SDD to plan `<feature>`".

**Limitation (partial install):** both `/sdd` and `/mini-sdd` delegate to role
subagents that this install does not provide. Unless those roles are available to
the agent by other means, the flows stop before writing artifacts and report the
missing requirement — they never fall back to running the phases inline. For the
full pipeline use Claude Code, Gemini CLI, Codex, Opencode, Cursor, or Kilo Code.

---

## Antigravity

Google Antigravity reads Agent Skills from `.agents/skills/` (project) or
`~/.gemini/config/skills/` (global). sdd-flow ships no subagent adapter for it, so this
is a **partial install**: skills only.

```bash
curl -fsSL https://raw.githubusercontent.com/nushey/sdd-flow/main/scripts/install.sh \
  | bash -s -- --client antigravity
```

**What lands:** the 5 skills in `.agents/skills/` (no subagent files).

**Global (every project on this machine):** `scripts/install.sh --client antigravity --global`
(or `-Client antigravity -Global`) → `~/.gemini/config/skills/`. No subagent files
either way.

**Invoke:** ask the agent to use the `sdd` skill, or say "use SDD for `<feature>`".

**Limitation (partial install):** `/sdd` and `/mini-sdd` require isolated role
subagents. Without them the flows stop before writing artifacts and report the
missing requirement; they do not run the phases inline in one context.

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
- **Windsurf/Devin** — a rules file only; no role subagents (partial install).

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
| Want the newest skills/agents | Re-run the same install command. Paths sdd-flow installed (listed in the `.sdd-flow-manifest` next to them) are replaced; identical content is kept. Installs from 0.6.1 or earlier keep the replaced `mini-sdd-planner` skill: delete that folder from the skill directory. |
| `error: these paths exist, differ from sdd-flow and were not installed by it` | A file or folder with a pack name already exists and has no installation record (for example your own `writing-skill`, or an install made before the manifest existed). Nothing was copied. Move it away, or re-run with `--force` / `-Force` to replace exactly the listed paths. |
| `error: the cache at ... was cloned from ..., not ...` | The clone cache belongs to another `--source`. Remove it or set `SDD_FLOW_CACHE` to another directory. |
| `error: git fetch/checkout/clone failed; nothing was installed` | Fix the network or the local changes in the cache; the installer never resets the cache and copies nothing after a git error. |
| Wrong project targeted | Add `--target /path/to/project` (bash) or `-Target` (PowerShell). |
| `skip: global rules — no confirmed ...` printed after `--global` | Expected for Windsurf. Not an error — install the rules per-project instead (`--target <dir>`, no `--global`). See the [per-client global paths table](#project-vs-global-install). |
| `--global` on Windows wrote to the wrong place / can't sandbox it | Expected — PowerShell's `$HOME` automatic variable ignores `$env:HOME` overrides. `-Global` on Windows always targets your real user profile; there's no redirect. Use `-Target <throwaway-dir>` if you just want to test the installer. |
| Skills/agents installed globally but `/sdd` still not found | Restart the client — global directories are scanned at startup same as project ones. Windsurf rules have no confirmed global path, so they need a project-level install regardless of `--global`. |

---

## Uninstall

Remove only the pack's own entries — never the shared directories, which may hold
skills and agents from other sources. Each directory the installer wrote to also
holds a `.sdd-flow-manifest` listing exactly what it installed there.

**Project install** (run from the project root):

```bash
rm -rf .agents/skills/{sdd,mini-sdd,sdd-plan,pr-creation,writing-skill} .agents/skills/.sdd-flow-manifest
# Codex:    rm -f .codex/agents/{sdd-init,sdd-tech-lead,sdd-developer,sdd-verifier,mini-sdd-developer}.toml .codex/agents/.sdd-flow-manifest
# Opencode: rm -f .opencode/agents/{sdd-init,sdd-tech-lead,sdd-developer,sdd-verifier,mini-sdd-developer}.md .opencode/agents/.sdd-flow-manifest
# Kilo:     rm -f .kilo/agent/{sdd-init,sdd-tech-lead,sdd-developer,sdd-verifier,mini-sdd-developer}.md .kilo/agent/.sdd-flow-manifest
# Cursor:   rm -f .cursor/agents/{sdd-init,sdd-tech-lead,sdd-developer,sdd-verifier,mini-sdd-developer}.md .cursor/agents/.sdd-flow-manifest
# Windsurf: rm -f .devin/rules/sdd.md .devin/rules/.sdd-flow-manifest .windsurfrules .sdd-flow-manifest
```

**Global install** — the same names under the user-level directories from the
[global paths table](#project-vs-global-install) (`~` = `%USERPROFILE%` on Windows):

```bash
# Skills, per client: ~/.agents/skills (Codex), ~/.config/opencode/skills (Opencode),
# ~/.kilo/skills (Kilo), ~/.cursor/skills (Cursor), ~/.codeium/windsurf/skills (Windsurf),
# ~/.gemini/config/skills (Antigravity). Example for Cursor:
rm -rf ~/.cursor/skills/{sdd,mini-sdd,sdd-plan,pr-creation,writing-skill} ~/.cursor/skills/.sdd-flow-manifest
rm -f  ~/.cursor/agents/{sdd-init,sdd-tech-lead,sdd-developer,sdd-verifier,mini-sdd-developer}.md ~/.cursor/agents/.sdd-flow-manifest
# Agents, per client: ~/.codex/agents/*.toml (Codex), ~/.config/opencode/agents (Opencode), ~/.kilo/agent (Kilo).
```

On Windows, use `Remove-Item` with the same individual paths.
