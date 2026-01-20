#!/bin/bash

TARGET="nvim"
TERMINAL="kitty"
CLASS_NAME="nvim-reload"

PIDS=$(pgrep -f "$TARGET" | grep -v $$)

if [ -n "$PIDS" ]; then
    kill -9 $PIDS 2>/dev/null
    sleep 0.3
fi
setsid $TERMINAL --class "$CLASS_NAME" -e $TARGET >/dev/null 2>&1 &

sleep 0.1
exit 0
