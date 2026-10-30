# Installing sdd-flow

sdd-flow is a set of [Agent Skills](https://agentskills.io): 11 skills and 5 subagents written in Markdown. It is not an MCP server, so there is nothing to run or register in `mcpServers`.

## Quick install

**macOS / Linux / WSL / git-bash**

```bash
curl -fsSL https://raw.githubusercontent.com/nushey/sdd-flow/main/scripts/install.sh | bash
```

**Windows (PowerShell 5.1 or 7+)**

```powershell
irm https://raw.githubusercontent.com/nushey/sdd-flow/main/scripts/install.ps1 -OutFile install.ps1
.\install.ps1
```

The installer asks two things:

1. **Scope:** global (every project on this machine) or local (the current project).
2. **Clients:** pick one or more with ↑↓ and Space, then press Enter.

Clients that share a skills folder, such as `.agents/skills`, are grouped together: the skills are written once and all of them use it. `[detected]` marks clients found on your machine. `[plugin installed]` means the native plugin is already there; installing the script copy too is allowed.

To read the script before running it, clone the repo and run it from there. It uses the local copy and skips the network:

```bash
git clone https://github.com/nushey/sdd-flow
sdd-flow/scripts/install.sh   # or .\sdd-flow\scripts\install.ps1
```

## Native plugins

| Client | Command |
|--------|---------|
| Claude Code | `/plugin marketplace add nushey/sdd-flow`, then `/plugin install sdd-flow@sdd-flow` |
| Gemini CLI | `gemini extensions install https://github.com/nushey/sdd-flow` |
| Codex | `codex plugin marketplace add nushey/sdd-flow`, then `codex plugin add sdd-flow` |
| Cursor | Customize → Rules → Add Rule → Remote Rule (GitHub), pointing at `https://github.com/nushey/sdd-flow` |
| Others | `npx skills add nushey/sdd-flow` (skills only) |

## Without the wizard

Pass a client and a scope to skip the questions, for example in CI:

```bash
curl -fsSL https://raw.githubusercontent.com/nushey/sdd-flow/main/scripts/install.sh \
  | bash -s -- --client cursor,codex --global
```

```powershell
.\install.ps1 -Client cursor,codex -Global
```

| Flag (bash) | PowerShell | Meaning |
|-------------|------------|---------|
| `--client`, `-c` | `-Client` | One or more clients, comma-separated, or `all`. |
| `--global`, `-g` | `-Global` | Install for your user, in every project. |
| `--local`, `-l` | `-Local` | Install in the current directory. |
| `--target`, `-t` | `-Target` | Install in another project directory. Ignored with `--global`. |

`--global` and `--local` can't be combined. If you pass only `--client`, the installer still asks for the scope, or installs locally when there is no terminal to ask in.

Client names: `claude`, `gemini`, `codex`, `opencode`, `kilo`, `cursor`, `windsurf` (alias `devin`), `antigravity`, `copilot`, `universal`.

## Where files go

| Client | Skills (local / global) | Subagents (local / global) |
|--------|-------------------------|----------------------------|
| `claude` | `.claude/skills/` / `~/.claude/skills/` | `.claude/agents/` / `~/.claude/agents/` |
| `gemini` | `.agents/skills/` / `~/.gemini/skills/` | `.gemini/agents/` / `~/.gemini/agents/` |
| `codex` | `.agents/skills/` / `~/.agents/skills/` | `.codex/agents/*.toml` / `~/.codex/agents/*.toml` |
| `opencode` | `.agents/skills/` / `~/.config/opencode/skills/` | `.opencode/agents/` / `~/.config/opencode/agents/` |
| `kilo` | `.agents/skills/` / `~/.kilo/skills/` | `.kilo/agents/` / `~/.config/kilo/agents/` |
| `cursor` | `.agents/skills/` / `~/.cursor/skills/` | `.cursor/agents/` / `~/.cursor/agents/` |
| `windsurf` | `.devin/skills/` / `~/.config/devin/skills/` | `.devin/agents/` / `~/.config/devin/agents/` |
| `antigravity` | `.agents/skills/` / `~/.gemini/config/skills/` and `~/.gemini/antigravity-cli/skills/` | `.agents/agents/` / `~/.gemini/config/agents/` |
| `copilot` | `.github/skills/` / `~/.copilot/skills/` | `.github/agents/*.agent.md` / `~/.copilot/agents/*.agent.md` |
| `universal` | `.agents/skills/` / `~/.agents/skills/` | none |

A few notes:

- Claude Code honors `$CLAUDE_CONFIG_DIR`, Codex honors `$CODEX_HOME`, and Opencode and Windsurf/Devin honor `$XDG_CONFIG_HOME`.
- On Windows, `~` is your user profile, and Windsurf/Devin global files go to `%APPDATA%\devin\`.
- Windsurf/Devin also gets `.devin/rules/sdd.md` and `.windsurfrules` on local installs. Its subagents need **Subagents (Preview)** turned on in settings.
- `universal` is for any other Agent Skills client (Cline, Roo Code, Goose, Amp, Zed, and others). It installs skills only, so `/sdd` and `/mini-sdd` won't run there because they need the subagents. The standalone skills work.

## Before using `/sdd` or `/mini-sdd`

- Add an `AGENTS.md` at the project root. sdd-flow reads it as the project's rules and never creates it. A global install doesn't change this: each project needs its own.
- Work in a git repository with at least one commit. No remote or GitHub CLI is needed.
- For `/sdd`, install Python 3.11+ (`python3` on macOS/Linux, `python` on Windows). The agents run the checker themselves. If you want to run `sdd check <slug>` by hand, add the installed `sdd` skill's `scripts/` folder to your `PATH`.

The standalone skills (`sharp-me`, `sdd-plan`, `sdd-debug`, `sdd-implement`, `sdd-code-review`, `sdd-acceptance-review`, `writing-agents`, `writing-humans`) don't need the role subagents or the checker.

## Updating

Run the same install command again. It replaces what it installed before and keeps files whose content hasn't changed.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `--client is required in non-interactive mode` | Pass `--client <name>`, or run the installer in a terminal to get the wizard. |
| Skills or subagents don't show up | Restart the client so it scans its folders again. |
| `AGENTS.md missing` | Add an `AGENTS.md` at the project root. |
| `Python 3.11+ is required` or `python3: not found` | Install Python 3.11+ and make sure it is on your `PATH`. |
| `unsupported format: plan.md (Full SDD only)` | Expected: `sdd check` only validates `/sdd` specs. |
| `BAD_ID` or `MISSING_SECTION` on an old spec | Old specs aren't migrated. Add `AC-NNN` IDs to `scope.md`, a `## Covers` section to each task, and a `Covers` column to `tasks.index.md` by hand. |
| `replacing these paths, which differ from sdd-flow and were not installed by it` | A file with the same name already existed. The installer replaces it and lists it; back it up first if you need it. |
| `the cache at ... was cloned from ..., not ...` | The cache belongs to another `--source`. Delete it or point `SDD_FLOW_CACHE` to another folder. |
| `git fetch/checkout/clone failed; nothing was installed` | Fix the network or the local changes in the cache, then retry. |
| Installed in the wrong project | Use `--target /path/to/project` (bash) or `-Target` (PowerShell). |
| `-Global` on Windows ignores `$env:HOME` | Expected: it always writes to your real user profile. Use `-Target <folder>` to test somewhere else. |
| You want to push or open a PR | Do it yourself. You can use `/pr-creation` for the description. |

## Uninstall

Each folder the installer wrote to has a `.sdd-flow-manifest` file that lists what it installed there. Delete those entries and the manifest, and leave the folder alone, since it may hold skills from other sources.

For example, for a local install in `.agents/skills/`:

```bash
cd .agents/skills
xargs rm -rf < .sdd-flow-manifest && rm .sdd-flow-manifest
```

Repeat for every folder from [Where files go](#where-files-go) that has a manifest. A local Windsurf/Devin install also leaves one in `.devin/rules/` and one in the project root. On Windows, use `Remove-Item` with the same paths.
