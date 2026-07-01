#!/usr/bin/env bash
# generate-adapters.sh
#
# Regenerate per-client agent adapters from the canonical Claude-Code agent
# prompts in agents/*.md. Run this whenever agents/*.md changes, then commit
# the output so the installer can copy deterministic, pre-validated files.
#
# Currently produces:
#   - integrations/codex/agents/<name>.toml   (Codex custom-agent TOML)
#
# Kilo / Cursor / Opencode are NOT materialised here: their agent files are the
# canonical markdown (verbatim copy, or a one-line frontmatter injection done by
# the installer). Keeping a single source of truth in agents/*.md avoids drift.
#
# Usage:  scripts/generate-adapters.sh
# Exit:   non-zero on any failure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
AGENTS_DIR="$ROOT_DIR/agents"
CODEX_OUT="$ROOT_DIR/integrations/codex/agents"

if [[ ! -d "$AGENTS_DIR" ]]; then
  echo "error: agents/ not found at $AGENTS_DIR" >&2
  exit 1
fi

mkdir -p "$CODEX_OUT"

# Collapse a YAML folded-scalar description (description: >) into one line.
# Expects "description: >" to be the final frontmatter key before the closing ---.
fold_description() {
  local file="$1"
  sed -n '/^description: >$/,/^---$/p' "$file" \
    | sed '1d;$d' \
    | sed 's/^[[:space:]]*//' \
    | paste -sd ' ' \
    | sed 's/[[:space:]]\{2,\}/ /g; s/^[[:space:]]*//; s/[[:space:]]*$//'
}

emit_codex_toml() {
  local src="$1"
  local out="$2"
  local name desc body

  name="$(grep -m1 '^name:' "$src" | sed 's/^name:[[:space:]]*//; s/[[:space:]]*$//')"
  if [[ -z "$name" ]]; then
    echo "error: no name: in $src" >&2
    return 1
  fi

  desc="$(fold_description "$src")"
  # Escape backslashes and double-quotes for a TOML basic string.
  desc="${desc//\\/\\\\}"
  desc="${desc//\"/\\\"}"

  # Body = everything after the second --- (frontmatter close). Only the
  # first two standalone "---" lines are delimiters; any later ones (e.g. a
  # markdown horizontal rule in the body) must be kept as content.
  body="$(awk 'BEGIN{seen=0} seen<2 && /^---[[:space:]]*$/ {seen++; next} seen>=2 {print}' "$src")"

  {
    printf '# Auto-generated from %s by scripts/generate-adapters.sh.\n' "$(basename "$src")"
    printf '# Do not edit by hand; edit the source agent and re-run the generator.\n'
    printf '\n'
    printf 'name = "%s"\n' "$name"
    printf 'description = "%s"\n' "$desc"
    printf '\n'
    printf '# sdd-flow subagents are intentionally narrow; read-only is wrong for the\n'
    printf '# developer, so we leave sandbox_mode unset (inherits the session policy).\n'
    printf 'developer_instructions = """\n'
    printf '%s\n' "$body"
    printf '"""\n'
  } > "$out"
}

echo "Generating Codex agent adapters in $CODEX_OUT"
shopt -s nullglob
for src in "$AGENTS_DIR"/*.md; do
  base="$(basename "$src" .md)"
  out="$CODEX_OUT/$base.toml"
  emit_codex_toml "$src" "$out"
  echo "  - $(basename "$out")"
done

echo "Done. Review with: git diff -- integrations/codex/"
