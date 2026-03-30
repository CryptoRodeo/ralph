#!/usr/bin/env bash
# ralph.sh
# Usage: ./ralph.sh [--auto] [--no-retry] <iterations>

set -euo pipefail

AUTO=false
NO_RETRY=false

while [[ "${1:-}" == --* ]]; do
  case "$1" in
    --auto) AUTO=true; shift ;;
    --no-retry) NO_RETRY=true; shift ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 [--auto] [--no-retry] <iterations>" >&2
  exit 1
fi

iterations="$1"
if ! [[ "$iterations" =~ ^[0-9]+$ ]] || [[ "$iterations" -le 0 ]]; then
  echo "Error: iterations must be a positive integer" >&2
  exit 1
fi

# Optional: ensure we're in a repo with the expected files
if [[ ! -f prd.json || ! -f progress.txt ]]; then
  echo "Error: expected ./prd.json and ./progress.txt in the current directory." >&2
  exit 1
fi

PROMPT=$(
  cat <<'EOF'
@prd.json @progress.txt
You are operating in a STRICT Ralph Loop.

If you attempt to work on more than one feature, you have FAILED this task.

=== EXECUTION CONTRACT ===
You MUST:
- Select EXACTLY ONE feature from prd.json that is NOT marked completed
- Work ONLY on that single feature
- Make ONLY the minimal changes required to implement that feature
- Update progress.txt with what you did
- If the feature becomes complete, mark ONLY THAT feature as completed in prd.json
- STOP IMMEDIATELY after completing this feature

You MUST NOT:
- Start, partially implement, or plan any other feature
- Refactor, clean up, or improve unrelated code
- Add follow-up features, enhancements, or "while I'm here" changes
- Continue after the single feature is done

=== STEP-BY-STEP ===
1. Choose the single highest-priority incomplete feature from prd.json.
2. Implement ONLY that feature.
3. Run EVERY command in the feature's "validation" array from prd.json. Each command must exit 0.
4. If ANY validation command fails:
   - Do NOT mark the feature as completed in prd.json
   - Append a failure entry to progress.txt with the command that failed and its output
   - STOP - do not retry or continue
5. If ALL validation commands pass, append a concise entry to progress.txt describing:
   - Feature worked on
   - Files changed
   - Current status
6. If and ONLY IF the feature is fully complete AND all validation passed:
   - Mark it completed in prd.json

=== HARD STOP CONDITION ===
After step 4 (and step 5 if applicable):
- EXIT immediately.
- Do NOT continue reasoning, planning, or coding.
EOF
)

cleanup() {
  echo "" >&2
  echo "Exiting Ralph loop." >&2
}
trap cleanup EXIT
trap 'echo ""; echo "Interrupted."; exit 130' INT

confirm_continue() {
  local reply=""
  while true; do
    echo "" >&2
    echo "Iteration complete." >&2
    echo "Review prd.json/progress.txt and git diff." >&2
    read -r -p "Run next iteration? [y/N] " reply
    case "${reply}" in
    [yY] | [yY][eE][sS]) return 0 ;;
    "" | [nN] | [nN][oO]) return 1 ;;
    *) echo "Please answer y or n." >&2 ;;
    esac
  done
}

for ((i = 1; i <= iterations; i++)); do
  echo "=== Ralph iteration $i/$iterations ===" >&2

  # Run Claude
  claude_exit=0
  claude -p --permission-mode bypassPermissions "$PROMPT" || claude_exit=$?

  if [[ "$claude_exit" -ne 0 ]]; then
    echo "Error: claude execution failed (exit $claude_exit)" >&2
    exit 1
  fi

  # Check if the last progress.txt entry indicates a validation failure
  last_progress=$(tail -20 progress.txt 2>/dev/null || true)
  if echo "$last_progress" | grep -qi 'INCOMPLETE\|FAILED\|failure'; then
    if [[ "$NO_RETRY" == true ]]; then
      echo "Validation failure detected but --no-retry is set, skipping retry." >&2
    else
      echo "=== Validation failure detected, retrying with error context ===" >&2
      RETRY_PROMPT="$PROMPT

The previous attempt at this feature failed. Here is what went wrong:
$last_progress"

      retry_exit=0
      claude -p --permission-mode bypassPermissions "$RETRY_PROMPT" || retry_exit=$?

      if [[ "$retry_exit" -ne 0 ]]; then
        echo "Error: claude retry execution failed (exit $retry_exit)" >&2
        # Log retry failure and continue to next iteration instead of exiting
        echo "" >> progress.txt
        echo "Retry failed: claude exited with code $retry_exit" >> progress.txt
      fi
    fi
  fi

  # If we still have iterations left, ask the human whether to continue.
  if ((i < iterations)); then
    if [[ "$AUTO" == true ]]; then
      echo "Auto mode: continuing to next iteration..." >&2
    elif ! confirm_continue; then
      exit 0
    fi
  fi
done
