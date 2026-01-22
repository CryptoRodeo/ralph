#!/bin/bash

# Download ralph.sh from GitHub
curl -o ralph.sh https://raw.githubusercontent.com/CryptoRodeo/ralph/refs/heads/main/ralph.sh

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
