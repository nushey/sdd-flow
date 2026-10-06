#!/usr/bin/env bash
# install.sh — install sdd-flow into any supported agentic client.
#
# sdd-flow is an Agent Skills + subagents pack (agentskills.io), NOT an MCP
# server. This script copies the 5 skills into the client's skill directory and
# the 5 subagent prompts into the client's agent directory, in the right shape.
#
# Usage:
#   scripts/install.sh --client <codex|opencode|kilo|cursor|windsurf|antigravity> \
#                      [--target <dir> | --global] [--source <path|url>] [--force]
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
#   --target  project root to install into (default: current directory). Ignored with --global.
#   --global  install to the client's user-level (all-projects) directory instead of
#             a project. Only copies pieces with a confirmed global path for that
#             client — anything unconfirmed is skipped with a printed note, never
#             guessed.
#   --source  local sdd-flow checkout, or a git URL (default: auto-detect local
#             repo, else clone https://github.com/nushey/sdd-flow).
#   --force   replace existing files/folders whose names collide with the pack but
#             that sdd-flow did not install (by default the install stops and lists them).
#   --help    show this help.

set -euo pipefail

REPO_URL="https://github.com/nushey/sdd-flow.git"
CACHE="${SDD_FLOW_CACHE:-$HOME/.cache/sdd-flow}"
CLIENTS="codex opencode kilo cursor windsurf antigravity"
MANIFEST=".sdd-flow-manifest"

CLIENT=""
TARGET="."
ARG_SOURCE=""
GLOBAL=0
FORCE=0

usage() {
  sed -n '3,30p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --client)  CLIENT="$2"; shift 2;;
    --target)  TARGET="$2"; shift 2;;
    --global)  GLOBAL=1; shift;;
    --source)  ARG_SOURCE="$2"; shift 2;;
    --force)   FORCE=1; shift;;
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

normalize_url() {
  local u="${1%/}"
  echo "${u%.git}"
}

clone_or_update() {
  local url="$1" dest="$2" cached
  if [[ -d "$dest/.git" ]]; then
    cached="$(git -C "$dest" config --get remote.origin.url)" \
      || { echo "error: cannot read the origin of the cache at $dest" >&2; exit 1; }
    if [[ "$(normalize_url "$cached")" != "$(normalize_url "$url")" ]]; then
      echo "error: the cache at $dest was cloned from $cached, not $url." >&2
      echo "       Remove that cache or set SDD_FLOW_CACHE to another directory." >&2
      exit 1
    fi
    echo "Updating cached sdd-flow at $dest"
    git -C "$dest" fetch --depth 1 origin HEAD \
      || { echo "error: git fetch failed; nothing was installed" >&2; exit 1; }
    git -C "$dest" checkout -q FETCH_HEAD \
      || { echo "error: git checkout failed in $dest (local changes kept); nothing was installed" >&2; exit 1; }
  else
    echo "Cloning sdd-flow from $url"
    git clone --depth 1 "$url" "$dest" \
      || { echo "error: git clone failed; nothing was installed" >&2; exit 1; }
  fi
}

#--- install plan --------------------------------------------------------------
# Every pack item is queued as (source, destination) first, checked for
# collisions, and only then copied. Destinations installed by sdd-flow are
# recorded by name in a .sdd-flow-manifest file next to them.
PLAN_SRC=()
PLAN_DEST=()
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

queue() {
  PLAN_SRC+=("$1")
  PLAN_DEST+=("$2")
}

