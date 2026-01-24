#!/usr/bin/env bash
set -euo pipefail

# reverse_ralph.sh
#
# Reverse Ralph (ticket-first) for deriving an implementation plan from:
# - Jira ticket / GitHub issue text
# - repo context (docs/configs/images; optional code excerpts)
#
# Design goals:
# - Runs from repo root (default --context-dir .)
# - Stateless Claude calls (claude -p + --no-session-persistence recommended)
# - File-based state (no hidden model memory)
# - Two-stage state machine:
#     Stage 0: produce ticket_analysis.md
#     Stage 1: produce derived_plan.json
#     Stage 2: done
#
# Usage:
#   ./reverse_ralph.sh --ticket-file TICKET.md
#   echo "..." | ./reverse_ralph.sh --ticket-stdin
#   ./reverse_ralph.sh --ticket "ABC-123: ..."
#
# Options:
#   --context-dir <dir>    (default: .)
#   --iterations <n>       (default: 1) advance stages per run
#   --out-dir <dir>        (default: .ralph)
#   --include-code         Include code excerpts in context bundle
#   --no-include-code      Docs/config/images only
#   --regen                Regenerate outputs for current+future stages (keeps ticket/context)
#
# Claude:
#   LLM_CMD=claude
#   LLM_ARGS="--permission-mode plan --max-turns 3 --no-session-persistence"

LLM_CMD="${LLM_CMD:-claude}"
LLM_ARGS="${LLM_ARGS:---permission-mode plan --max-turns 3 --no-session-persistence}"

OUT_DIR="${OUT_DIR:-.ralph}"
CONTEXT_DIR="."
ITERATIONS=1

TICKET_FILE=""
TICKET_TEXT=""
TICKET_STDIN=0

REGEN=0

# Context limits
MAX_TEXT_BYTES="${MAX_TEXT_BYTES:-120000}"
MAX_CODE_BYTES="${MAX_CODE_BYTES:-80000}"
MAX_FILES_DOCS="${MAX_FILES_DOCS:-45}"
MAX_FILES_CODE="${MAX_FILES_CODE:-25}"
MAX_FILES_IMAGES="${MAX_FILES_IMAGES:-25}"

INCLUDE_CODE_DEFAULT=1
INCLUDE_CODE="$INCLUDE_CODE_DEFAULT"

EXCLUDE_DIRS=(
  ".git"
  "node_modules"
  "vendor"
  "dist"
  "build"
  "target"
  ".next"
  ".turbo"
  ".cache"
  "coverage"
  ".idea"
  ".vscode"
  ".pytest_cache"
  ".mypy_cache"
  ".venv"
  "venv"
  "__pycache__"
)

DOC_GLOBS=(
  "README*"
  "docs/**/*.md" "docs/**/*.mdx" "docs/**/*.adoc" "docs/**/*.rst" "docs/**/*.txt"
  "design/**/*.md" "design/**/*.mdx" "design/**/*.adoc" "design/**/*.rst" "design/**/*.txt"
  "adr/**/*.md" "adrs/**/*.md" "docs/adrs/**/*.md"
  "*.md" "*.mdx" "*.adoc" "*.rst" "*.txt"
  "CHANGELOG*" "CONTRIBUTING*"
  "package.json" "tsconfig*.json" "pnpm-workspace.yaml" "lerna.json" "turbo.json"
  "Cargo.toml" "go.mod" "go.work" "pyproject.toml" "requirements*.txt"
  "*.yaml" "*.yml" "*.json" "*.toml" "*.ini" "*.env" ".env*"
)

CODE_GLOBS=(
  "src/**/*" "packages/**/*" "plugins/**/*"
  "*.ts" "*.tsx" "*.js" "*.jsx" "*.go" "*.py" "*.java" "*.kt" "*.rs" "*.c" "*.h" "*.cpp" "*.hpp" "*.sh"
)

IMAGE_GLOBS=("*.png" "*.jpg" "*.jpeg" "*.webp" "*.gif" "*.svg")
RALPHIGNORE_NAME=".ralphignore"

usage() {
  cat <<'EOF'
Usage:
  reverse_ralph.sh [options]

Ticket input (choose one):
  --ticket-file <path>   Read ticket/user story from a file
  --ticket <string>      Ticket text or URL (treated as text; no network fetch)
  --ticket-stdin         Read ticket text from stdin

Options:
  --context-dir <dir>    Directory to scan for context files (default: .)
  --iterations <n>       How many stage-advances to run (default: 1)
  --out-dir <dir>        Output state directory (default: .ralph)
  --include-code         Force include code excerpts in context bundle
  --no-include-code      Force docs-only context bundle
  --regen                Regenerate outputs for current+future stages

Outputs (in out-dir):
  ticket.md
  context.bundle.md
  ticket_analysis.md
  derived_plan.json
  reverse_state.json

EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}
trim() { awk '{$1=$1;print}'; }

