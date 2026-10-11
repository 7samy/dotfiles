#!/bin/bash
# Importiert alle /etc/wireguard/proton-*.conf als NetworkManager-Verbindungen.
# Ausfuehren mit: sudo ./import-vpn.sh
set -u
if [ "$(id -u)" -ne 0 ]; then
    echo "Bitte mit sudo ausfuehren: sudo $0" >&2
    exit 1
fi

for f in /etc/wireguard/proton-*.conf; do
    [ -e "$f" ] || { echo "Keine proton-*.conf in /etc/wireguard gefunden"; exit 1; }
    name=$(basename "$f" .conf)
    if nmcli -g NAME connection show | grep -qx "$name"; then
        echo "uebersprungen (existiert schon): $name"
        continue
    fi
    if nmcli connection import type wireguard file "$f" >/dev/null; then
        # nicht automatisch beim Booten verbinden
        nmcli connection modify "$name" connection.autoconnect no
        echo "importiert: $name"
    else
        echo "FEHLER beim Import: $f" >&2
    fi
done
