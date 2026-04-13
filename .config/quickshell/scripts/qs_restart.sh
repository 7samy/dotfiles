#!/bin/bash
pkill -x qs
while pgrep -x qs > /dev/null; do
    sleep 0.1
done
hyprctl dispatch exec qs