is_excluded_path() {
  local rel="$1"
  local ex

  for ex in "${EXCLUDE_DIRS[@]}"; do
    [[ "$rel" == "$ex/"* ]] && return 0
    [[ "$rel" == "$ex" ]] && return 0
  done

  local ignore_file="$CONTEXT_DIR/$RALPHIGNORE_NAME"
  if [[ -f "$ignore_file" ]]; then
    while IFS= read -r line; do
      line="$(printf "%s" "$line" | trim)"
      [[ -z "$line" ]] && continue
      [[ "$line" == \#* ]] && continue
      [[ "$rel" == "$line"* ]] && return 0
    done <"$ignore_file"
  fi

  return 1
}

is_text_like() {
  local f="$1"
  if command -v file >/dev/null 2>&1; then
    local mime
    mime="$(file --mime-type -b "$f" || true)"
    case "$mime" in
    text/*) return 0 ;;
    application/json | application/xml) return 0 ;;
    application/x-yaml | application/yaml) return 0 ;;
    esac
    return 1
  fi
  grep -Iq . "$f" 2>/dev/null
}

is_image_like() {
  local f="$1"
  local ext="${f##*.}"
  ext="${ext,,}"
  case "$ext" in
  png | jpg | jpeg | webp | gif | svg) return 0 ;;
  *) return 1 ;;
  esac
}

collect_matches() {
  local cap="$1"
  shift
  local -a globs=("$@")

  (
    shopt -s nullglob globstar
    cd "$CONTEXT_DIR"

    local -a results=()
    local rel abs
    for g in "${globs[@]}"; do
      for rel in $g; do
        [[ -d "$rel" ]] && continue
        is_excluded_path "$rel" && continue
        abs="$CONTEXT_DIR/$rel"
        results+=("$abs")
        [[ "${#results[@]}" -ge "$cap" ]] && break 2
      done
    done

    declare -A seen=()
    for abs in "${results[@]}"; do
      if [[ -z "${seen[$abs]+x}" ]]; then
        seen["$abs"]=1
        printf '%s\0' "$abs"
      fi
    done
  )
}

file_bytes() { wc -c <"$1" | tr -d ' '; }

safe_excerpt() {
  local f="$1"
  local max="$2"
  local size
  size="$(file_bytes "$f")"
  if [[ "$size" -le "$max" ]]; then
    cat "$f"
  else
    head -c "$max" "$f"
    echo
    echo
    echo "[...truncated to ${max} bytes...]"
  fi
}

llm() {
  local prompt="$1"
  # shellcheck disable=SC2086
  printf "%s" "$prompt" | "$LLM_CMD" -p $LLM_ARGS
}

# Paths
TICKET_MD="$OUT_DIR/ticket.md"
CONTEXT_BUNDLE="$OUT_DIR/context.bundle.md"
TICKET_ANALYSIS_MD="$OUT_DIR/ticket_analysis.md"
DERIVED_PLAN_JSON="$OUT_DIR/derived_plan.json"
STATE_JSON="$OUT_DIR/reverse_state.json"

normalize_ticket() {
  if [[ -n "$TICKET_FILE" ]]; then
    [[ -f "$TICKET_FILE" ]] || die "Ticket file not found: $TICKET_FILE"
    cat "$TICKET_FILE" >"$TICKET_MD"
    return
  fi
  if [[ "$TICKET_STDIN" -eq 1 ]]; then
    cat >"$TICKET_MD"
    return
  fi
  if [[ -n "$TICKET_TEXT" ]]; then
    printf "%s\n" "$TICKET_TEXT" >"$TICKET_MD"
    return
  fi
  die "Provide one of: --ticket-file, --ticket, --ticket-stdin"
}

write_context_bundle() {
  : >"$CONTEXT_BUNDLE"

  {
    echo "# Context Bundle (Reverse Ralph)"
    echo
    echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "Repo/context dir: $CONTEXT_DIR"
    [[ -f "$CONTEXT_DIR/$RALPHIGNORE_NAME" ]] && echo "Using ignore file: $CONTEXT_DIR/$RALPHIGNORE_NAME"
    echo
    echo "## Ticket"
    echo
    echo '```'
    safe_excerpt "$TICKET_MD" 40000
    echo '```'
    echo
  } >>"$CONTEXT_BUNDLE"

  local -a doc_files=()
  while IFS= read -r -d '' f; do
    is_text_like "$f" && doc_files+=("$f")
  done < <(collect_matches "$MAX_FILES_DOCS" "${DOC_GLOBS[@]}")

  {
    echo "## Docs & Config Context (excerpts)"
    echo
    if [[ "${#doc_files[@]}" -eq 0 ]]; then
      echo "_No doc/config files matched._"
      echo
    fi
  } >>"$CONTEXT_BUNDLE"

  local f size
  for f in "${doc_files[@]}"; do
    size="$(file_bytes "$f")"
    {
      echo "### $f"
      echo "- bytes: $size"
      echo
      echo '```'
      safe_excerpt "$f" "$MAX_TEXT_BYTES"
      echo '```'
      echo
    } >>"$CONTEXT_BUNDLE"
  done

  local -a images=()
  while IFS= read -r -d '' f; do
    is_image_like "$f" && images+=("$f")
  done < <(collect_matches "$MAX_FILES_IMAGES" "${IMAGE_GLOBS[@]}")

  {
    echo "## Images (paths + metadata)"
    echo
    if [[ "${#images[@]}" -eq 0 ]]; then
      echo "_No images matched._"
      echo
    else
      echo "If you see lines like 'Analyze this image: <path>', you should open and interpret the image as context."
      echo
    fi
  } >>"$CONTEXT_BUNDLE"

  local mime
  for f in "${images[@]}"; do
    size="$(file_bytes "$f")"
    mime="unknown"
    command -v file >/dev/null 2>&1 && mime="$(file --mime-type -b "$f" || true)"
    {
      echo "### $f"
      echo "- mime: $mime"
      echo "- bytes: $size"
      echo "- Analyze this image: $f"
      echo
    } >>"$CONTEXT_BUNDLE"
  done

  if [[ "$INCLUDE_CODE" -eq 1 ]]; then
    local -a code_files=()
    while IFS= read -r -d '' f; do
      is_text_like "$f" && code_files+=("$f")
    done < <(collect_matches "$MAX_FILES_CODE" "${CODE_GLOBS[@]}")

    {
      echo "## Code Context (selected excerpts)"
      echo
      if [[ "${#code_files[@]}" -eq 0 ]]; then
        echo "_No code files matched (or all excluded)._"
        echo
      else
        echo "Representative excerpts only. Prefer inspecting repo directly for complete context."
        echo
      fi
      echo
    } >>"$CONTEXT_BUNDLE"

    for f in "${code_files[@]}"; do
      size="$(file_bytes "$f")"
      {
        echo "### $f"
        echo "- bytes: $size"
        echo
        echo '```'
        safe_excerpt "$f" "$MAX_CODE_BYTES"
        echo '```'
        echo
      } >>"$CONTEXT_BUNDLE"
    done
  else
    {
      echo "## Code Context"
      echo
      echo "_Code excerpts disabled (docs-only mode)._"
      echo
    } >>"$CONTEXT_BUNDLE"
  fi
}

state_get_stage() {
  if [[ ! -f "$STATE_JSON" ]]; then
    echo "0"
    return
  fi
  local v
  v="$(tr -d '\n\r\t ' <"$STATE_JSON" | sed -n 's/^{"stage":\([0-9][0-9]*\)}$/\1/p')"
  [[ -n "$v" ]] || die "reverse_state.json is invalid"
  echo "$v"
}

state_set_stage() {
  local s="$1"
  cat >"$STATE_JSON" <<EOF
{"stage":$s}
EOF
}

regen_if_requested() {
  if [[ "$REGEN" -eq 1 ]]; then
    rm -f "$TICKET_ANALYSIS_MD" "$DERIVED_PLAN_JSON"
    # Keep state but rewind to stage 0 so it re-derives everything deterministically
    state_set_stage 0
  fi
}

stage0_ticket_analysis() {
  if [[ -f "$TICKET_ANALYSIS_MD" ]]; then
    return
  fi

  echo "Generating ticket_analysis.md ..."

  local prompt
  prompt="$(
    cat <<'EOF'
You are operating in a STRICT "Reverse Ralph" ticket analysis phase.

You are at the ROOT of a software repository.
Your job is to turn a Jira ticket / GitHub issue into a clear, implementation-oriented understanding.

You will be given:
- ticket.md (the raw ticket text)
- context.bundle.md (repo context excerpts + image paths you can open)

Rules:
- Output MUST be markdown only.
- Do NOT write an implementation plan yet. Focus on reconstructing intent and requirements.
- Be explicit about unknowns; do not assume details not supported by the inputs.
- If the ticket references UI/behavior and images exist, open them and incorporate findings.

Create a document with these sections:

# Ticket Analysis
## Problem statement (1-3 paragraphs)
## In-scope (bullets)
## Out-of-scope (bullets)
## Requirements (bullets, testable)
## Acceptance criteria (bullets, testable)
## Assumptions (bullets)
## Constraints (bullets: security, performance, compatibility, UX, API)
## Risks (bullets)
## Open questions (bullets, prioritized)
## Suggested repo touchpoints (bullets: folders/files/components to inspect)

Keep it concise and actionable.
EOF
  )"

  local combined="@${TICKET_MD} @${CONTEXT_BUNDLE}

${prompt}
"

  local out
  out="$(llm "$combined")" || die "LLM failed generating ticket analysis"
  printf "%s\n" "$out" >"$TICKET_ANALYSIS_MD"
}

stage1_derive_plan() {
  if [[ -f "$DERIVED_PLAN_JSON" ]]; then
    return
  fi

  echo "Generating derived_plan.json ..."

  local prompt
  prompt="$(
    cat <<'EOF'
You are operating in a STRICT "Reverse Ralph" planning phase.

Goal:
Derive a concrete implementation plan from the ticket and the ticket analysis.
This plan should be suitable to feed into an execution loop (one step at a time).

You will be given:
- ticket.md
- ticket_analysis.md
- context.bundle.md (repo excerpts + image paths)

Rules:
- Output MUST be valid JSON ONLY. No prose, no markdown fences.
- Steps must be ordered for incremental progress and early validation.
- Create 5 to 30 steps.
- Each step should be small enough to implement in < 1 day.
- Include acceptance criteria for each step.
- If unknowns remain, include early steps that resolve them (spikes, confirmations, API checks).
- Reference repo locations realistically; do not invent structure if existing structure is implied.

Schema:
{
  "title": string,
  "source": "jira" | "github" | "ticket",
  "summary": string,
  "assumptions": string[],
  "open_questions": string[],
  "risks": string[],
  "steps": [
    {
      "id": "S1" | "S2" | ...,
      "title": string,
      "details": string,
      "acceptance_criteria": string[],
      "touched_areas": string[]
    }
  ]
}
EOF
  )"

  local combined="@${TICKET_MD} @${TICKET_ANALYSIS_MD} @${CONTEXT_BUNDLE}

${prompt}
"

  # Prefer JSON output mode if supported (harmless if ignored by CLI).
  # shellcheck disable=SC2086
  local out
  out="$(printf "%s" "$combined" | "$LLM_CMD" -p $LLM_ARGS --output-format json)" ||
    die "LLM failed deriving plan"
  printf "%s\n" "$out" >"$DERIVED_PLAN_JSON"
}

advance_once() {
  local stage
  stage="$(state_get_stage)"

  case "$stage" in
  0)
    stage0_ticket_analysis
    state_set_stage 1
    ;;
  1)
    stage1_derive_plan
    state_set_stage 2
    ;;
  *)
    echo "Reverse Ralph is complete (stage=$stage)."
    echo "Outputs:"
    echo "  - $TICKET_ANALYSIS_MD"
    echo "  - $DERIVED_PLAN_JSON"
    ;;
  esac
}

# ----------------------------
# Parse args
# ----------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
  --ticket-file)
    TICKET_FILE="${2:-}"
    shift 2
    ;;
  --ticket)
    TICKET_TEXT="${2:-}"
    shift 2
    ;;
  --ticket-stdin)
    TICKET_STDIN=1
    shift
    ;;
  --context-dir)
    CONTEXT_DIR="${2:-}"
    shift 2
    ;;
  --iterations)
    ITERATIONS="${2:-}"
    shift 2
    ;;
  --out-dir)
    OUT_DIR="${2:-}"
    shift 2
    ;;
  --include-code)
    INCLUDE_CODE=1
    shift
    ;;
  --no-include-code)
    INCLUDE_CODE=0
    shift
    ;;
  --regen)
    REGEN=1
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *) die "Unknown arg: $1" ;;
  esac
done

[[ -d "$CONTEXT_DIR" ]] || die "--context-dir does not exist: $CONTEXT_DIR"
[[ "$ITERATIONS" =~ ^[0-9]+$ ]] || die "--iterations must be an integer"

mkdir -p "$OUT_DIR"

main() {
  normalize_ticket
  write_context_bundle
  regen_if_requested

  local i=0
  while [[ "$i" -lt "$ITERATIONS" ]]; do
    advance_once
    i=$((i + 1))
  done

  echo
  echo "Artifacts:"
  echo "  - $TICKET_MD"
  echo "  - $CONTEXT_BUNDLE"
  [[ -f "$TICKET_ANALYSIS_MD" ]] && echo "  - $TICKET_ANALYSIS_MD"
  [[ -f "$DERIVED_PLAN_JSON" ]] && echo "  - $DERIVED_PLAN_JSON"
  echo "  - $STATE_JSON"
}

main
