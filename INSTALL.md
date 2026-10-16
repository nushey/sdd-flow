# Installing sdd-flow

sdd-flow works in any agent harness that reads [Agent Skills](https://agentskills.io).
It is **not** an MCP server — there is no process to spawn, no `command`/`args`/`env`,
and nothing to register in an `mcpServers` block. sdd-flow ships two things:

- **Skills** (`skills/<name>/SKILL.md`) — the orchestrator (`sdd`, `mini-sdd`) plus
  standards and standalone tools (`sharp-me`, `pr-creation`, `sdd-plan`, `sdd-implement`, `sdd-review`).
- **Subagent prompts** (`agents/<name>.md`) — the five roles:
  `sdd-init`, `sdd-tech-lead`, `sdd-developer`, `sdd-verifier`, `mini-sdd-developer`.

The installer below supports **interactive wizard mode** and **non-interactive CLI flags**
for both **local (per-project)** and **global (user-level)** installations across all
major coding agents.

---

## Interactive Wizard (Recommended)

Run the installer with **no flags** to launch the interactive wizard. It first asks for
**global** (machine-wide) or **local** (current project) scope, then lists every supported
client once, all unchecked: move with ↑↓, toggle with Space, confirm with Enter (at least one
client is required).

The focused client has a cyan `>` pointer, and selected clients have a green `[x]`.
Highlighted keyboard hints stay visible below the list. In smaller terminals, the list
scrolls with the arrow keys while keeping the focused client and its group visible;
long names, paths and statuses continue onto additional lines. Navigation updates only
the affected rows to avoid flashing the whole menu.

- Clients that share a skills directory for the chosen scope (for example `.agents/skills`
  locally) are grouped under a *shared, installed together* heading: the skills are written
  once and used by all of them. Each client's subagents are installed only if you check it.
- `[detected]` marks clients found on this machine; it is informational only.
- Clients that already have the sdd-flow native plugin (Claude Code, Codex) are shown in red
  with `[plugin installed]`; checking them installs the script copy alongside the plugin.

**macOS / Linux / WSL / git-bash**

```bash
curl -fsSL https://raw.githubusercontent.com/nushey/sdd-flow/main/scripts/install.sh | bash
```

**Windows (Windows PowerShell 5.1 or PowerShell 7+)**

```powershell
irm https://raw.githubusercontent.com/nushey/sdd-flow/main/scripts/install.ps1 -OutFile install.ps1
.\install.ps1
```

> Prefer to inspect first? Clone and run locally — the script auto-detects a local
> checkout and skips the network:
> ```bash
> git clone https://github.com/nushey/sdd-flow
> sdd-flow/scripts/install.sh   # or .\sdd-flow\scripts\install.ps1
> ```

---

## Non-Interactive CLI Install

Pass `--client` (`-c`) and either `--local` (`-l`) or `--global` (`-g`) to bypass the
wizard (or use in CI/scripts). Multiple clients can be comma-separated, or use `all`:

**macOS / Linux / WSL / git-bash**

```bash
# Local (current directory)
curl -fsSL https://raw.githubusercontent.com/nushey/sdd-flow/main/scripts/install.sh \
  | bash -s -- --client <client> --local

# Global (every project on this machine)
curl -fsSL https://raw.githubusercontent.com/nushey/sdd-flow/main/scripts/install.sh \
  | bash -s -- --client <client> --global

# Multiple clients globally
curl -fsSL https://raw.githubusercontent.com/nushey/sdd-flow/main/scripts/install.sh \
  | bash -s -- --client cursor,antigravity,codex --global
```

**Windows (PowerShell)**

```powershell
# Local (current directory)
.\install.ps1 -Client <client> -Local

# Global (every project on this machine)
.\install.ps1 -Client <client> -Global

# Multiple clients globally
.\install.ps1 -Client cursor,antigravity,codex -Global
```

---

## Supported Clients & Paths

All **9 full clients** receive both the **7 skills** and the **5 isolated role subagents**
(adapted to each harness's frontmatter/file format) in both **local** and **global** modes.
The **`universal`** target installs skills only into `.agents/skills` / `~/.agents/skills`
for additional `agentskills.io`-compatible harnesses.

| Client (`--client`) | Scope | Skills land at | Subagents land at | Native plugin alternative |
|---------------------|-------|----------------|-------------------|---------------------------|
| **[`claude`](#claude-code)** | Local<br>Global | `.claude/skills/`<br>`~/.claude/skills/` | `.claude/agents/*.md`<br>`~/.claude/agents/*.md` | `/plugin marketplace add nushey/sdd-flow` + `/plugin install sdd-flow@sdd-flow` |
| **[`gemini`](#gemini-cli)** | Local<br>Global | `.agents/skills/`<br>`~/.gemini/skills/` | `.gemini/agents/*.md`<br>`~/.gemini/agents/*.md` | `gemini extensions install https://github.com/nushey/sdd-flow` |
| **[`codex`](#codex)** | Local<br>Global | `.agents/skills/`<br>`~/.agents/skills/` | `.codex/agents/*.toml`<br>`~/.codex/agents/*.toml` | `codex plugin marketplace add nushey/sdd-flow` + `codex plugin add sdd-flow` |
| **[`opencode`](#opencode)** | Local<br>Global | `.agents/skills/`<br>`~/.config/opencode/skills/` | `.opencode/agents/*.md`<br>`~/.config/opencode/agents/*.md` | — |
| **[`kilo`](#kilo-code)** | Local<br>Global | `.agents/skills/`<br>`~/.kilo/skills/` | `.kilo/agents/*.md`<br>`~/.config/kilo/agents/*.md` | — |
| **[`cursor`](#cursor)** | Local<br>Global | `.agents/skills/`<br>`~/.cursor/skills/` | `.cursor/agents/*.md`<br>`~/.cursor/agents/*.md` | Customize → Rules → Remote Rule (GitHub) |
| **[`windsurf`](#windsurf--devin-desktop)** (`devin`) | Local<br>Global | `.devin/skills/`<br>`~/.config/devin/skills/` | `.devin/agents/*.md`<br>`~/.config/devin/agents/*.md` | — |
| **[`antigravity`](#antigravity)** | Local<br>Global | `.agents/skills/`<br>`~/.gemini/config/skills/`, `~/.gemini/antigravity-cli/skills/` | `.agents/agents/*.md`<br>`~/.gemini/config/agents/*.md` | — |
| **[`copilot`](#github-copilot)** | Local<br>Global | `.github/skills/`<br>`~/.copilot/skills/` | `.github/agents/*.agent.md`<br>`~/.copilot/agents/*.agent.md` | — |
| **[`universal`](#universal-agentskills-only)** | Local<br>Global | `.agents/skills/`<br>`~/.agents/skills/` | *(none — skills-only)* | `npx skills add nushey/sdd-flow` |

> **Note on environment overrides:**
> - **Claude Code** respects `$CLAUDE_CONFIG_DIR` (defaults to `~/.claude`).
> - **Codex** respects `$CODEX_HOME` (defaults to `~/.codex`).
> - **Opencode** and **Devin/Windsurf** respect `$XDG_CONFIG_HOME` on Linux/macOS (defaults to `~/.config`). On Windows, Devin global paths use `%APPDATA%\devin\{skills,agents}`.
> - On Windows, `~` is `%USERPROFILE%` (PowerShell's `$HOME`).

### Before you start the SDD flows (all clients)

Standalone `sharp-me` and `sdd-plan` require no subagents. `sharp-me` also works
without a repository. `sdd-review` requires isolated subagent delegation, but no
registered reviewer role. `sdd-implement` works in the current session or an
isolated subagent, according to the user's choice, without a registered developer
role or commits. Plans from `sharp-me` and standalone `sdd-plan` are saved under
`.spec/<plan-name>/`; `sdd-implement` imports external plans there and keeps a
separate cumulative `history.md`. These standalone skills require no feature
branch or checker. The following preconditions apply to `/sdd` and `/mini-sdd`:

1. Your project **must have an `AGENTS.md`** at the root. SDD treats it as law and
   never creates it for you. (Optional companion `CLAUDE.md` is also read if present.)
   **This is still required per-project even if you install globally** — a global
   install only skips re-copying skills/agents into every project, it does not
   supply `AGENTS.md`.
2. The project must be a **git repository with at least one commit** — every flow
   commits on a feature branch and stops at the start otherwise. No remote,
   upstream, or GitHub CLI is needed: both flows end after local verification.
3. Full SDD needs **Python 3.11+** (`python3` on macOS/Linux, `python` on Windows)
   for its checker. It is standard-library only and ships inside the installed
   `sdd` skill (`scripts/sdd.py`, with `sdd` and `sdd.cmd` launchers); the agents
   call it by absolute path. To type `sdd check <slug>` yourself, add that
   `scripts/` folder to your `PATH` — the installer never edits `PATH` or shell
   profiles.

---

## Project (`--local`) vs. Global (`--global`) Install

All flags are **100% optional**. When you run the installer in a terminal without flags,
the wizard asks whether to install **globally** (user-level) or **locally** (current
directory), then which client(s) to install. If you pass only `--client <name>` without
`--global`, `--local`, or `--target`, the wizard still prompts you to choose between
global and local (or defaults to local in non-interactive CI environments).

```bash
# Local: specific project directory
scripts/install.sh --client kilo --target /path/to/project

# Global: every project on this machine
scripts/install.sh --client kilo --global
```

```powershell
# Local: specific project directory
scripts\install.ps1 -Client kilo -Target "C:\path\to\project"

# Global: every project on this machine
scripts\install.ps1 -Client kilo -Global
```

`--global` and `--local` are mutually exclusive; `--target` is ignored with `--global`.

> **PowerShell note:** `$HOME` in `install.ps1` is PowerShell's built-in
> automatic variable, not `$env:HOME` — setting `$env:HOME` before running the
> script has **no effect**. Running `-Global` on Windows writes to your real user
> profile immediately. If you want to test without touching your real machine, use
> `-Target` to a throwaway directory instead of `-Global`.

---

## Claude Code

Claude Code reads skills from `.claude/skills/` and subagents from `.claude/agents/*.md`
(or globally from `~/.claude/skills/` and `~/.claude/agents/*.md`).

```bash
scripts/install.sh --client claude --global   # or --local
```

**Native plugin alternative:**

```text
/plugin marketplace add nushey/sdd-flow
/plugin install sdd-flow@sdd-flow
```

---

## Gemini CLI

Gemini CLI reads Agent Skills from `.agents/skills/` (project) or `~/.gemini/skills/`
(global), and subagents from `.gemini/agents/*.md` (project) or `~/.gemini/agents/*.md`
(global).

```bash
scripts/install.sh --client gemini --global   # or --local
```

**Native extension alternative:**

```bash
gemini extensions install https://github.com/nushey/sdd-flow
```

---

## Codex

Codex (CLI, IDE extension, and app) reads Agent Skills from `.agents/skills/` and
custom agents from `.codex/agents/*.toml`.

```bash
scripts/install.sh --client codex --global    # or --local
```

**What lands:** 7 skills in `.agents/skills/` (or `~/.agents/skills/`) and 5 custom
agents in `.codex/agents/` (or `~/.codex/agents/`) as TOML with `name`, `description`,
`developer_instructions`.

**Native alternative:**

```bash
codex plugin marketplace add nushey/sdd-flow
codex plugin add sdd-flow
```

**Invoke:** type `/skills` or `$sdd` to load the orchestrator, then `/sdd <feature>`.

---

## Opencode

Opencode reads Agent Skills from `.agents/skills/` (project) or
`~/.config/opencode/skills/` (global), and subagents from `.opencode/agents/*.md`
(project) or `~/.config/opencode/agents/*.md` (global).

```bash
scripts/install.sh --client opencode --global # or --local
```

**What lands:** 7 skills and 5 subagents (each with `mode: subagent` injected into its
frontmatter).

**Invoke:** say `/sdd <feature>` for full SDD, or `/mini-sdd <change>` for small fixes.

---

## Kilo Code

Kilo Code reads Agent Skills from `.agents/skills/` (project) or `~/.kilo/skills/`
(global), and subagents from `.kilo/agents/*.md` (project) or `~/.config/kilo/agents/*.md`
(global), with `mode: subagent` injected into frontmatter.

```bash
scripts/install.sh --client kilo --global     # or --local
```

**Invoke:** use the `sdd` skill; say `/sdd <feature>`.

---

## Cursor

Cursor reads Agent Skills from `.agents/skills/` (project) or `~/.cursor/skills/`
(global), and custom subagents from `.cursor/agents/*.md` (project) or
`~/.cursor/agents/*.md` (global).

```bash
scripts/install.sh --client cursor --global   # or --local
```

**Native alternative:** open **Customize → Rules → Add Rule → Remote Rule (GitHub)**
and point it at `https://github.com/nushey/sdd-flow`.

**Invoke:** type `/sdd` in Agent chat, or ask Cursor to "spec this feature".

---

## Windsurf / Devin Desktop

Windsurf (rebranded to **Devin Desktop**, CLI/IDE) supports both `SKILL.md` directories
and Markdown subagent definitions (`agents/*.md`), in addition to project rule files.

```bash
scripts/install.sh --client windsurf --global # or --local (alias: --client devin)
```

**What lands (local):**

- 7 skills in `.devin/skills/`.
- 5 role subagents in `.devin/agents/*.md`. Custom subagents are a preview feature in
  Devin Desktop: enable **Subagents (Preview)** in settings.
- `.devin/rules/sdd.md` and `.windsurfrules` (routing rule fallback).

**What lands (global):**

- 7 skills in `${XDG_CONFIG_HOME:-~/.config}/devin/skills/` (Windows: `%APPDATA%\devin\skills\`).
- 5 role subagents in `${XDG_CONFIG_HOME:-~/.config}/devin/agents/` (Windows: `%APPDATA%\devin\agents\`).

**Invoke:** say `/sdd <feature>` or `/mini-sdd <change>`.

---

## Antigravity

Google Antigravity (IDE & `agy` CLI) loads skills from `.agents/skills/` (local) or
`~/.gemini/config/skills/` and `~/.gemini/antigravity-cli/skills/` (global), and custom
subagents from `.agents/agents/*.md` (local) or `~/.gemini/config/agents/*.md` (global)
with `mainAgent: false` in the YAML frontmatter.

```bash
scripts/install.sh --client antigravity --global # or --local
```

**What lands:** 7 skills and 5 role subagents (with `mainAgent: false`
injected into frontmatter).

**Invoke:** ask the agent to use `/sdd <feature>` or `/mini-sdd <change>`.

---

## GitHub Copilot

GitHub Copilot (VS Code Agent Mode & Coding Agent CLI) reads skills from `.github/skills/`
(local) or `~/.copilot/skills/` (global), and custom agents from
`.github/agents/*.agent.md` (local) or `~/.copilot/agents/*.agent.md` (global).

```bash
scripts/install.sh --client copilot --global  # or --local
```

**What lands:** 7 skills and 5 role subagents (`*.agent.md`).

---

## Universal (`.agents/skills` only)

For any other `agentskills.io`-compliant client (Cline, Roo Code, Goose, Amp, Trae, Zed,
Junie, Warp, etc.) that reads `.agents/skills/` (local) or `~/.agents/skills/` (global)
without a dedicated subagent adapter:

```bash
scripts/install.sh --client universal --global # or --local
```

**Limitation (skills-only):** Standalone `sharp-me` and `sdd-plan` work anywhere;
`sdd-implement` works in-session or with generic subagent delegation, and `sdd-review`
works with generic subagent delegation. Full `/sdd` and `/mini-sdd` require the five
registered role subagents and will stop at the start if installed via `universal` alone.

---

## How it works

sdd-flow conforms to the open [Agent Skills](https://agentskills.io) standard: each
skill is a folder with a `SKILL.md` (YAML frontmatter `name` + `description`, then
instructions). Clients discover skills via **progressive disclosure** — only the
name/description load at startup; the full `SKILL.md` loads when the agent activates
the skill.

Subagent prompts adapt to each client's format:

- **Claude / Gemini / Cursor / Windsurf (Devin)** — `.md` copied as-is.
- **Opencode / Kilo** — `.md` with `mode: subagent` injected into frontmatter.
- **Antigravity** — `.md` with `mainAgent: false` injected into frontmatter.
- **Copilot** — copied as `*.agent.md`.
- **Codex** — `.codex/agents/*.toml` (pre-generated; see [`integrations/codex/`](./integrations/codex)).

The canonical agent prompts live once in [`agents/`](./agents). To regenerate the
Codex TOML adapters after editing them:

```bash
scripts/generate-adapters.sh
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `error: --client is required in non-interactive mode` | Pass `--client <name>` or run in a terminal with TTY access to use the interactive wizard. |
| Skill or subagent not discovered after install | Restart the client so it re-scans skill and agent directories. |
| `Status: FAIL — AGENTS.md missing` | Add an `AGENTS.md` at your project root; SDD never creates it. |
| `ERROR Python 3.11+ is required` or `python3: not found` | Install Python 3.11+ and make sure `python3` (`python` on Windows) is on `PATH`. SDD stops instead of skipping the checker. |
| `ERROR unsupported format: plan.md (Full SDD only)` | Expected for Mini-SDD/standalone plans: `sdd check` validates Full SDD specs only. |
| `sdd check` reports `BAD_ID` / `MISSING_SECTION` on an older spec | Specs created before AC IDs are not migrated automatically. Add `AC-NNN` IDs to `scope.md`, `## Covers` to each task, and the `Covers` column to `tasks.index.md` by hand, keeping task IDs and hashes. |
| Want to publish the feature | Push and open the PR yourself (optionally with the `pr-creation` skill). Neither flow publishes. |
| Want the newest skills/agents | Re-run the same install command. Paths sdd-flow installed (listed in the `.sdd-flow-manifest` next to them) are replaced; identical content is kept. |
| `warning: replacing these paths, which differ from sdd-flow and were not installed by it` | A file or folder with a pack name already existed without an installation record. The installer always replaces it and lists the replaced paths; back them up beforehand if you need them. |
| `error: the cache at ... was cloned from ..., not ...` | The clone cache belongs to another `--source`. Remove it or set `SDD_FLOW_CACHE` to another directory. |
| `error: git fetch/checkout/clone failed; nothing was installed` | Fix the network or the local changes in the cache; the installer never resets the cache and copies nothing after a git error. |
| Wrong project targeted | Add `--target /path/to/project` (bash) or `-Target` (PowerShell). |
| `--global` on Windows wrote to the wrong place / can't sandbox it | Expected — PowerShell's `$HOME` automatic variable ignores `$env:HOME` overrides. `-Global` on Windows always targets your real user profile. Use `-Target <throwaway-dir>` if you just want to test the installer. |

---

## Uninstall

Remove only the pack's own entries — never the shared directories, which may hold
skills and agents from other sources. Each directory the installer wrote to also
holds a `.sdd-flow-manifest` listing exactly what it installed there.

**Project install** (run from the project root):

```bash
rm -rf .agents/skills/{sdd,mini-sdd,sharp-me,sdd-plan,sdd-implement,sdd-review,pr-creation} .agents/skills/.sdd-flow-manifest
# Claude:      rm -rf .claude/skills/{sdd,mini-sdd,sharp-me,sdd-plan,sdd-implement,sdd-review,pr-creation} .claude/skills/.sdd-flow-manifest .claude/agents/{sdd-init,sdd-tech-lead,sdd-developer,sdd-verifier,mini-sdd-developer}.md .claude/agents/.sdd-flow-manifest
# Gemini:      rm -f .gemini/agents/{sdd-init,sdd-tech-lead,sdd-developer,sdd-verifier,mini-sdd-developer}.md .gemini/agents/.sdd-flow-manifest
# Codex:       rm -f .codex/agents/{sdd-init,sdd-tech-lead,sdd-developer,sdd-verifier,mini-sdd-developer}.toml .codex/agents/.sdd-flow-manifest
# Opencode:    rm -f .opencode/agents/{sdd-init,sdd-tech-lead,sdd-developer,sdd-verifier,mini-sdd-developer}.md .opencode/agents/.sdd-flow-manifest
# Kilo:        rm -f .kilo/agents/{sdd-init,sdd-tech-lead,sdd-developer,sdd-verifier,mini-sdd-developer}.md .kilo/agents/.sdd-flow-manifest
# Cursor:      rm -f .cursor/agents/{sdd-init,sdd-tech-lead,sdd-developer,sdd-verifier,mini-sdd-developer}.md .cursor/agents/.sdd-flow-manifest
# Windsurf:    rm -rf .devin/skills/{sdd,mini-sdd,sharp-me,sdd-plan,sdd-implement,sdd-review,pr-creation} .devin/skills/.sdd-flow-manifest .devin/agents/{sdd-init,sdd-tech-lead,sdd-developer,sdd-verifier,mini-sdd-developer}.md .devin/agents/.sdd-flow-manifest .devin/rules/sdd.md .devin/rules/.sdd-flow-manifest .windsurfrules .sdd-flow-manifest
# Antigravity: rm -f .agents/agents/{sdd-init,sdd-tech-lead,sdd-developer,sdd-verifier,mini-sdd-developer}.md .agents/agents/.sdd-flow-manifest
# Copilot:     rm -rf .github/skills/{sdd,mini-sdd,sharp-me,sdd-plan,sdd-implement,sdd-review,pr-creation} .github/skills/.sdd-flow-manifest .github/agents/{sdd-init,sdd-tech-lead,sdd-developer,sdd-verifier,mini-sdd-developer}.agent.md .github/agents/.sdd-flow-manifest
```

**Global install** — remove the same pack entries under the user-level directories from
the [Supported Clients & Paths table](#supported-clients--paths) (`~` = `%USERPROFILE%` on Windows).
On Windows, use `Remove-Item` with the same individual paths.
