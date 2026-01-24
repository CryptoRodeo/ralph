#!/usr/bin/env bash
set -euo pipefail

# ralph_ticket_steps.sh
#
# Hardened Ralph-style loop for Claude Code (claude CLI).
# - Run from repo root (default context-dir = .)
# - Ingest a Jira/feature ticket (file / stdin / string)
# - Snapshot high-signal context (docs/design/config + selected code)
# - Include image paths for Claude to review (no base64 spam by default)
# - Generate plan.json once, then emit EXACTLY ONE next step per iteration
#
# Usage:
#   ./ralph_ticket_steps.sh --ticket-file TICKET.md
#   echo "Story..." | ./ralph_ticket_steps.sh --ticket-stdin
#   ./ralph_ticket_steps.sh --ticket "https://jira/browse/ABC-123"
#
# Options:
#   --context-dir <dir>    (default: .)
#   --iterations <n>       (default: 1)
#   --out-dir <dir>        (default: .ralph)
#   --include-code         Include code files in context snapshot (default: auto; see INCLUDE_CODE_DEFAULT)
#   --no-include-code      Exclude code files (docs-only) in context snapshot
#
# Claude CLI:
#   LLM_CMD=claude
#   LLM_ARGS='--permission-mode plan --max-turns 3 --no-session-persistence'
#
# Notes:
# - This script does NOT edit your repo; it only generates steps.
# - Use .ralphignore (optional) for custom excludes (one path prefix or glob-like prefix per line).
# - Excludes common junk dirs by default (node_modules, .git, dist, etc).
# - Keeps context sizes bounded (caps number of files and excerpt sizes).

# ----------------------------
# Configuration (defaults)
# ----------------------------
LLM_CMD="${LLM_CMD:-claude}"
LLM_ARGS="${LLM_ARGS:---permission-mode plan --max-turns 3 --no-session-persistence}"

OUT_DIR="${OUT_DIR:-.ralph}"
CONTEXT_DIR="."
ITERATIONS=1

TICKET_FILE=""
TICKET_TEXT=""
TICKET_STDIN=0

# Context collection knobs
MAX_TEXT_BYTES="${MAX_TEXT_BYTES:-120000}" # max bytes per text file excerpted
MAX_CODE_BYTES="${MAX_CODE_BYTES:-80000}"  # max bytes per code file excerpted
MAX_FILES_DOCS="${MAX_FILES_DOCS:-45}"     # cap doc/config files
MAX_FILES_CODE="${MAX_FILES_CODE:-25}"     # cap code files
MAX_FILES_IMAGES="${MAX_FILES_IMAGES:-25}" # cap images

# Default behavior: include some code only if docs/context are thin.
INCLUDE_CODE_DEFAULT=1
INCLUDE_CODE="$INCLUDE_CODE_DEFAULT"

# Default excludes when running at repo root
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

# High-signal docs/config globs
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

# Code globs (only included if INCLUDE_CODE=1)
CODE_GLOBS=(
  "src/**/*" "packages/**/*" "plugins/**/*"
  "*.ts" "*.tsx" "*.js" "*.jsx" "*.go" "*.py" "*.java" "*.kt" "*.rs" "*.c" "*.h" "*.cpp" "*.hpp" "*.sh"
)

# Images (design mocks, screenshots)
IMAGE_GLOBS=("*.png" "*.jpg" "*.jpeg" "*.webp" "*.gif" "*.svg")

# Ralph ignore file
RALPHIGNORE_NAME=".ralphignore"

