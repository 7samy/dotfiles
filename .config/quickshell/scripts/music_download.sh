#!/usr/bin/env bash
# Laedt einen Song von SoundCloud, YouTube (Music) oder Spotify als mp3 in den Music-Ordner.
#   Aufruf: music_download.sh <link> <musikordner>
#
# SoundCloud -> yt-dlp
# YouTube    -> yt-dlp (music.youtube.com, youtube.com, youtu.be)
# Spotify    -> 1) spotdl (Titel/Kuenstler/Cover von Spotify, Tonspur von YouTube Music)
#               2) Fallback, falls spotdl scheitert (z.B. AudioProviderError):
#                  spotdl liefert nur die Songdaten, die Tonspur holt das normale
#                  yt-dlp per YouTube-Suche (Dauer-Abgleich), Tags + Cover werden
#                  danach per ffmpeg gesetzt. Die Spotify-Datei selbst ist
#                  DRM-geschuetzt und wird nie verwendet.
#
# Ausgabe (eine Zeile pro Ereignis, wird von MusicPickerState gelesen):
#   STATUS|text      Statusmeldung
#   PROG|prozent     Fortschritt 0-100
#   DONE|name        fertig (Dateiname ohne .mp3, bei mehreren "N Songs")
#   ERR|text         Fehler
# Das Fehlerprotokoll steht in /tmp/qs_music_dl.log

url="$1"
dir="${2%/}"
log=/tmp/qs_music_dl.log

emit() { printf '%s|%s\n' "$1" "$2"; }
fail() { emit ERR "$1"; exit 1; }
need() { command -v "$1" > /dev/null 2>&1 || fail "$1 fehlt ($2)"; }

# yt-dlp mit Fortschrittsanzeige; Rest der Argumente geht direkt an yt-dlp
run_ytdlp() {
    yt-dlp --ignore-config --newline \
        --progress-template "download:PROG|%(progress._percent_str)s" "$@" 2>> "$log" | while IFS= read -r line; do
        case "$line" in
            PROG\|*)
                p="${line#PROG|}"
                p="${p//[^0-9.]/}"
                if [ -n "$p" ]; then
                    emit PROG "$p"
                    case "$p" in 100*) emit STATUS "Konvertiere …" ;; esac
                fi
                ;;
        esac
    done
    return "${PIPESTATUS[0]}"
}

# Spotify-Fallback: Songdaten von spotdl, Tonspur per yt-dlp-Suche
spotify_fallback() {
    command -v yt-dlp > /dev/null 2>&1 || return 1
    command -v python3 > /dev/null 2>&1 || return 1

    emit STATUS "Hole Songdaten …"
    timeout 60 spotdl save "$url" --save-file "$tmp/meta.spotdl" >> "$log" 2>&1
    [ -s "$tmp/meta.spotdl" ] || return 1

    local title artist album dur cover
    IFS=$'\t' read -r title artist album dur cover < <(python3 - "$tmp/meta.spotdl" << 'PY'
import json, sys
d = json.load(open(sys.argv[1]))
s = d[0] if isinstance(d, list) else d
arts = s.get("artists") or ([s["artist"]] if s.get("artist") else [])
clean = lambda x: str(x or "").replace("\t", " ").replace("\n", " ").strip()
print("\t".join([
    clean(s.get("name")),
    clean(", ".join(arts)),
    clean(s.get("album_name")),
    str(int(s.get("duration") or 0)),
    clean(s.get("cover_url")),
]))
PY
)
    [ -n "$title" ] || return 1
    local first="${artist%%,*}"

    emit STATUS "Suche auf YouTube …"
    local filter=()
    if [ "${dur:-0}" -gt 0 ] 2> /dev/null; then
        filter=(--match-filter "duration>=$((dur - 6)) & duration<=$((dur + 10))")
    fi
    rm -f "$tmp"/dl.*
    # --max-downloads 1 beendet yt-dlp mit Code 101, das ist hier kein Fehler
    run_ytdlp -f "bestaudio/best" -x --audio-format mp3 --audio-quality 0 \
        "${filter[@]}" --max-downloads 1 -o "dl.%(ext)s" "ytsearch5:$first $title"
    if [ ! -s "$tmp/dl.mp3" ] && [ ${#filter[@]} -gt 0 ]; then
        # Kein Treffer mit passender Laenge -> ersten Treffer nehmen
        emit STATUS "Suche erneut …"
        run_ytdlp -f "bestaudio/best" -x --audio-format mp3 --audio-quality 0 \
            --max-downloads 1 -o "dl.%(ext)s" "ytsearch1:$first $title"
    fi
    [ -s "$tmp/dl.mp3" ] || return 1

    # Tags + Cover setzen
    emit STATUS "Setze Tags …"
    [ -n "$cover" ] && curl -fsSL --max-time 20 "$cover" -o "$tmp/cover.jpg" 2>> "$log"
    local fname="$artist - $title"
    fname="${fname//\//_}"
    fname="${fname#.}"
    local ok=1
    if [ -s "$tmp/cover.jpg" ]; then
        ffmpeg -y -loglevel error -i "$tmp/dl.mp3" -i "$tmp/cover.jpg" -map 0:a -map 1:v -c copy -id3v2_version 3 \
            -metadata title="$title" -metadata artist="$artist" -metadata album="$album" \
            -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)" \
            "$tmp/final.mp3" 2>> "$log" && ok=0
    fi
    if [ "$ok" -ne 0 ]; then
        ffmpeg -y -loglevel error -i "$tmp/dl.mp3" -c copy -id3v2_version 3 \
            -metadata title="$title" -metadata artist="$artist" -metadata album="$album" \
            "$tmp/final.mp3" 2>> "$log" || return 1
    fi
    rm -f "$tmp/dl.mp3"
    mv -f "$tmp/final.mp3" "$tmp/$fname.mp3"
    return 0
}

[ -n "$url" ] && [ -n "$dir" ] || fail "Link oder Ordner fehlt"
mkdir -p "$dir" 2> /dev/null || fail "Ordner nicht beschreibbar"

# ---- Dienst erkennen (nur diese Link-Formen werden akzeptiert) ----
case "$url" in
    https://open.spotify.com/* | https://spotify.link/* | spotify:track:*) svc=spotify ;;
    https://soundcloud.com/* | https://www.soundcloud.com/* | https://m.soundcloud.com/* | https://on.soundcloud.com/* | https://snd.sc/*) svc=soundcloud ;;
    https://music.youtube.com/* | https://www.youtube.com/* | https://m.youtube.com/* | https://youtube.com/* | https://youtu.be/*) svc=youtube ;;
    *) fail "Nur Spotify-, SoundCloud- oder YouTube-Links" ;;
