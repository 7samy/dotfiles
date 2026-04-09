#!/bin/bash

SOURCE_DIR="$HOME/Programming"

cd "$SOURCE_DIR" || exit 1

if [ ! -d ".git" ]; then
    echo "Error: No Git repository found in $SOURCE_DIR."
    exit 1
fi

git add -A 2>/dev/null

if ! git diff --cached --quiet; then
    echo "Changes found. Committing and pushing..."
    git commit -m "auto: sync $(date '+%Y-%m-%d %H:%M')" 2>/dev/null
    BRANCH=$(git branch --show-current)
    git push origin "$BRANCH" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo "Success: Push completed."
    else
        echo "Error: Push failed."
    fi
else
    echo "No changes. Nothing to do."
fi
