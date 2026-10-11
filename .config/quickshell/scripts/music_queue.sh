#!/bin/bash
# Verwaltet die "Up next"-Warteschlange direkt in der mpd-Playlist.
#
# Die mpd-Playlist enthaelt die ganze Bibliothek. Vorgemerkte Songs liegen als
# Block direkt hinter dem laufenden Song:
#
#   [laufender Song] [queue 0] [queue 1] ... [Rest der Bibliothek]
#
# Aufruf (Indizes sind 0-basiert innerhalb der Queue):
#   music_queue.sh add   <datei> <k>   # hinter die k bereits vorgemerkten Songs
#   music_queue.sh del   <index>       # aus der Queue entfernen
#   music_queue.sh next  <index>       # an den Anfang der Queue ("Play next")
#   music_queue.sh play  <index>       # diesen Queue-Song sofort abspielen
#   music_queue.sh clear <anzahl>      # die naechsten <anzahl> Songs entfernen
set -u

cmd="${1:-}"
cur=$(mpc -f "%position%" current 2>/dev/null)   # 1-basierte Position des laufenden Songs
[ -n "$cur" ] || exit 1                          # es laeuft nichts -> nichts zu tun
base=$((cur + 1))                                # Position von queue[0]

case "$cmd" in
    add)
        f="${2:-}"
        k="${3:-0}"
        [ -n "$f" ] || exit 1
        # Direkt hinter den laufenden Song einfuegen ...
        mpc insert "$f" >/dev/null || exit 1
        # ... und hinter die bereits vorgemerkten Songs schieben
        if [ "$k" -gt 0 ]; then
            mpc move "$base" "$((base + k))" >/dev/null
        fi
        ;;
    del)
        mpc del "$((base + ${2:-0}))" >/dev/null
        ;;
    next)
        mpc move "$((base + ${2:-0}))" "$base" >/dev/null
        ;;
    play)
        mpc play "$((base + ${2:-0}))" >/dev/null
        ;;
    clear)
        for _ in $(seq 1 "${2:-0}"); do
            mpc del "$base" >/dev/null
        done
        ;;
esac
exit 0
