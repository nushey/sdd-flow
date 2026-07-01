#!/usr/bin/env bash
# install.sh — install sdd-flow into any supported agentic client.
#
# sdd-flow is an Agent Skills + subagents pack (agentskills.io), NOT an MCP
# server. This script copies the 5 skills into the client's skill directory and
# the 5 subagent prompts into the client's agent directory, in the right shape.
#
# Usage:
#   scripts/install.sh --client <codex|opencode|kilo|cursor|windsurf|antigravity> \
#                      [--target <dir>] [--source <path|url>]
#
#   # One-liner from anywhere (clones sdd-flow to a cache):
#   curl -fsSL https://raw.githubusercontent.com/nushey/sdd-flow/main/scripts/install.sh \
#     | bash -s -- --client codex
#
#   # Or run from a local clone (auto-detected, no network):
#   git clone https://github.com/nushey/sdd-flow && sdd-flow/scripts/install.sh --client kilo
#
# Flags:
#   --client  (required) target client.
#   --target  project root to install into (default: current directory).
#   --source  local sdd-flow checkout, or a git URL (default: auto-detect local
#             repo, else clone https://github.com/nushey/sdd-flow).
#   --help    show this help.

set -euo pipefail

REPO_URL="https://github.com/nushey/sdd-flow.git"
CACHE="${SDD_FLOW_CACHE:-$HOME/.cache/sdd-flow}"
CLIENTS="codex opencode kilo cursor windsurf antigravity"

CLIENT=""
TARGET="."
ARG_SOURCE=""

usage() {
  sed -n '3,24p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --client)  CLIENT="$2"; shift 2;;
    --target)  TARGET="$2"; shift 2;;
    --source)  ARG_SOURCE="$2"; shift 2;;
    --help|-h) usage 0;;
    *) echo "error: unknown argument: $1" >&2; usage 1;;
  esac
done

[[ -n "$CLIENT" ]] || { echo "error: --client is required (one of: $CLIENTS)" >&2; usage 1; }
# shellcheck disable=SC2086
case " $CLIENTS " in *" $CLIENT "*) ;; *) echo "error: unknown client '$CLIENT' (one of: $CLIENTS)" >&2; exit 1;; esac

