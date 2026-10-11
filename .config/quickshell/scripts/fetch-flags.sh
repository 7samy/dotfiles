#!/bin/bash
# Laedt die runden Flaggen (circle-flags, MIT) fuer alle WireGuard-Verbindungen
# in ~/.config/quickshell/resources/flags
# Aufruf ohne Argumente: Codes aus den NetworkManager-Verbindungen "proton-xx"
# Aufruf mit Codes:      ./fetch-flags.sh de us nl
set -u
dest="$HOME/.config/quickshell/resources/flags"
mkdir -p "$dest"

if [ $# -gt 0 ]; then
    codes="$*"
else
    codes=$(nmcli -t -f NAME,TYPE connection show \
        | grep ':wireguard$' \
        | sed -nE 's/^proton-([a-zA-Z]{2})([-_.].*)?:wireguard$/\1/p' \
        | tr 'A-Z' 'a-z' | sort -u)
fi

[ -n "$codes" ] || { echo "Keine Laendercodes gefunden (erst import-vpn.sh ausfuehren?)"; exit 1; }

for c in $codes; do
    url="https://raw.githubusercontent.com/HatScripts/circle-flags/gh-pages/flags/$c.svg"
    if curl -fsS -o "$dest/$c.svg" "$url"; then
        echo "ok: $c"
    else
        rm -f "$dest/$c.svg"
        echo "nicht gefunden: $c" >&2
    fi
done
echo "Flaggen in $dest"