# ----------------------------
# Helpers
# ----------------------------
usage() {
  cat <<'EOF'
Usage:
  ralph_ticket_steps.sh [options]

Ticket input (choose one):
  --ticket-file <path>   Read ticket/user story from a file
  --ticket <string>      Ticket text or Jira URL (treated as text; no network fetch)
  --ticket-stdin         Read ticket text from stdin

Options:
  --context-dir <dir>    Directory to scan for context files (default: .)
  --iterations <n>       How many steps to emit this run (default: 1)
  --out-dir <dir>        Output state directory (default: .ralph)
  --include-code         Force include code excerpts in context snapshot
  --no-include-code      Force docs-only context snapshot
  -h, --help             Show help

Env:
  LLM_CMD=claude
  LLM_ARGS='--permission-mode plan --max-turns 3 --no-session-persistence'

Notes:
  - Creates: .ralph/ticket.md, context.bundle.md, plan.json, state.json, progress.md
  - Uses .ralphignore (optional) in context dir to exclude paths by prefix (one per line)
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

trim() { awk '{$1=$1;print}'; }

# Prefix-based exclude check (fast and predictable)
is_excluded_path() {
  local rel="$1" # relative path from CONTEXT_DIR
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
  # Collect unique, sorted matches for a set of globs, respecting excludes, up to cap.
  # Output: NUL-delimited absolute paths.
  local cap="$1"
  shift
  local -a globs=("$@")

  local -a results=()
  local rel abs

  (
    shopt -s nullglob globstar
    cd "$CONTEXT_DIR"

    # We deliberately iterate globs in order to prioritize signal.
    for g in "${globs[@]}"; do
      for rel in $g; do
        # Normalize rel; skip dirs
        [[ -d "$rel" ]] && continue
        is_excluded_path "$rel" && continue
        abs="$CONTEXT_DIR/$rel"
        results+=("$abs")
        [[ "${#results[@]}" -ge "$cap" ]] && break 2
      done
    done

    # Print unique (preserve order as much as possible)
    # Use awk with RS to handle NUL safely would be overkill; we expect manageable sizes.
    # We'll do a simple uniqueness pass here:
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

normalize_ticket() {
  local ticket_md="$OUT_DIR/ticket.md"

  if [[ -n "$TICKET_FILE" ]]; then
    [[ -f "$TICKET_FILE" ]] || die "Ticket file not found: $TICKET_FILE"
    cat "$TICKET_FILE" >"$ticket_md"
    return
  fi

  if [[ "$TICKET_STDIN" -eq 1 ]]; then
    cat >"$ticket_md"
    return
  fi

  if [[ -n "$TICKET_TEXT" ]]; then
    printf "%s\n" "$TICKET_TEXT" >"$ticket_md"
    return
  fi

  die "Provide one of: --ticket-file, --ticket, --ticket-stdin"
}

llm() {
  # Claude Code CLI: use print mode for scripting. Read prompt via stdin.
  local prompt="$1"
  # shellcheck disable=SC2086
  printf "%s" "$prompt" | "$LLM_CMD" -p $LLM_ARGS
}

# ----------------------------
# State files
# ----------------------------
TICKET_MD="$OUT_DIR/ticket.md"
CONTEXT_BUNDLE="$OUT_DIR/context.bundle.md"
PLAN_JSON="$OUT_DIR/plan.json"
STATE_JSON="$OUT_DIR/state.json"
PROGRESS_MD="$OUT_DIR/progress.md"

write_context_bundle() {
  : >"$CONTEXT_BUNDLE"

  {
    echo "# Context Bundle"
    echo
    echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "Repo/context dir: $CONTEXT_DIR"
    if [[ -f "$CONTEXT_DIR/$RALPHIGNORE_NAME" ]]; then
      echo "Using ignore file: $CONTEXT_DIR/$RALPHIGNORE_NAME"
    fi
    echo
    echo "## Ticket"
    echo
    echo '```'
    safe_excerpt "$TICKET_MD" 40000
    echo '```'
    echo
  } >>"$CONTEXT_BUNDLE"

  # Docs/config (high-signal)
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

  # Images (paths + metadata for Claude to open)
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
    if command -v file >/dev/null 2>&1; then
      mime="$(file --mime-type -b "$f" || true)"
    fi
    {
      echo "### $f"
      echo "- mime: $mime"
      echo "- bytes: $size"
      echo "- Analyze this image: $f"
      echo
    } >>"$CONTEXT_BUNDLE"
  done

  # Code excerpts (optional / gated)
  if [[ "$INCLUDE_CODE" -eq 1 ]]; then
    local -a code_files=()
    while IFS= read -r -d '' f; do
      # Only include text-like code files
      is_text_like "$f" && code_files+=("$f")
    done < <(collect_matches "$MAX_FILES_CODE" "${CODE_GLOBS[@]}")

    {
      echo "## Code Context (selected excerpts)"
      echo
      if [[ "${#code_files[@]}" -eq 0 ]]; then
        echo "_No code files matched (or all excluded)._"
        echo
      else
        echo "These are representative excerpts to orient implementation. Prefer inspecting repo directly for full context."
        echo
      fi
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

ensure_plan() {
  if [[ -f "$PLAN_JSON" ]]; then
    return
  fi

  local prompt
  prompt="$(
    cat <<'EOF'
You are operating in a STRICT "Ralph Planning Loop".

You are at the ROOT of a software repository.
Assume relative paths are from repository root.
Prefer referencing existing files/folders over inventing new structure.

Goal:
Turn the ticket + context into an ordered implementation plan.

Rules:
- Output MUST be valid JSON ONLY. No prose, no markdown fences.
- Create a plan of 5 to 30 steps.
- Each step MUST be concrete, testable, and small enough to do in < 1 day.
- Steps should be ordered for incremental progress and early validation.
- Include clear acceptance criteria per step.
- If information is missing, include steps that explicitly clarify what to ask / where to check.

You are given a context bundle that may contain:
- Excerpts from docs/config files
- Image paths with lines like 'Analyze this image: <path>' (you should open and interpret them)

Schema:
{
  "title": string,
  "summary": string,
  "assumptions": string[],
  "risks": string[],
  "steps": [
    {
      "id": "S1" | "S2" | ...,
      "title": string,
      "details": string,
      "acceptance_criteria": string[],
      "touched_areas": string[]   // files/folders/components likely involved (best guess)
    }
  ]
}

Now produce the plan JSON.
EOF
  )"

  local combined
  combined="@${TICKET_MD} @${CONTEXT_BUNDLE}

${prompt}
"

  echo "Generating plan.json ..."
  # Force JSON output at the CLI level too (best-effort). If unsupported, Claude will still follow the prompt.
  # shellcheck disable=SC2086
  local out
  out="$(printf "%s" "$combined" | "$LLM_CMD" -p $LLM_ARGS --output-format json)" ||
    die "LLM failed generating plan"
  printf "%s\n" "$out" >"$PLAN_JSON"

  cat >"$STATE_JSON" <<EOF
{"next_index":0}
EOF
  : >"$PROGRESS_MD"
}

json_get_next_index() {
  local v
  v="$(tr -d '\n\r\t ' <"$STATE_JSON" | sed -n 's/^{"next_index":\([0-9][0-9]*\)}$/\1/p')"
  [[ -n "$v" ]] || die "state.json is invalid"
  printf "%s" "$v"
}

json_set_next_index() {
  local n="$1"
  cat >"$STATE_JSON" <<EOF
{"next_index":$n}
EOF
}

count_steps() {
  # Count '"id": "' occurrences; assumes schema is followed.
  grep -o '"id"[[:space:]]*:[[:space:]]*"' "$PLAN_JSON" | wc -l | tr -d ' '
}

extract_step_json_by_index() {
  # Extract the Nth step object (0-based) from plan.json using a lightweight awk state machine.
  local idx="$1"
  awk -v target="$idx" '
    BEGIN { inSteps=0; depth=0; cur=-1; buf=""; }
    /"steps"[[:space:]]*:[[:space:]]*\[/ { inSteps=1 }
    {
      if (!inSteps) next;

      if ($0 ~ /{[[:space:]]*$/) {
        if (depth==0) { cur++; buf=""; }
        depth++;
      }

      if (depth>0) { buf = buf $0 "\n"; }

      if ($0 ~ /}[[:space:]]*,?[[:space:]]*$/ && depth>0) {
        depth--;
        if (depth==0 && cur==target) {
          print buf;
          exit 0;
        }
      }
    }
  ' "$PLAN_JSON"
}

emit_next_step() {
  local next total
  next="$(json_get_next_index)"
  total="$(count_steps)"

  if [[ "$next" -ge "$total" ]]; then
    echo "All steps already emitted. (next_index=$next total=$total)"
    return 0
  fi

  local step_json
  step_json="$(extract_step_json_by_index "$next")"
  [[ -n "$step_json" ]] || die "Failed to extract step index $next"

  local prompt
  prompt="$(
    cat <<'EOF'
You are operating in a STRICT Ralph Step Emitter.

You will be given:
- plan.json (the full plan)
- progress.md (steps already emitted)
- one specific step object (JSON fragment)

Task:
- Produce EXACTLY ONE "Next Step" output in MARKDOWN.
- Expand ONLY the given step into an executable checklist.
- Include sections:
  - Objective
  - Rationale
  - Checklist (bulleted; keep items small)
  - Files/areas to inspect or likely modify
  - Done when (acceptance criteria, in your words)
  - Questions to answer (ONLY if the step requires missing info)

Constraints:
- DO NOT include any other steps.
- DO NOT revise the overall plan.
- Keep it focused: one step only.

Output must be markdown only.
EOF
  )"

  local combined
  combined="@${PLAN_JSON} @${PROGRESS_MD}

# Step JSON (the ONLY step to expand)
${step_json}

${prompt}
"

  echo "Emitting step $((next + 1))/$total ..."
  local out
  out="$(llm "$combined")" || die "LLM failed emitting step"

  {
    echo "----"
    echo "## Step $((next + 1))"
    echo
    printf "%s\n" "$out"
    echo
  } >>"$PROGRESS_MD"

  json_set_next_index "$((next + 1))"

  echo
  echo "Wrote: $PROGRESS_MD"
  echo "Updated: $STATE_JSON"
}

# ----------------------------
# CLI args
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

# Auto-gate code inclusion: if docs are sparse, keep INCLUDE_CODE=1; else still allow it but bounded.
# (We keep it simple: if you explicitly set --no-include-code, it stays off.)
if [[ "$INCLUDE_CODE" -eq 1 && "$INCLUDE_CODE_DEFAULT" -eq 1 ]]; then
  : # already on
fi

main() {
  normalize_ticket
  write_context_bundle
  ensure_plan

  local i=0
  while [[ "$i" -lt "$ITERATIONS" ]]; do
    emit_next_step
    i=$((i + 1))
  done

  echo
  echo "Artifacts:"
  echo "  - $TICKET_MD"
  echo "  - $CONTEXT_BUNDLE"
  echo "  - $PLAN_JSON"
  echo "  - $STATE_JSON"
  echo "  - $PROGRESS_MD"
}

main
