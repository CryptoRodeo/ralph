#!/usr/bin/env bash
set -euo pipefail

# reverse_ralph.sh
#
# Default behavior:
#   - Reads ticket
#   - Builds a context bundle from repo files (docs/config + optional code + image paths)
#   - Stage 0: writes ticket_analysis.md (markdown)
#   - Stage 1: writes derived_plan.json (validated JSON plan)
#
# Examples:
#   ./reverse_ralph.sh --ticket-file TICKET.md
#   echo "..." | ./reverse_ralph.sh --ticket-stdin
#   ./reverse_ralph.sh --ticket "ABC-123: ..."
#
# Common knobs:
#   --out-dir .ralph
#   --context-dir .
#   --no-code
#   --regen

LLM_CMD="${LLM_CMD:-claude}"

# Defaults (override via env)
LLM_ARGS_STAGE0="${LLM_ARGS_STAGE0:---permission-mode plan --max-turns 8 --no-session-persistence}"
LLM_ARGS_STAGE1="${LLM_ARGS_STAGE1:---max-turns 12 --no-session-persistence}"

OUT_DIR="${OUT_DIR:-.ralph}"
CONTEXT_DIR="."
INCLUDE_CODE=1
REGEN=0

TICKET_FILE=""
TICKET_TEXT=""
TICKET_STDIN=0

# Context limits
MAX_TEXT_BYTES="${MAX_TEXT_BYTES:-120000}"
MAX_CODE_BYTES="${MAX_CODE_BYTES:-80000}"
MAX_FILES_DOCS="${MAX_FILES_DOCS:-45}"
MAX_FILES_CODE="${MAX_FILES_CODE:-25}"
MAX_FILES_IMAGES="${MAX_FILES_IMAGES:-25}"

EXCLUDE_DIRS=(
  ".git" "node_modules" "vendor" "dist" "build" "target" ".next" ".turbo" ".cache"
  "coverage" ".idea" ".vscode" ".pytest_cache" ".mypy_cache" ".venv" "venv" "__pycache__"
)

DOC_GLOBS=(
  "README*" "docs/**/*.md" "docs/**/*.mdx" "docs/**/*.adoc" "docs/**/*.rst" "docs/**/*.txt"
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
  --ticket-file <path>   Read ticket text from a file
  --ticket <string>      Ticket text (no network fetch)
  --ticket-stdin         Read ticket text from stdin

Options:
  --context-dir <dir>    Directory to scan for context files (default: .)
  --out-dir <dir>        Output state directory (default: .ralph)
  --no-code              Exclude code excerpts (docs/config/images only)
  --regen                Regenerate analysis + plan (keeps ticket/context)

Env overrides:
  LLM_CMD=claude
  LLM_ARGS_STAGE0="--permission-mode plan --max-turns 8 --no-session-persistence"
  LLM_ARGS_STAGE1="--max-turns 12 --no-session-persistence"
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}
trim() { awk '{$1=$1;print}'; }