command -v git >/dev/null 2>&1 || { echo "error: git is required" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#--- source resolution -------------------------------------------------------
resolve_source() {
  if [[ -n "$ARG_SOURCE" ]]; then
    if [[ "$ARG_SOURCE" =~ ^https?:// || "$ARG_SOURCE" =~ ^git@ ]]; then
      clone_or_update "$ARG_SOURCE" "$CACHE"
      SRC="$CACHE"
    else
      SRC="$ARG_SOURCE"
    fi
    return
  fi
  # Auto-detect: are we running from inside the sdd-flow repo?
  local repo_local="$SCRIPT_DIR/.."
  if [[ -d "$repo_local/skills" && -d "$repo_local/agents" ]]; then
    SRC="$(cd "$repo_local" && pwd)"
    return
  fi
  clone_or_update "$REPO_URL" "$CACHE"
  SRC="$CACHE"
}

clone_or_update() {
  local url="$1" dest="$2"
  if [[ -d "$dest/.git" ]]; then
    echo "Updating cached sdd-flow at $dest"
    git -C "$dest" fetch --depth 1 origin HEAD >/dev/null 2>&1 || true
    git -C "$dest" checkout -q FETCH_HEAD 2>/dev/null || git -C "$dest" reset --hard -q HEAD
  else
    echo "Cloning sdd-flow from $url"
    git clone --depth 1 "$url" "$dest"
  fi
}

#--- helpers -----------------------------------------------------------------
copy_skills() {
  # $1 = absolute source root, $2 = target skill dir (e.g. <target>/.agents/skills)
  local src="$1" dest_skills="$2"
  mkdir -p "$dest_skills"
  local d name
  for d in "$src"/skills/*/; do
    [[ -d "$d" ]] || continue
    name="$(basename "$d")"
    rm -rf "${dest_skills:?}/$name"
    cp -r "$d" "${dest_skills:?}/$name"
    echo "  skill:  $name"
  done
}

emit_opencode_agent() {
  # Insert `mode: subagent` after the opening frontmatter delimiter.
  awk 'NR==1 && /^---[[:space:]]*$/ {print; print "mode: subagent"; next} {print}' "$1" > "$2"
}

#--- per-client install ------------------------------------------------------
install_codex() {
  local src="$1" t="$2"
  copy_skills "$src" "$t/.agents/skills"
  mkdir -p "$t/.codex/agents"
  local f base
  for f in "$src"/integrations/codex/agents/*.toml; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    cp "$f" "$t/.codex/agents/$base"
    echo "  agent:  .codex/agents/$base"
  done
}

install_opencode() {
  local src="$1" t="$2"
  copy_skills "$src" "$t/.agents/skills"
  mkdir -p "$t/.opencode/agents"
  local f base
  for f in "$src"/agents/*.md; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    emit_opencode_agent "$f" "$t/.opencode/agents/$base"
    echo "  agent:  .opencode/agents/$base"
  done
}

install_kilo() {
  local src="$1" t="$2"
  copy_skills "$src" "$t/.agents/skills"
  mkdir -p "$t/.kilo/agent"
  local f base
  for f in "$src"/agents/*.md; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    cp "$f" "$t/.kilo/agent/$base"
    echo "  agent:  .kilo/agent/$base"
  done
}

install_cursor() {
  local src="$1" t="$2"
  copy_skills "$src" "$t/.agents/skills"
  mkdir -p "$t/.cursor/agents"
  local f base
  for f in "$src"/agents/*.md; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    cp "$f" "$t/.cursor/agents/$base"
    echo "  agent:  .cursor/agents/$base"
  done
}

install_windsurf() {
  local src="$1" t="$2"
  copy_skills "$src" "$t/.agents/skills"   # best-effort; rules carry the logic
  mkdir -p "$t/.devin/rules"
  cp "$src/integrations/windsurf/windsurfrules" "$t/.devin/rules/sdd.md"
  echo "  rules:  .devin/rules/sdd.md"
  # Legacy single-file for pre-rebrand Windsurf.
  cp "$src/integrations/windsurf/windsurfrules" "$t/.windsurfrules"
  echo "  rules:  .windsurfrules (legacy)"
}

install_antigravity() {
  local src="$1" t="$2"
  copy_skills "$src" "$t/.agents/skills"
}

invoke_hint() {
  case "$1" in
    codex)       echo "  - Type /skills or use the agent to load the 'sdd' skill; run /sdd <feature>.";;
    opencode)    echo "  - The agent auto-loads the 'sdd' skill; say '/sdd <feature>' or '@sdd-developer ...'.";;
    kilo)        echo "  - Use the 'sdd' skill; say '/sdd <feature>'.";;
    cursor)      echo "  - Type /sdd or let the agent load the 'sdd' skill by asking to 'spec this'.";;
    windsurf)    echo "  - Say '/sdd <feature>' or 'use SDD to plan <feature>' (rules-driven orchestrator).";;
    antigravity) echo "  - Ask the agent to use the 'sdd' skill, or say 'use SDD for <feature>'.";;
  esac
}

#--- main --------------------------------------------------------------------
resolve_source
SRC="$(cd "$SRC" && pwd)"
mkdir -p "$TARGET"
TARGET="$(cd "$TARGET" && pwd)"

[[ -d "$SRC/skills" && -d "$SRC/agents" ]] || { echo "error: source has no skills/ and agents/ ($SRC)" >&2; exit 1; }

echo "Installing sdd-flow for '$CLIENT'"
echo "  source: $SRC"
echo "  target: $TARGET"

case "$CLIENT" in
  codex)       install_codex "$SRC" "$TARGET";;
  opencode)    install_opencode "$SRC" "$TARGET";;
  kilo)        install_kilo "$SRC" "$TARGET";;
  cursor)      install_cursor "$SRC" "$TARGET";;
  windsurf)    install_windsurf "$SRC" "$TARGET";;
  antigravity) install_antigravity "$SRC" "$TARGET";;
esac

cat <<EOF

Done. sdd-flow is installed for $CLIENT.

Before you start:
  - Make sure your project has an AGENTS.md at the root (user-provided; SDD never creates it).
  - Install the GitHub CLI (gh) and run \`gh auth login\` — the Verifier opens PRs with it.

Invoke:
$(invoke_hint "$CLIENT")

Re-run this command any time to refresh skills/agents.
EOF
