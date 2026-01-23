#!/usr/bin/env bash
set -euo pipefail

# If we are NOT running from a file, write ourselves to a temp file and re-run
if [[ "${BASH_SOURCE[0]}" == "bash" || ! -f "${BASH_SOURCE[0]}" ]]; then
  TMP="$(mktemp /tmp/ralph_init.XXXXXX.sh)"
  cat >"$TMP"
  chmod +x "$TMP"
  exec bash "$TMP"
fi

SCRIPT_PATH="$(realpath "$0")"
trap 'rm -f "$SCRIPT_PATH"' EXIT

echo "🚀 Initializing Ralph..."

# Download ralph.sh from GitHub (fail on HTTP errors)
curl -fsSL -o "ralph.sh" "https://raw.githubusercontent.com/CryptoRodeo/ralph/refs/heads/main/ralph.sh"

# Make ralph.sh executable
chmod +x "ralph.sh"

# Create empty progress.txt file
: >"progress.txt"

# Create prd.json file with valid JSON
cat >"prd.json" <<'EOF'
[
  {
    "category": "",
    "description": "",
    "steps": [],
    "passes": false
  }
]
EOF

echo "✅ Ralph initialized"
echo "🧨 Cleaning up installer: $SCRIPT_PATH"