esac

case "$svc:$url" in
    spotify:*/album/* | spotify:*/playlist/* | spotify:*/artist/*) fail "Bitte einen einzelnen Song verlinken" ;;
    soundcloud:*/sets/*) fail "Bitte einen einzelnen Song verlinken" ;;
    youtube:*/playlist\?* | youtube:*/browse/* | youtube:*/channel/*) fail "Bitte einen einzelnen Song verlinken" ;;
esac

need ffmpeg "sudo pacman -S ffmpeg"

tmp=$(mktemp -d /tmp/qs_dl.XXXXXX) || fail "Temp-Ordner fehlgeschlagen"
trap 'rm -rf "$tmp"' EXIT
cd "$tmp" || fail "Temp-Ordner nicht erreichbar"
: > "$log"
shopt -s nullglob

# ---- Download ----
if [ "$svc" = soundcloud ] || [ "$svc" = youtube ]; then
    need yt-dlp "sudo pacman -S yt-dlp"
    if [ "$svc" = youtube ]; then
        emit STATUS "Lade von YouTube …"
    else
        emit STATUS "Lade von SoundCloud …"
    fi
    # --no-playlist: bei Links wie watch?v=...&list=... nur den einen Song laden
    run_ytdlp --no-playlist --no-warnings \
        -f "bestaudio/best" -x --audio-format mp3 --audio-quality 0 \
        --embed-thumbnail --convert-thumbnails jpg --embed-metadata \
        -o "%(artist,uploader)s - %(title)s.%(ext)s" -- "$url"
else
    need spotdl "pipx install spotdl"
    emit STATUS "Suche Song …"
    timeout 60 spotdl download "$url" --format mp3 \
        --output "{artists} - {title}.{output-ext}" 2>&1 | tr '\r' '\n' | tee -a "$log" | while IFS= read -r line; do
        case "$line" in
            *ownloading*) emit STATUS "Lade herunter …" ;;
            *onverting* | *Processing*) emit STATUS "Konvertiere …" ;;
        esac
    done
    files=("$tmp"/*.mp3)
    if [ ${#files[@]} -eq 0 ]; then
        emit STATUS "spotdl fehlgeschlagen, neuer Weg …"
        spotify_fallback
    fi
fi

# ---- Ergebnis einsammeln ----
files=("$tmp"/*.mp3)
if [ ${#files[@]} -eq 0 ]; then
    if grep -qiE 'javascript runtime|js runtime|n challenge|challenge solving' "$log"; then
        fail "yt-dlp braucht eine JS-Laufzeit (sudo pacman -S deno)"
    fi
    reason=$(grep -iE 'error|failed|unable|rate' "$log" | tail -n1 | cut -c1-80)
    fail "Download fehlgeschlagen${reason:+: $reason}"
fi

moved=0
last=""
for f in "${files[@]}"; do
    b=$(basename "$f")
    if [ -e "$dir/$b" ]; then
        last="$b"
        continue
    fi
    if mv -n -- "$f" "$dir/"; then
        moved=$((moved + 1))
        last="$b"
    fi
done
[ "$moved" -gt 0 ] || fail "Song ist schon vorhanden"

emit STATUS "Aktualisiere Bibliothek …"
command -v mpc > /dev/null 2>&1 && mpc update --wait > /dev/null 2>&1

name="${last%.mp3}"
[ "$moved" -gt 1 ] && name="$moved Songs"
emit DONE "$name"
