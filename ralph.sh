#!/usr/bin/env bash
# ralph.sh
# Usage: ./ralph.sh <iterations>

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <iterations>" >&2
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
3. Validate using available feedback loops (types, tests, build).
4. Append a concise entry to progress.txt describing:
   - Feature worked on
   - Files changed
   - Current status
5. If and ONLY IF the feature is fully complete:
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
  if ! claude -p --permission-mode acceptEdits "$PROMPT"; then
    echo "Error: claude execution failed" >&2
    exit 1
  fi

  # If we still have iterations left, ask the human whether to continue.
  if ((i < iterations)); then
    if ! confirm_continue; then
      exit 0
    fi
  fi
done
