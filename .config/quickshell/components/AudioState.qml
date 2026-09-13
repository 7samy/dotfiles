import QtQuick
import Quickshell
import Quickshell.Services.Mpris
pragma Singleton

QtObject {
    // WICHTIG: _lastRawPos NICHT überschreiben – wir brauchen den alten
    // Wert vom Ende des vorherigen Liedes, um den Reset zu erkennen!

    id: root

    // ==== Audio-Icon-Zustand ====
    property real iconCenterX: 0
    property bool dropdownOpen: false
    property bool buttonHovered: false
    property bool dropdownHovered: false
    property bool muted: false
    // ==== MPRIS-Player ====
    property MprisPlayer lastActivePlayer: null
    readonly property MprisPlayer activePlayer: {
        const players = Mpris.players.values;
        if (root.lastActivePlayer && players.indexOf(root.lastActivePlayer) !== -1 && !isBrowser(root.lastActivePlayer))
            return root.lastActivePlayer;

        for (const p of players) {
            if (p.playbackState === MprisPlaybackState.Playing && !isBrowser(p))
                return p;

        }
        for (const p of players) {
            if (p.playbackState === MprisPlaybackState.Playing)
                return p;

        }
        if (root.lastActivePlayer && players.indexOf(root.lastActivePlayer) !== -1)
            return root.lastActivePlayer;

        return players.length > 0 ? players[0] : null;
    }
    readonly property bool hasPlayer: activePlayer !== null
    readonly property bool isPlaying: hasPlayer && activePlayer.playbackState === MprisPlaybackState.Playing
    readonly property string title: hasPlayer ? (activePlayer.trackTitle ?? "") : ""
    readonly property string artist: hasPlayer ? (activePlayer.trackArtist ?? "") : ""
    readonly property string artUrl: {
        if (!hasPlayer)
            return "";

        var url = activePlayer.trackArtUrl ?? "";
        if (!url && activePlayer.metadata && activePlayer.metadata["mpris:artUrl"])
            url = activePlayer.metadata["mpris:artUrl"];

        return url;
    }
    // ==== Wiedergabeposition / Länge / Lautstärke ====
    property real position: 0
    property real length: 0
    property real volume: 0
    // ==== Track-Erkennung & Cooldown ====
    property string _trackKey: ""
    property int _positionCooldown: 0
    property real _lastRawPos: 0 // NEU: Merkt sich den letzten rohen Wert vom Player
    // ==== Website-Icon-Quelle (PNG) ====
    readonly property string websiteIconSource: {
        if (!hasPlayer)
            return "";

        var domain = "";
        if (activePlayer.metadata && activePlayer.metadata["xesam:url"])
            domain = extractDomain(activePlayer.metadata["xesam:url"]);
        else if (activePlayer.trackId)
            domain = extractDomain(activePlayer.trackId);
        var basePath = "file:///home/azu/.config/quickshell/resources/icons/";
        if (domain.includes("youtube") || domain.includes("youtu.be"))
            return basePath + "youtube.png";

        if (domain.includes("twitch"))
            return basePath + "twitch.png";

        if (domain.includes("tiktok"))
            return basePath + "tiktok.png";

        var identity = activePlayer.identity.toLowerCase();
        if (identity.includes("zen") || identity.includes("firefox"))
            return basePath + "firefox.png";

        if (identity.includes("chrome") || identity.includes("chromium"))
            return basePath + "chrome.png";

        return "";
    }
    readonly property bool showWebsiteIcon: hasPlayer && isBrowser(activePlayer)
    // ==== Timer ====
    property Timer hideTimer
    property Timer playerUpdateTimer

    function isBrowser(player) {
        if (!player)
            return false;

        var identity = player.identity.toLowerCase();
        var desktopEntry = player.desktopEntry ? player.desktopEntry.toLowerCase() : "";
        return identity.includes("firefox") || identity.includes("zen") || identity.includes("chrome") || identity.includes("chromium") || desktopEntry.includes("firefox") || desktopEntry.includes("zen") || desktopEntry.includes("chrome") || desktopEntry.includes("chromium");
    }

    function extractDomain(url) {
        if (!url)
            return "";

        var s = url.toString().replace(/^https?:\/\//, "").split('/')[0].split(':')[0].replace(/^www\./, "");
        return s.toLowerCase();
    }

    function updateHoverTimer() {
        if (!root.buttonHovered && !root.dropdownHovered)
            hideTimer.start();
        else
            hideTimer.stop();
    }

    function togglePlay() {
        if (hasPlayer)
            activePlayer.togglePlaying();

    }

    function next() {
        if (hasPlayer && activePlayer.canGoNext)
            activePlayer.next();

    }

    function previous() {
        if (hasPlayer && activePlayer.canGoPrevious)
            activePlayer.previous();

    }

    function startHideTimer() {
        hideTimer.start();
    }

    function stopHideTimer() {
        hideTimer.stop();
    }

    function seekTo(targetPosition) {
        if (hasPlayer && activePlayer.positionSupported) {
            activePlayer.position = targetPosition;
            root.position = targetPosition;
            root._positionCooldown = 3;
        }
    }

    function setVolume(val) {
        if (hasPlayer) {
            const safeVal = Math.max(0, Math.min(val, 1));
            activePlayer.volume = safeVal;
            root.volume = safeVal;
        }
    }

    hideTimer: Timer {
        interval: 400
        onTriggered: root.dropdownOpen = false
    }

    playerUpdateTimer: Timer {
        interval: 200
        running: true
        repeat: true
        onTriggered: {
            // _lastRawPos bewusst NICHT aktualisieren!

            if (!root.hasPlayer) {
                root.position = 0;
                root.length = 0;
                root.volume = 0;
                root._trackKey = "";
                root._positionCooldown = 0;
                root._lastRawPos = 0;
                return ;
            }
            const player = root.activePlayer;
            const newPos = player.position || 0;
            const newLength = player.length || 0;
            const newVol = (player.volume !== undefined && Number.isFinite(player.volume)) ? player.volume : 0;
            const trackKey = (player.trackTitle ?? "") + "|" + (player.trackArtist ?? "") + "|" + (player.trackId ?? "");
            if (trackKey !== root._trackKey) {
                // Neues Lied erkannt
                root._trackKey = trackKey;
                root.length = newLength;
                root.position = 0;
                root._positionCooldown = 25; // ~5 s Puffer für langsame Player
                // Wenn der Player schon bei (fast) 0 ist, sofort übernehmen
                if (newPos < 2) {
                    root._positionCooldown = 0;
                    root.position = newPos;
                    root._lastRawPos = newPos;
                }
            } else if (root._positionCooldown > 0) {
                root._positionCooldown -= 1;
                root.length = newLength;
                // Reset erkannt, wenn Position gesunken ist ODER sehr klein ist
                if (newPos + 0.5 < root._lastRawPos || newPos < 2) {
                    root._positionCooldown = 0;
                    root.position = newPos;
                    root._lastRawPos = newPos; // ab jetzt normal weiterführen
                } else {
                    root.position = 0;
                }
            } else {
                root.position = newPos;
                root.length = newLength;
                root._lastRawPos = newPos;
            }
            root.volume = newVol;
            // ---- Player-Aktualisierung (unverändert) ----
            const players = Mpris.players.values;
            for (const p of players) {
                if (p.playbackState === MprisPlaybackState.Playing && !isBrowser(p)) {
                    if (root.lastActivePlayer !== p)
                        root.lastActivePlayer = p;

                    return ;
                }
            }
            for (const p of players) {
                if (p.playbackState === MprisPlaybackState.Playing) {
                    if (root.lastActivePlayer !== p)
                        root.lastActivePlayer = p;

                    return ;
                }
            }
        }
    }

}
