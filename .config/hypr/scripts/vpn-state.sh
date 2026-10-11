#!/bin/bash
# Merkt sich die zuletzt genutzte VPN-Verbindung und stellt sie wieder her.
# Usage:
#   vpn-state.sh save <name>   – speichert <name> als letzte Verbindung
#   vpn-state.sh restore       – verbindet mit der gespeicherten Verbindung

STATE_FILE="$HOME/.cache/vpn-last"

case "$1" in
    save)
        if [ -z "$2" ]; then
            echo "Usage: $0 save <name>"
            exit 1
        fi
        echo "$2" > "$STATE_FILE"
        ;;
    restore)
        [ -f "$STATE_FILE" ] || exit 0
        NAME=$(cat "$STATE_FILE")
        [ -n "$NAME" ] || exit 0

        # Kurz warten, bis NetworkManager bereit ist (nach Login)
        for i in $(seq 1 10); do
            if nmcli -t -f RUNNING general 2>/dev/null | grep -q "running"; then
                break
            fi
            sleep 1
        done

        # Nur verbinden, falls nicht schon aktiv
        if ! nmcli -t -f NAME connection show --active | grep -qxF "$NAME"; then
            nmcli connection up "$NAME"
        fi
        ;;
    *)
        echo "Usage: $0 {save <name>|restore}"
        exit 1
        ;;
esac
