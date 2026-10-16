# integrations/

Per-client adapter files used by the sdd-flow installer (`scripts/install.sh` /
`scripts/install.ps1`).

sdd-flow ships **Agent Skills** (`skills/*/SKILL.md`) and **subagent prompts**
(`agents/*.md`) that conform to the open [agentskills.io](https://agentskills.io)
standard. Most agentic clients read `.agents/skills/<name>/SKILL.md` natively, so
the skills need no transformation — the installer just copies each skill folder
whole, which is how the `sdd` checker (`skills/sdd/scripts/`) and its contract
(`skills/sdd/references/`) reach every client. Subagent
prompts need a per-client shape, handled as follows:

| Client | Skills (local / global) | Subagents (local / global) | Source of the adapter |
|--------|-------------------------|----------------------------|-----------------------|
| Claude Code (`claude`) | `.claude/skills/` / `~/.claude/skills/` | `.claude/agents/*.md` / `~/.claude/agents/*.md` | copied verbatim from `agents/*.md` |
| Gemini CLI (`gemini`) | `.agents/skills/` / `~/.gemini/skills/` | `.gemini/agents/*.md` / `~/.gemini/agents/*.md` | copied verbatim from `agents/*.md` |
| Codex (`codex`) | `.agents/skills/` / `~/.agents/skills/` | `.codex/agents/*.toml` / `~/.codex/agents/*.toml` | **`integrations/codex/agents/*.toml`** (pre-generated) |
| Opencode (`opencode`) | `.agents/skills/` / `~/.config/opencode/skills/` | `.opencode/agents/*.md` / `~/.config/opencode/agents/*.md` (+`mode: subagent`) | generated at install from `agents/*.md` |
| Kilo Code (`kilo`) | `.agents/skills/` / `~/.kilo/skills/` | `.kilo/agents/*.md` / `~/.config/kilo/agents/*.md` (+`mode: subagent`) | generated at install from `agents/*.md` |
| Cursor (`cursor`) | `.agents/skills/` / `~/.cursor/skills/` | `.cursor/agents/*.md` / `~/.cursor/agents/*.md` | copied verbatim from `agents/*.md` |
| Windsurf / Devin (`windsurf`) | `.devin/skills/` / `~/.config/devin/skills/` | `.devin/agents/*.md` / `~/.config/devin/agents/*.md` | copied verbatim from `agents/*.md` + **`integrations/windsurf/windsurfrules`** |
| Antigravity (`antigravity`) | `.agents/skills/` / `~/.gemini/config/skills/` + `~/.gemini/antigravity-cli/skills/` | `.agents/agents/*.md` / `~/.gemini/config/agents/*.md` (+`mainAgent: false`) | generated at install from `agents/*.md` |
| GitHub Copilot (`copilot`) | `.github/skills/` / `~/.copilot/skills/` | `.github/agents/*.agent.md` / `~/.copilot/agents/*.agent.md` | copied from `agents/*.md` as `*.agent.md` |
| Universal (`universal`) | `.agents/skills/` / `~/.agents/skills/` | none — skills-only install | none |

## Why only two committed adapter trees?

To avoid drift, the **canonical** agent prompts live once in `agents/*.md`. The
installer transforms/copies them at install time for every client. We commit only
what is genuinely bespoke:

- **`codex/agents/*.toml`** — Codex custom agents are TOML; the md→toml transform
  is mechanical but fiddly, so we pre-generate and commit deterministic, validated
  files. Regenerate after editing `agents/*.md`:
  ```bash
  scripts/generate-adapters.sh
  ```
- **`windsurf/windsurfrules`** — Windsurf/Devin Desktop rules file installed at
  `.devin/rules/sdd.md` and `.windsurfrules` alongside the skills and role
  subagents.

All other client adapters (Claude, Gemini, Opencode, Kilo, Cursor, Windsurf/Devin
agents, Antigravity, Copilot) are produced by the installer from `agents/*.md`
(verbatim copy, frontmatter injection, or `.agent.md` rename), so they are not
duplicated here.
