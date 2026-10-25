#!/usr/bin/env bash

set -euo pipefail

REPO_URL="https://github.com/nushey/sdd-flow.git"
CACHE="${SDD_FLOW_CACHE:-$HOME/.cache/sdd-flow}"
CLIENTS_FULL=(claude gemini codex opencode kilo cursor windsurf antigravity copilot)
CLIENTS_ALL=(claude gemini codex opencode kilo cursor windsurf antigravity copilot universal)
MANIFEST=".sdd-flow-manifest"

RAW_CLIENTS=()
SELECTED_CLIENTS=()
TARGET="."
ARG_SOURCE=""
GLOBAL=0
LOCAL_FLAG=0
TARGET_SET=0

usage() {
  cat <<'EOF'
install.sh — install sdd-flow into any supported agentic client.

sdd-flow is an Agent Skills + subagents pack (agentskills.io), NOT an MCP
server. This script copies the 10 skills into the client's skill directory and
the 5 subagent prompts into the client's agent directory, in the right shape.

Usage:
  scripts/install.sh [--client <client[,client...]|all>]
                     [--global | --local] [--target <dir>]
                     [--source <path|url>]

  # Interactive wizard (select client and global/local scope):
  curl -fsSL https://raw.githubusercontent.com/nushey/sdd-flow/main/scripts/install.sh | bash

  # Direct non-interactive install:
  curl -fsSL https://raw.githubusercontent.com/nushey/sdd-flow/main/scripts/install.sh \
    | bash -s -- --client claude --global

Supported clients:
  claude       Claude Code (.claude/skills + .claude/agents)
  gemini       Gemini CLI (.agents/skills or ~/.gemini/skills + .gemini/agents)
  codex        OpenAI Codex (.agents/skills + .codex/agents/*.toml)
  opencode     OpenCode (.agents/skills or ~/.config/opencode/skills + agents)
  kilo         Kilo Code (.agents/skills or ~/.kilo/skills + .kilo/agents)
  cursor       Cursor (.agents/skills or ~/.cursor/skills + .cursor/agents)
  windsurf     Windsurf / Devin Desktop (.devin skills/agents/rules + .windsurfrules)
  antigravity  Google Antigravity (.agents/skills & agents or ~/.gemini/config)
  copilot      GitHub Copilot (.github/skills + .github/agents)
  universal    Universal skills-only (.agents/skills or ~/.agents/skills)
  all          All 9 full clients above

Flags:
  --client, -c  Target client(s), comma-separated, or 'all'.
                If omitted, an interactive wizard opens.
  --global, -g  Install to the client's user-level directory (~/) for all projects.
  --local,  -l  Install to the project root (default: current directory).
  --target, -t  Project root to install into (ignored with --global).
  --source      Local sdd-flow checkout or git URL.
  --help,   -h  Show this help.
EOF
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --client|-c) RAW_CLIENTS+=("$2"); shift 2;;
    --target|-t) TARGET="$2"; TARGET_SET=1; shift 2;;
    --global|-g) GLOBAL=1; shift;;
    --local|-l)  LOCAL_FLAG=1; shift;;
    --source)    ARG_SOURCE="$2"; shift 2;;
    --help|-h)   usage 0;;
    *) echo "error: unknown argument: $1" >&2; usage 1;;
  esac
done

if [[ "$GLOBAL" -eq 1 && "$LOCAL_FLAG" -eq 1 ]]; then
  echo "error: --global and --local cannot be used together" >&2
  exit 1
fi

command -v git >/dev/null 2>&1 || { echo "error: git is required" >&2; exit 1; }

if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  SCRIPT_DIR="$PWD"
fi

claude_home() { echo "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"; }
codex_home()  { echo "${CODEX_HOME:-$HOME/.codex}"; }
config_home() { echo "${XDG_CONFIG_HOME:-$HOME/.config}"; }

client_label() {
  case "$1" in
    claude)      echo "Claude Code";;
    gemini)      echo "Gemini CLI";;
    codex)       echo "OpenAI Codex";;
    opencode)    echo "OpenCode";;
    kilo)        echo "Kilo Code";;
    cursor)      echo "Cursor";;
    windsurf)    echo "Windsurf / Devin Desktop";;
    antigravity) echo "Google Antigravity";;
    copilot)     echo "GitHub Copilot";;
    universal)   echo "Universal (skills only)";;
  esac
}

is_client_detected() {
  case "$1" in
    claude)
      [[ -d "$(claude_home)" ]] || command -v claude >/dev/null 2>&1;;
    gemini)
      command -v gemini >/dev/null 2>&1 || [[ -d "$HOME/.gemini/extensions" || -d "$HOME/.gemini/skills" || -f "$HOME/.gemini/settings.json" ]];;
    codex)
      [[ -d "$(codex_home)" || -d "/etc/codex" ]] || command -v codex >/dev/null 2>&1;;
    opencode)
      [[ -d "$(config_home)/opencode" ]] || command -v opencode >/dev/null 2>&1;;
    kilo)
      [[ -d "$HOME/.kilo" || -d "$HOME/.kilocode" || -d "$(config_home)/kilo" ]] || command -v kilo >/dev/null 2>&1;;
    cursor)
      [[ -d "$HOME/.cursor" ]] || command -v cursor >/dev/null 2>&1;;
    windsurf)
      [[ -d "$(config_home)/devin" || -d "$HOME/.codeium/windsurf" || -d "$HOME/.windsurf" || -d "$HOME/.devin" ]] \
        || command -v windsurf >/dev/null 2>&1 || command -v devin >/dev/null 2>&1;;
    antigravity)
      [[ -d "$HOME/.gemini/antigravity" || -d "$HOME/.gemini/antigravity-cli" || -d "$HOME/.gemini/config" ]] \
        || command -v agy >/dev/null 2>&1;;
    copilot)
      [[ -d "$HOME/.copilot" ]] || command -v copilot >/dev/null 2>&1;;
    *)
      return 1;;
  esac
}

normalize_client() {
  case "$1" in
    claude|claude-code)     echo "claude";;
    gemini|gemini-cli)      echo "gemini";;
    codex)                  echo "codex";;
    opencode)               echo "opencode";;
    kilo|kilocode)          echo "kilo";;
    cursor)                 echo "cursor";;
    windsurf|devin)         echo "windsurf";;
    antigravity|agy)        echo "antigravity";;
    copilot|github-copilot) echo "copilot";;
    universal)              echo "universal";;
    all)                    echo "all";;
    *)                      return 1;;
  esac
}

contains() {
  local needle="$1" item
  shift
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

add_selected_client() {
  contains "$1" "${SELECTED_CLIENTS[@]+"${SELECTED_CLIENTS[@]}"}" || SELECTED_CLIENTS+=("$1")
}

has_plugin_install() {
  case "$1" in
    claude) grep -Fqs '"sdd-flow@sdd-flow"' "$(claude_home)/plugins/installed_plugins.json";;
    codex)  grep -Fqs '[plugins."sdd-flow@sdd-flow"]' "$(codex_home)/config.toml";;
    *)      return 1;;
  esac
}

expand_client_token() {
  local raw="$1" norm c
  norm="$(normalize_client "$raw")" || {
    echo "error: unknown client '$raw' (expected one of: ${CLIENTS_ALL[*]} all)" >&2
    exit 1
  }
  case "$norm" in
    all)
      for c in "${CLIENTS_FULL[@]}"; do add_selected_client "$c"; done;;
    *)
      add_selected_client "$norm";;
  esac
}

parse_raw_clients() {
  local entry token tokens
  for entry in "${RAW_CLIENTS[@]}"; do
    IFS=', ' read -r -a tokens <<< "$entry"
    for token in "${tokens[@]}"; do
      [[ -z "$token" ]] || expand_client_token "$token"
    done
  done
}

can_prompt() {
  (: < /dev/tty) 2>/dev/null
}

skills_dir() {
  if [[ "$GLOBAL" -eq 1 ]]; then
    case "$1" in
      claude)          echo "$(claude_home)/skills";;
      gemini)          echo "$HOME/.gemini/skills";;
      codex|universal) echo "$HOME/.agents/skills";;
      opencode)        echo "$(config_home)/opencode/skills";;
      kilo)            echo "$HOME/.kilo/skills";;
      cursor)          echo "$HOME/.cursor/skills";;
      windsurf)        echo "$(config_home)/devin/skills";;
      antigravity)     echo "$HOME/.gemini/config/skills";;
      copilot)         echo "$HOME/.copilot/skills";;
    esac
  else
    case "$1" in
      claude)   echo ".claude/skills";;
      windsurf) echo ".devin/skills";;
      copilot)  echo ".github/skills";;
      *)        echo ".agents/skills";;
    esac
  fi
}

wizard_wrap() {
  local text="$1" width="$2" part
  while [[ "${#text}" -gt "$width" ]]; do
    part="${text:0:$width}"
    [[ "$part" == *' '* && "$part" != ' '* ]] && part="${part% *}"
    printf '%s\n' "$part"
    text="${text:${#part}}"
    text="${text# }"
  done
  printf '%s\n' "$text"
}

wizard_restore_terminal() {
  local height width
  stty "$1" < /dev/tty
  IFS=' ' read -r height width < <(stty size < /dev/tty)
  printf '\033[0m\033[?25h\033[%d;1H\n' "$height" > /dev/tty
}

wizard_select_clients() {
  local i r c dir n key rest line cursor=-1 message="" tilde='~'
  local height width old_height=0 old_width=0 start=0 group=0 sticky available pos
  local output move prefix style wizard_tty_state resized
  local reset=$'\033[0m' bold=$'\033[1m' cyan=$'\033[1;36m' green=$'\033[1;32m' red=$'\033[31m'
  local dirs=() shared=() row_kinds=() row_values=() checked=() hints=() badges=() plugins=() labels=()
  local content=() owners=() first=() groups=() group_sizes=() client_starts=() client_ends=()
  local frame=() previous=()
  for i in "${!CLIENTS_ALL[@]}"; do
    dirs+=("$(skills_dir "${CLIENTS_ALL[$i]}")")
    labels+=("$(client_label "${CLIENTS_ALL[$i]}")")
    checked+=(0)
    badges+=("$(is_client_detected "${CLIENTS_ALL[$i]}" && printf ' [detected]' || true)")
    if has_plugin_install "${CLIENTS_ALL[$i]}"; then
      plugins+=(1)
      badges[$i]+=" [plugin installed]"
    else
      plugins+=(0)
    fi
  done
  for i in "${!dirs[@]}"; do
    n=0
    for dir in "${dirs[@]}"; do
      [[ "$dir" == "${dirs[$i]}" ]] && n=$((n + 1))
    done
    if [[ "$n" -gt 1 ]] && ! contains "${dirs[$i]}" "${shared[@]+"${shared[@]}"}"; then
      shared+=("${dirs[$i]}")
    fi
  done
  for dir in "${shared[@]+"${shared[@]}"}"; do
    row_kinds+=(h)
    row_values+=("── ${dir/#"$HOME"/$tilde} ── shared, installed together")
    for i in "${!dirs[@]}"; do
      [[ "${dirs[$i]}" == "$dir" ]] || continue
      row_kinds+=(c)
      row_values+=("$i")
    done
  done
  row_kinds+=(h)
  row_values+=("── Own directory ──")
  for i in "${!dirs[@]}"; do
    contains "${dirs[$i]}" "${shared[@]+"${shared[@]}"}" && continue
    row_kinds+=(c)
    row_values+=("$i")
  done
  for i in "${!dirs[@]}"; do
    if contains "${dirs[$i]}" "${shared[@]+"${shared[@]}"}"; then
      hints[$i]=""
    else
      hints[$i]=" (${dirs[$i]/#"$HOME"/$tilde})"
    fi
  done
  for r in "${!row_kinds[@]}"; do
    if [[ "${row_kinds[$r]}" == "c" ]]; then
      cursor="$r"
      break
    fi
  done

  wizard_tty_state="$(stty -g < /dev/tty)"
  trap 'wizard_restore_terminal "$wizard_tty_state"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  trap 'exit 129' HUP
  stty -echo < /dev/tty
  read -r height width < <(stty size < /dev/tty)
  output=$'\033[?25l'
  for ((r = 1; r < height; r++)); do output+=$'\n'; done
  printf '%s' "$output" > /dev/tty
  while true; do
    read -r height width < <(stty size < /dev/tty)
    width=$((width - 1))
    resized=0
    if [[ "$width" -ne "$old_width" || "$height" -ne "$old_height" ]]; then
      resized=1
      old_width="$width"
      old_height="$height"
      content=() owners=() first=() groups=() group_sizes=() client_starts=() client_ends=()
      start=0
      for r in "${!row_kinds[@]}"; do
        if [[ "${row_kinds[$r]}" == "h" ]]; then
          group="${#content[@]}"
          while IFS= read -r line; do
            content+=("$line") owners+=(-1) first+=(0) groups+=("$group")
          done < <(wizard_wrap "${row_values[$r]}" "$width")
          group_sizes[$group]=$((${#content[@]} - group))
        else
          i="${row_values[$r]}"
          client_starts[$i]="${#content[@]}"
          n=1
          while IFS= read -r line; do
            content+=("$line") owners+=("$i") first+=("$n") groups+=("$group")
            n=0
          done < <(wizard_wrap "${labels[$i]}${hints[$i]}${badges[$i]}" "$((width - 6))")
          client_ends[$i]=$((${#content[@]} - 1))
        fi
      done
    fi

    i="${row_values[$cursor]}"
    available=$((height - 6))
    [[ "$start" -gt "${client_starts[$i]}" ]] && start="${client_starts[$i]}"
    while true; do
      group="${groups[$start]}"
      sticky=0
      [[ "$group" -lt "$start" ]] && sticky="${group_sizes[$group]}"
      [[ "${client_ends[$i]}" -lt "$((start + available - sticky))" || "$start" -ge "${client_starts[$i]}" ]] && break
      start=$((start + 1))
      if [[ "${owners[$start]}" -eq -1 ]]; then
        group="${groups[$start]}"
        start=$((group + group_sizes[group]))
      fi
    done

    frame=()
    for ((r = 0; r < height; r++)); do frame+=(""); done
    frame[0]="${bold}sdd-flow · Installation${reset}"
    frame[1]="${bold}Select clients${reset}"
    pos=3
    for ((r = group; r < group + sticky; r++)); do
      frame[$pos]="${bold}${content[$r]}${reset}"
      pos=$((pos + 1))
    done
    for ((r = start; r < ${#content[@]} && pos < height - 3; r++)); do
      c="${owners[$r]}"
      if [[ "$c" -lt 0 ]]; then
        frame[$pos]="${bold}${content[$r]}${reset}"
      else
        prefix='      '
        if [[ "${first[$r]}" -eq 1 ]]; then
          prefix='  '
          [[ "$c" -eq "$i" ]] && prefix="${cyan}> ${reset}"
          if [[ "${checked[$c]}" -eq 1 ]]; then
            prefix+="${green}[x]${reset} "
          else
            prefix+="${bold}[ ]${reset} "
          fi
        fi
        style=""
        [[ "$c" -eq "$i" ]] && style="$bold"
        [[ "${plugins[$c]}" -eq 1 ]] && style+="$red"
        frame[$pos]="${prefix}${style}${content[$r]}${reset}"
      fi
      pos=$((pos + 1))
    done
    frame[$((height - 3))]="${bold}${message}${reset}"
    frame[$((height - 2))]="${cyan}[↑↓]${reset} Move   ${cyan}[Space]${reset} Select"
    frame[$((height - 1))]="${cyan}[Enter]${reset} Confirm"
    output=""
    for r in "${!frame[@]}"; do
      if [[ "$resized" -eq 1 || "${frame[$r]}" != "${previous[$r]-}" ]]; then
        printf -v move '\033[%d;1H' "$((r + 1))"
        output+="${move}${frame[$r]}${reset}"$'\033[K'
      fi
    done
    [[ -z "$output" ]] || printf '%s' "$output" > /dev/tty
    previous=("${frame[@]}")
    message=""
    IFS= read -rsn1 key < /dev/tty || exit 1
    case "$key" in
      $'\033')
        IFS= read -rsn2 rest < /dev/tty || true
        case "$rest" in
          '[A')
            for ((r = cursor - 1; r >= 0; r--)); do
              [[ "${row_kinds[$r]}" == "c" ]] && { cursor="$r"; break; }
            done;;
          '[B')
            for ((r = cursor + 1; r < ${#row_kinds[@]}; r++)); do
              [[ "${row_kinds[$r]}" == "c" ]] && { cursor="$r"; break; }
            done;;
        esac;;
      ' ')
        i="${row_values[$cursor]}"
        checked[$i]=$((1 - checked[$i]));;
      '')
        for i in "${!CLIENTS_ALL[@]}"; do
          [[ "${checked[$i]}" -eq 1 ]] && add_selected_client "${CLIENTS_ALL[$i]}"
        done
        if [[ "${#SELECTED_CLIENTS[@]}" -gt 0 ]]; then
          wizard_restore_terminal "$wizard_tty_state"
          trap - EXIT INT TERM HUP
          echo "Selected: ${SELECTED_CLIENTS[*]}" > /dev/tty
          return
        fi
        message="  select at least one client";;
    esac
  done
}

wizard_select_scope() {
  local choice abs_target height width line
  abs_target="$(cd "$TARGET" 2>/dev/null && pwd || echo "$TARGET")"
  read -r height width < <(stty size < /dev/tty)
  printf '\n\033[1msdd-flow · Installation\033[0m\n\033[1mSelect installation scope:\033[0m\n' > /dev/tty
  for line in '1) Global — user-level, available across all projects' "2) Local — project-level ($abs_target)"; do
    while IFS= read -r line; do
      printf '\033[1;36m%s\033[0m\n' "$line" > /dev/tty
    done < <(wizard_wrap "$line" "$((width - 1))")
  done
  printf '\n' > /dev/tty
  while true; do
    printf '\033[1mEnter scope [1=global, 2=local] (default: 1):\033[0m ' > /dev/tty
    read -r choice < /dev/tty || exit 1
    case "${choice:-1}" in
      1|g|global|Global|GLOBAL)
        GLOBAL=1
        break;;
      2|l|local|Local|LOCAL)
        GLOBAL=0
        LOCAL_FLAG=1
        break;;
      *)
        echo "  please enter 1 (global) or 2 (local)." > /dev/tty;;
    esac
  done
}

if [[ "$GLOBAL" -eq 0 && "$LOCAL_FLAG" -eq 0 && "$TARGET_SET" -eq 0 ]]; then
  if can_prompt; then
    wizard_select_scope
  fi
fi

if [[ "${#RAW_CLIENTS[@]}" -gt 0 ]]; then
  parse_raw_clients
else
  if can_prompt; then
    wizard_select_clients
  else
    echo "error: --client is required in non-interactive mode (one of: ${CLIENTS_ALL[*]} all)" >&2
    usage 1
  fi
fi

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

PLAN_SRC=()
PLAN_DEST=()
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

queue() {
  contains "$2" "${PLAN_DEST[@]+"${PLAN_DEST[@]}"}" && return 0
  PLAN_SRC+=("$1")
  PLAN_DEST+=("$2")
}

queue_skills() {
  local d
  for d in "$1"/skills/*/; do
    [[ -d "$d" ]] || continue
    queue "${d%/}" "$2/$(basename "$d")"
  done
}

queue_files() {
  local f
  for f in "$1"/*."$2"; do
    [[ -f "$f" ]] || continue
    queue "$f" "$3/$(basename "$f")"
  done
}

queue_opencode_agents() {
  local f base
  mkdir -p "$STAGE/opencode"
  for f in "$1"/agents/*.md; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    awk 'NR==1 && /^---[[:space:]]*$/ {print; print "mode: subagent"; next} {print}' "$f" > "$STAGE/opencode/$base"
    queue "$STAGE/opencode/$base" "$2/$base"
  done
}

queue_antigravity_agents() {
  local f base
  mkdir -p "$STAGE/antigravity"
  for f in "$1"/agents/*.md; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    awk 'NR==1 && /^---[[:space:]]*$/ {print; print "mainAgent: false"; next} {print}' "$f" > "$STAGE/antigravity/$base"
    queue "$STAGE/antigravity/$base" "$2/$base"
  done
}

queue_copilot_agents() {
  local f base
  for f in "$1"/agents/*.md; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f" .md)"
    queue "$f" "$2/$base.agent.md"
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

report_collisions() {
  local i dest conflicts=0
  for i in "${!PLAN_DEST[@]}"; do
    dest="${PLAN_DEST[$i]}"
    [[ -e "$dest" ]] || continue
    if owned "$dest" || same_content "${PLAN_SRC[$i]}" "$dest"; then
      continue
    fi
    [[ "$conflicts" -eq 0 ]] && echo "warning: replacing these paths, which differ from sdd-flow and were not installed by it:" >&2
    echo "  $dest" >&2
    conflicts=$((conflicts + 1))
  done
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

plan_project_client() {
  local src="$1" t="$2" client="$3"
  queue_skills "$src" "$t/$(skills_dir "$client")"
  case "$client" in
    claude)
      queue_files "$src/agents" md "$t/.claude/agents";;
    gemini)
      queue_files "$src/agents" md "$t/.gemini/agents";;
    codex)
      queue_files "$src/integrations/codex/agents" toml "$t/.codex/agents";;
    opencode)
      queue_opencode_agents "$src" "$t/.opencode/agents";;
    kilo)
      queue_opencode_agents "$src" "$t/.kilo/agents";;
    cursor)
      queue_files "$src/agents" md "$t/.cursor/agents";;
    windsurf)
      queue_files "$src/agents" md "$t/.devin/agents"
      queue "$src/integrations/windsurf/windsurfrules" "$t/.devin/rules/sdd.md"
      queue "$src/integrations/windsurf/windsurfrules" "$t/.windsurfrules";;
    antigravity)
      queue_antigravity_agents "$src" "$t/.agents/agents";;
    copilot)
      queue_copilot_agents "$src" "$t/.github/agents";;
    universal) ;;
  esac
}

plan_global_client() {
  local src="$1" client="$2"
  queue_skills "$src" "$(skills_dir "$client")"
  case "$client" in
    claude)
      queue_files "$src/agents" md "$(claude_home)/agents";;
    gemini)
      queue_files "$src/agents" md "$HOME/.gemini/agents";;
    codex)
      queue_files "$src/integrations/codex/agents" toml "$(codex_home)/agents";;
    opencode)
      queue_opencode_agents "$src" "$(config_home)/opencode/agents";;
    kilo)
      queue_opencode_agents "$src" "$(config_home)/kilo/agents";;
    cursor)
      queue_files "$src/agents" md "$HOME/.cursor/agents";;
    windsurf)
      queue_files "$src/agents" md "$(config_home)/devin/agents";;
    antigravity)
      queue_skills "$src" "$HOME/.gemini/antigravity-cli/skills"
      queue_antigravity_agents "$src" "$HOME/.gemini/config/agents";;
    copilot)
      queue_copilot_agents "$src" "$HOME/.copilot/agents";;
    universal) ;;
  esac
}

invoke_hint() {
  case "$1" in
    claude)      echo "  - [claude]      Run /sdd <feature> or /mini-sdd <change> in Claude Code.";;
    gemini)      echo "  - [gemini]      Run /sdd <feature> or ask Gemini CLI to load the 'sdd' skill.";;
    codex)       echo "  - [codex]       Type /skills or \$sdd to load the orchestrator; run /sdd <feature>.";;
    opencode)    echo "  - [opencode]    Say '/sdd <feature>' or '@sdd-developer ...'.";;
    kilo)        echo "  - [kilo]        Use the 'sdd' skill; say '/sdd <feature>'.";;
    cursor)      echo "  - [cursor]      Type /sdd or ask the agent to 'spec this'.";;
    windsurf)    echo "  - [windsurf]    Say '/sdd <feature>' or '/mini-sdd <change>' in Devin Desktop / Windsurf.";;
    antigravity) echo "  - [antigravity] Type /sdd <feature> or ask the agent to use the 'sdd' skill.";;
    copilot)     echo "  - [copilot]     Ask Copilot to run /sdd <feature> (ensure runSubagent is enabled).";;
    universal)   echo "  - [universal]   Skills-only install. sharp-me, sdd-plan, sdd-debug, sdd-implement, sdd-review, pr-creation,"
                 echo "                  writing-agents and writing-humans"
                 echo "                  work without role subagents; /sdd and /mini-sdd require them.";;
  esac
}

resolve_source
SRC="$(cd "$SRC" && pwd)"

[[ -d "$SRC/skills" && -d "$SRC/agents" ]] || { echo "error: source has no skills/ and agents/ ($SRC)" >&2; exit 1; }

CLIENT_LIST="${SELECTED_CLIENTS[*]}"

if [[ "$GLOBAL" -eq 1 ]]; then
  echo "Installing sdd-flow for: $CLIENT_LIST (global, user-level)"
  echo "  source: $SRC"
  for c in "${SELECTED_CLIENTS[@]}"; do
    plan_global_client "$SRC" "$c"
  done
  report_collisions
  apply_plan
  cat <<EOF

Done. sdd-flow is installed for: $CLIENT_LIST (global — applies to every project on this machine).

Before you start:
  - Every project you use sdd-flow in still needs its own AGENTS.md at the root
    (user-provided; SDD never creates it). Global install only skips re-copying
    skills/agents per project — it does not skip that precondition.
  - Every project must be a git repository with at least one commit. SDD's
    checker needs Python 3.11+ (python3). No remote or GitHub CLI is required.

Invoke:
EOF
  for c in "${SELECTED_CLIENTS[@]}"; do
    invoke_hint "$c"
  done
  echo ""
  echo "Re-run this command any time to refresh skills/agents."
else
  mkdir -p "$TARGET"
  TARGET="$(cd "$TARGET" && pwd)"
  echo "Installing sdd-flow for: $CLIENT_LIST (local project)"
  echo "  source: $SRC"
  echo "  target: $TARGET"
  for c in "${SELECTED_CLIENTS[@]}"; do
    plan_project_client "$SRC" "$TARGET" "$c"
  done
  report_collisions
  apply_plan
  cat <<EOF

Done. sdd-flow is installed for: $CLIENT_LIST.

Before you start:
  - Make sure your project has an AGENTS.md at the root (user-provided; SDD never creates it).
  - The project must be a git repository with at least one commit. SDD's
    checker needs Python 3.11+ (python3). No remote or GitHub CLI is required.

Invoke:
EOF
  for c in "${SELECTED_CLIENTS[@]}"; do
    invoke_hint "$c"
  done
  echo ""
  echo "Re-run this command any time to refresh skills/agents."
fi
