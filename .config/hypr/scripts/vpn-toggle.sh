#!/bin/bash

# Ensure we only get the JSON output and no terminal errors
exec 2>/dev/null

# Check for 'proton' in active connections
if nmcli connection show --active | grep -q "proton"; then
    if [ "$1" == "toggle" ]; then
        nmcli connection down proton
    else
        echo '{"text": " Proton", "class": "connected", "tooltip": "Connected to Proton"}'
    fi
else
    if [ "$1" == "toggle" ]; then
        nmcli connection up proton
    else
        echo '{"text": " Proton", "class": "disconnected", "tooltip": "VPN Disconnected"}'
    fi
fi
