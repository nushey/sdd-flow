# integrations/

Per-client adapter files used by the sdd-flow installer (`scripts/install.sh` /
`scripts/install.ps1`).

sdd-flow ships **Agent Skills** (`skills/*/SKILL.md`) and **subagent prompts**
(`agents/*.md`) that conform to the open [agentskills.io](https://agentskills.io)
standard. Most agentic clients read `.agents/skills/<name>/SKILL.md` natively, so
the skills need no transformation — the installer just copies them. Subagent
prompts need a per-client shape, handled as follows:

| Client | Skills | Subagents | Source of the adapter |
|--------|--------|-----------|-----------------------|
| Codex | `.agents/skills/` (copied) | `.codex/agents/*.toml` | **`integrations/codex/agents/*.toml`** (pre-generated) |
| Opencode | `.agents/skills/` (copied) | `.opencode/agents/*.md` (+`mode: subagent`) | generated at install from `agents/*.md` |
| Kilo Code | `.agents/skills/` / `.claude/skills/` (copied) | `.kilo/agent/*.md` | copied verbatim from `agents/*.md` |
| Cursor | `.agents/skills/` / `.cursor/skills/` (copied) | `.cursor/agents/*.md` | copied verbatim from `agents/*.md` |
| Antigravity | `.agents/skills/` (copied) | n/a (orchestrator-only) | none |
| Windsurf / Devin | `.agents/skills/` (copied, best-effort — client-side loading unconfirmed) | rules-driven orchestrator | **`integrations/windsurf/windsurfrules`** |

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
- **`windsurf/windsurfrules`** — Windsurf/Devin Desktop runs the flow as a
  rules-driven orchestrator rather than discrete skill-loaded subagents, so the
  adapter is bespoke prose, not a transform of an agent file.

Opencode / Kilo / Cursor adapters are produced by the installer from
`agents/*.md` (verbatim copy, or a one-line `mode: subagent` frontmatter
injection for Opencode), so they are not duplicated here.
