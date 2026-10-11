#!/bin/bash
# Waehlt per Dateidialog eine oder mehrere WireGuard-.conf-Dateien (z.B. von Proton)
# aus und importiert sie als NetworkManager-Verbindung "proton-<land>[-N]".
# Laeuft ohne sudo (nmcli import als normaler Benutzer).
#
# Der Laendercode wird aus dem Dateinamen gelesen, z.B.:
#   NL#12.conf, wg-NL-FREE-12.conf, proton-nl.conf  ->  proton-nl, proton-nl-2, ...
set -u

notify() {
    command -v notify-send >/dev/null 2>&1 && notify-send -a "VPN" "$1" "${2:-}"
    return 0
}

pick_files() {
    local start="$HOME/Downloads/"
    [ -d "$start" ] || start="$HOME/"

    if command -v zenity >/dev/null 2>&1; then
        zenity --file-selection --multiple --separator='|' \
            --title="WireGuard-Konfigurationen auswaehlen" \
            --filename="$start" \
            --file-filter="WireGuard (*.conf) | *.conf" \
            --file-filter="Alle Dateien | *" 2>/dev/null | tr '|' '\n'
    elif command -v kdialog >/dev/null 2>&1; then
        kdialog --multiple --separate-output \
            --title "WireGuard-Konfigurationen auswaehlen" \
            --getopenfilename "$start" "*.conf|WireGuard (*.conf)" 2>/dev/null
    elif command -v yad >/dev/null 2>&1; then
        yad --file --multiple --separator='|' \
            --title="WireGuard-Konfigurationen auswaehlen" \
            --filename="$start" \
            --file-filter="WireGuard | *.conf" 2>/dev/null | tr '|' '\n'
    else
        notify "VPN-Import fehlgeschlagen" "Kein Dateidialog gefunden (zenity, kdialog oder yad installieren)."
        return 1
    fi
}

# Liest den Laendercode aus dem Dateinamen (erstes 2-Buchstaben-Token, "wg" wird uebersprungen)
country_code() {
    local base lower tok
    base=$(basename "$1")
    base="${base%.conf}"
    lower=$(echo "$base" | tr 'A-Z' 'a-z')
    for tok in $(echo "$lower" | tr -c 'a-z' ' '); do
        if [ "${#tok}" -eq 2 ] && [ "$tok" != "wg" ]; then
            echo "$tok"
            return
        fi
    done
    echo "xx"
}

files=$(pick_files) || exit 1
[ -n "$files" ] || exit 0   # Dialog abgebrochen

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

existing=$(nmcli -g NAME connection show)
ok=0
fail=0
last_err=""

while IFS= read -r f; do
    [ -n "$f" ] || continue

    cc=$(country_code "$f")
    name="proton-$cc"
    n=2
    while grep -qxF "$name" <<<"$existing"; do
        name="proton-$cc-$n"
        n=$((n + 1))
    done

    # NetworkManager benennt Verbindung + Interface nach dem Dateinamen
    cp -- "$f" "$tmp/$name.conf"
    if err=$(nmcli connection import type wireguard file "$tmp/$name.conf" 2>&1); then
        nmcli connection modify "$name" connection.autoconnect no >/dev/null 2>&1
        existing+=$'\n'"$name"
        ok=$((ok + 1))
    else
        fail=$((fail + 1))
        last_err="$(basename "$f"): $err"
    fi
    rm -f "$tmp/$name.conf"
done <<<"$files"

if [ "$fail" -gt 0 ]; then
    notify "VPN-Import: $ok ok, $fail fehlgeschlagen" "$last_err"
elif [ "$ok" -gt 0 ]; then
    notify "VPN-Import" "$ok Verbindung(en) importiert"
fi
exit 0
