#!/bin/bash

# Updated to the correct absolute path
SOURCE_DIR="/home/azu/Documents/Programming"

cd "$SOURCE_DIR" || { echo "Error: Could not find $SOURCE_DIR"; exit 1; }

if [ ! -d ".git" ]; then
    echo "Error: No Git repository found in $SOURCE_DIR."
    exit 1
fi

# Remove 2>/dev/null so you can see if the push fails for other reasons (like SSH)
git add -A
if ! git diff --cached --quiet; then
    echo "Changes found. Committing and pushing..."
    git commit -m "auto: sync $(date '+%Y-%m-%d %H:%M')"
    BRANCH=$(git branch --show-current)
    git push origin "$BRANCH"
else
    echo "No changes. Nothing to do."
fi