is_excluded_path() {
  local rel="$1" ex
  for ex in "${EXCLUDE_DIRS[@]}"; do
    [[ "$rel" == "$ex/"* ]] && return 0
    [[ "$rel" == "$ex" ]] && return 0
  done

  local ignore_file="$CONTEXT_DIR/$RALPHIGNORE_NAME"
  if [[ -f "$ignore_file" ]]; then
    while IFS= read -r line; do
      line="$(printf "%s" "$line" | trim)"
      [[ -z "$line" || "$line" == \#* ]] && continue
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
    text/* | application/json | application/xml | application/x-yaml | application/yaml) return 0 ;;
    *) return 1 ;;
    esac
  fi
  grep -Iq . "$f" 2>/dev/null
}

is_image_like() {
  local f="$1" ext="${f##*.}"
  ext="${ext,,}"
  case "$ext" in png | jpg | jpeg | webp | gif | svg) return 0 ;; *) return 1 ;; esac
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
  local f="$1" max="$2" size
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

llm_print() {
  local prompt="$1" args="$2"
  # shellcheck disable=SC2086
  printf "%s" "$prompt" | "$LLM_CMD" -p $args
}

# Paths
TICKET_MD="$OUT_DIR/ticket.md"
CONTEXT_BUNDLE="$OUT_DIR/context.bundle.md"
TICKET_ANALYSIS_MD="$OUT_DIR/ticket_analysis.md"
DERIVED_PLAN_JSON="$OUT_DIR/derived_plan.json"

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
    [[ "${#doc_files[@]}" -eq 0 ]] && echo "_No doc/config files matched._" && echo
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
      echo "If you see lines like 'Analyze this image: <path>', open and interpret it as context."
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
      [[ "${#code_files[@]}" -eq 0 ]] && echo "_No code files matched (or all excluded)._"
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

validate_derived_plan_json() {
  local json="$1"
  command -v jq >/dev/null 2>&1 || return 0
  printf "%s" "$json" | jq -e '
    type=="object"
    and (.title|type=="string")
    and (.source|type=="string")
    and (.summary|type=="string")
    and (.assumptions|type=="array")
    and (.open_questions|type=="array")
    and (.risks|type=="array")
    and (.steps|type=="array")
    and (.steps|length>=1)
    and (all(.steps[]; (.id|type=="string") and (.title|type=="string") and (.details|type=="string")
        and (.acceptance_criteria|type=="array") and (.touched_areas|type=="array")))
  ' >/dev/null
}

stage0_ticket_analysis() {
  if [[ -f "$TICKET_ANALYSIS_MD" && "$REGEN" -ne 1 ]]; then
    return
  fi

  echo "Generating ticket_analysis.md ..."

  local prompt combined out
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

  combined="@${TICKET_MD} @${CONTEXT_BUNDLE}

${prompt}
"
  out="$(llm_print "$combined" "$LLM_ARGS_STAGE0")" || die "LLM failed generating ticket analysis"
  printf "%s\n" "$out" >"$TICKET_ANALYSIS_MD"
}

stage1_derive_plan() {
  if [[ -f "$DERIVED_PLAN_JSON" && "$REGEN" -ne 1 ]]; then
    return
  fi

  command -v jq >/dev/null 2>&1 || die "jq is required for Stage 1 (used to extract .structured_output)"

  echo "Generating derived_plan.json ..."

  local schema prompt combined wrapper plan

  schema='{
    "type":"object",
    "required":["title","source","summary","assumptions","open_questions","risks","steps"],
    "properties":{
      "title":{"type":"string"},
      "source":{"type":"string","enum":["jira","github","ticket"]},
      "summary":{"type":"string"},
      "assumptions":{"type":"array","items":{"type":"string"}},
      "open_questions":{"type":"array","items":{"type":"string"}},
      "risks":{"type":"array","items":{"type":"string"}},
      "steps":{
        "type":"array",
        "minItems":5,
        "maxItems":30,
        "items":{
          "type":"object",
          "required":["id","title","details","acceptance_criteria","touched_areas"],
          "properties":{
            "id":{"type":"string"},
            "title":{"type":"string"},
            "details":{"type":"string"},
            "acceptance_criteria":{"type":"array","items":{"type":"string"}},
            "touched_areas":{"type":"array","items":{"type":"string"}}
          }
        }
      }
    }
  }'

  prompt="$(
    cat <<'EOF'
You are operating in a STRICT "Reverse Ralph" planning phase.

Goal:
Derive a concrete implementation plan from the ticket and the ticket analysis.
This plan should be suitable to feed into an execution loop (one step at a time).

Inputs:
- ticket.md
- ticket_analysis.md
- context.bundle.md (repo excerpts + image paths)

Rules:
- Output MUST be valid JSON ONLY (no prose, no markdown fences).
- Steps must be ordered for incremental progress and early validation.
- Create 5 to 30 steps.
- Each step should be small enough to implement in < 1 day.
- Include acceptance criteria for each step.
- If unknowns remain, include early steps that resolve them (spikes, confirmations, API checks).
- Reference repo locations realistically; do not invent structure if existing structure is implied.

Return ONLY the JSON object.
EOF
  )"

  combined="@${TICKET_MD} @${TICKET_ANALYSIS_MD} @${CONTEXT_BUNDLE}

${prompt}
"

  # Always request JSON wrapper and extract structured_output with jq
  # shellcheck disable=SC2086
  wrapper="$(
    printf "%s" "$combined" | "$LLM_CMD" -p $LLM_ARGS_STAGE1 \
      --output-format json \
      --json-schema "$schema"
  )" || die "LLM failed deriving plan"

  # Extract the schema-validated object
  plan="$(printf "%s" "$wrapper" | jq -c '.structured_output // empty')" || true

  if [[ -z "$plan" || "$plan" == "null" ]]; then
    echo "Error: Stage 1 did not return structured_output." >&2
    echo "This usually means your claude CLI ignored --json-schema or returned an error wrapper." >&2
    echo "Debug: printing the top-level keys we received:" >&2
    printf "%s" "$wrapper" | jq -r 'keys[]?' >&2 || true
    exit 1
  fi

  # Validate
  if ! validate_derived_plan_json "$plan"; then
    echo "Error: structured_output was present but did not match expected plan shape." >&2
    echo "Tip: check schema/validator mismatch; dumping structured_output:" >&2
    printf "%s\n" "$plan" | jq . >&2 || true
    exit 1
  fi

  printf "%s\n" "$plan" | jq . >"$DERIVED_PLAN_JSON"
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
  --out-dir)
    OUT_DIR="${2:-}"
    shift 2
    ;;
  --no-code)
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
mkdir -p "$OUT_DIR"

main() {
  normalize_ticket
  write_context_bundle
  stage0_ticket_analysis
  stage1_derive_plan

  echo
  echo "Artifacts:"
  echo "  - $TICKET_MD"
  echo "  - $CONTEXT_BUNDLE"
  echo "  - $TICKET_ANALYSIS_MD"
  echo "  - $DERIVED_PLAN_JSON"
}

main
