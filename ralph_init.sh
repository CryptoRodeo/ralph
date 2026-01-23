#!/bin/bash

# Download ralph.sh from GitHub
curl -o ralph.sh https://raw.githubusercontent.com/CryptoRodeo/ralph/refs/heads/main/ralph.sh

# Make ralph.sh executable
chmod +x ralph.sh

# Create empty progress.txt file
touch progress.txt

# Create prd.json file with correct format
cat >prd.json <<'EOF'
[
  {
    "category": "",
    "description": "",
    "steps": [

    ],
    "passes": false
  },
]
EOF

# Delete this script after setup is complete (only if run as a file, not piped)
if [ -f "$0" ]; then
  rm -- "$0"
fi
