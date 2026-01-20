#!/bin/bash

# Kill Waybar gently first
pkill -f "waybar$"

# Wait for clean shutdown (increase time)
sleep 1

# Check if Waybar is still running
if pgrep -f "waybar$" >/dev/null; then
    echo "Waybar not responding to SIGTERM - sending SIGKILL"
    pkill -9 -f "waybar$"
    sleep 0.5  # Give time for SIGKILL to take effect
fi

if [ -f ~/.config/environment.d/*.conf ]; then
    set -a
    source ~/.config/environment.d/*.conf 2>/dev/null || true
    set +a
fi

# Start Waybar with proper environment
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DISPLAY="${DISPLAY:-:0}"

# Start Waybar - using nohup and redirecting output
nohup waybar >/tmp/waybar.log 2>&1 &

# Verify it started
sleep 0.5
if pgrep -f "waybar$" >/dev/null; then
    echo "Waybar restarted successfully"
else
    echo "Failed to restart Waybar"
    # Try one more time with debug
    echo "Trying with debug output..."
    nohup waybar --verbose >/tmp/waybar-debug.log 2>&1 &
fi 
