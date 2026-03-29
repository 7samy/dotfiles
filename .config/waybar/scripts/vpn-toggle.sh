#!/bin/bash

# Check if 'proton' connection is active
if nmcli connection show --active | grep -q "proton"; then
    # If it's active, show the "ON" icon for Waybar
    if [ "$1" == "toggle" ]; then
        nmcli connection down proton
    else
        echo '{"text": " Proton", "class": "connected", "tooltip": "Connected to Proton"}'
    fi
else
    # If it's inactive, show the "OFF" icon
    if [ "$1" == "toggle" ]; then
        nmcli connection up proton
    else
        echo '{"text": " Proton", "class": "disconnected", "tooltip": "VPN Disconnected"}'
    fi
fi