queue_skills() {
  # $1 = source root, $2 = target skill dir (e.g. <target>/.agents/skills)
  local d
  for d in "$1"/skills/*/; do
    [[ -d "$d" ]] || continue
    queue "${d%/}" "$2/$(basename "$d")"
  done
}

queue_files() {
  # $1 = source dir, $2 = extension, $3 = destination dir
  local f
  for f in "$1"/*."$2"; do
    [[ -f "$f" ]] || continue
    queue "$f" "$3/$(basename "$f")"
  done
}

queue_opencode_agents() {
  # Insert `mode: subagent` after the opening frontmatter delimiter.
  local f base
  mkdir -p "$STAGE/opencode"
  for f in "$1"/agents/*.md; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    awk 'NR==1 && /^---[[:space:]]*$/ {print; print "mode: subagent"; next} {print}' "$f" > "$STAGE/opencode/$base"
    queue "$STAGE/opencode/$base" "$2/$base"
  done
}

owned() {
  local manifest
  manifest="$(dirname "$1")/$MANIFEST"
  [[ -f "$manifest" ]] && grep -Fxq "$(basename "$1")" "$manifest"
}

same_content() {
  if [[ -d "$1" ]]; then
    [[ -d "$2" ]] && diff -rq "$1" "$2" >/dev/null 2>&1
  else
    [[ -f "$2" ]] && cmp -s "$1" "$2"
  fi
}

record() {
  local manifest
  manifest="$(dirname "$1")/$MANIFEST"
  owned "$1" || echo "$(basename "$1")" >> "$manifest"
}

check_collisions() {
  local i dest conflicts=0
  for i in "${!PLAN_DEST[@]}"; do
    dest="${PLAN_DEST[$i]}"
    [[ -e "$dest" ]] || continue
    if owned "$dest" || same_content "${PLAN_SRC[$i]}" "$dest"; then
      continue
    fi
    [[ "$conflicts" -eq 0 ]] && echo "error: these paths exist, differ from sdd-flow and were not installed by it:" >&2
    echo "  $dest" >&2
    conflicts=$((conflicts + 1))
  done
  if [[ "$conflicts" -gt 0 ]]; then
    [[ "$FORCE" -eq 1 ]] && { echo "  --force: replacing them." >&2; return; }
    echo "Nothing was installed. Move them away, or re-run with --force to replace them." >&2
    exit 1
  fi
}

apply_plan() {
  local i src dest
  for i in "${!PLAN_DEST[@]}"; do
    src="${PLAN_SRC[$i]}"
    dest="${PLAN_DEST[$i]}"
    mkdir -p "$(dirname "$dest")"
    if [[ -e "$dest" ]] && same_content "$src" "$dest"; then
      echo "  unchanged: $dest"
    else
      rm -rf "$dest"
      cp -R "$src" "$dest"
      echo "  installed: $dest"
    fi
    record "$dest"
  done
}

#--- per-client plan -----------------------------------------------------------
plan_project() {
  local src="$1" t="$2"
  queue_skills "$src" "$t/.agents/skills"
  case "$CLIENT" in
    codex)    queue_files "$src/integrations/codex/agents" toml "$t/.codex/agents";;
    opencode) queue_opencode_agents "$src" "$t/.opencode/agents";;
    kilo)     queue_files "$src/agents" md "$t/.kilo/agent";;
    cursor)   queue_files "$src/agents" md "$t/.cursor/agents";;
    windsurf)
      queue "$src/integrations/windsurf/windsurfrules" "$t/.devin/rules/sdd.md"
      # Legacy single-file for pre-rebrand Windsurf.
      queue "$src/integrations/windsurf/windsurfrules" "$t/.windsurfrules";;
    antigravity) ;;
  esac
}

# Only confirmed global directories are used here. A client with no confirmed
# global path for a piece prints a skip note instead of guessing — install
# per-project for that piece with the default (non --global) command.
plan_global() {
  local src="$1"
  case "$CLIENT" in
    codex)
      queue_skills "$src" "$HOME/.agents/skills"
      queue_files "$src/integrations/codex/agents" toml "$HOME/.codex/agents";;
    opencode)
      queue_skills "$src" "$HOME/.config/opencode/skills"
      queue_opencode_agents "$src" "$HOME/.config/opencode/agents";;
    kilo)
      queue_skills "$src" "$HOME/.kilo/skills"
      queue_files "$src/agents" md "$HOME/.kilo/agent";;
    cursor)
      queue_skills "$src" "$HOME/.cursor/skills"
      queue_files "$src/agents" md "$HOME/.cursor/agents";;
    windsurf)
      queue_skills "$src" "$HOME/.codeium/windsurf/skills"
      echo "  skip:   global rules — no confirmed user-level rules directory for Windsurf/Devin Desktop."
      echo "          Install rules per-project: scripts/install.sh --client windsurf --target <dir>";;
    antigravity)
      queue_skills "$src" "$HOME/.gemini/config/skills";;
  esac
}

invoke_hint() {
  case "$1" in
    codex)       echo "  - Type /skills or use the agent to load the 'sdd' skill; run /sdd <feature>.";;
    opencode)    echo "  - The agent auto-loads the 'sdd' skill; say '/sdd <feature>' or '@sdd-developer ...'.";;
    kilo)        echo "  - Use the 'sdd' skill; say '/sdd <feature>'.";;
    cursor)      echo "  - Type /sdd or let the agent load the 'sdd' skill by asking to 'spec this'.";;
    windsurf)    echo "  - Partial install: no role subagents are installed for this client, so /sdd and"
                 echo "    /mini-sdd stop before writing artifacts unless the roles are available. See INSTALL.md.";;
    antigravity) echo "  - Partial install: skills only. /sdd and /mini-sdd require subagent delegation and"
                 echo "    stop before writing artifacts on this client. See INSTALL.md.";;
  esac
}

#--- main --------------------------------------------------------------------
resolve_source
SRC="$(cd "$SRC" && pwd)"

[[ -d "$SRC/skills" && -d "$SRC/agents" ]] || { echo "error: source has no skills/ and agents/ ($SRC)" >&2; exit 1; }

if [[ "$GLOBAL" -eq 1 ]]; then
  echo "Installing sdd-flow for '$CLIENT' (global, user-level)"
  echo "  source: $SRC"
  plan_global "$SRC"
  check_collisions
  apply_plan
  cat <<EOF

Done. sdd-flow is installed for $CLIENT (global — applies to every project on this machine).

Before you start:
  - Every project you use sdd-flow in still needs its own AGENTS.md at the root
    (user-provided; SDD never creates it). Global install only skips re-copying
    skills/agents per project — it does not skip that precondition.
  - Every project must be a git repository. Install the GitHub CLI (gh) and run
    \`gh auth login\` — the Verifier opens PRs with it.

Invoke:
$(invoke_hint "$CLIENT")

Re-run this command any time to refresh skills/agents.
EOF
else
  mkdir -p "$TARGET"
  TARGET="$(cd "$TARGET" && pwd)"
  echo "Installing sdd-flow for '$CLIENT'"
  echo "  source: $SRC"
  echo "  target: $TARGET"
  plan_project "$SRC" "$TARGET"
  check_collisions
  apply_plan
  cat <<EOF

Done. sdd-flow is installed for $CLIENT.

Before you start:
  - Make sure your project has an AGENTS.md at the root (user-provided; SDD never creates it).
  - The project must be a git repository. Install the GitHub CLI (gh) and run
    \`gh auth login\` — the Verifier opens PRs with it.

Invoke:
$(invoke_hint "$CLIENT")

Re-run this command any time to refresh skills/agents.
EOF
fi
