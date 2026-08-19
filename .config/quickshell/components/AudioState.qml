import QtQuick
import Quickshell
import Quickshell.Services.Mpris
pragma Singleton

QtObject {
    id: root

    // ==== Audio-Icon-Zustand ====
    property real iconCenterX: 0
    property bool dropdownOpen: false
    property bool buttonHovered: false
    property bool dropdownHovered: false // NEU: Hover-Status des Dropdowns
    property bool muted: false
    property real volumePercent: 50
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

        console.log("DEBUG artUrl:", url, "Player:", activePlayer.identity);
        return url;
    }
    // ==== Website-Icon-Quelle (PNG) ====
    readonly property string websiteIconSource: {
        if (!hasPlayer)
            return "";

        var domain = "";
        if (activePlayer.metadata && activePlayer.metadata["xesam:url"])
            domain = extractDomain(activePlayer.metadata["xesam:url"]);
        else if (activePlayer.trackId)
            domain = extractDomain(activePlayer.trackId);
        console.log("DEBUG domain:", domain);
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
    // ==== Soll Website-Icon anstelle des Covers angezeigt werden? ====
    readonly property bool showWebsiteIcon: hasPlayer && isBrowser(activePlayer)
    // ==== Dropdown-Timer ====
    property Timer hideTimer
    // ==== Timer zur Aktualisierung des lastActivePlayer ====
    property Timer playerUpdateTimer

    // ==== Browser-Erkennung ====
    function isBrowser(player) {
        if (!player)
            return false;

        var identity = player.identity.toLowerCase();
        var desktopEntry = player.desktopEntry ? player.desktopEntry.toLowerCase() : "";
        return identity.includes("firefox") || identity.includes("zen") || identity.includes("chrome") || identity.includes("chromium") || desktopEntry.includes("firefox") || desktopEntry.includes("zen") || desktopEntry.includes("chrome") || desktopEntry.includes("chromium");
    }

    // ==== Domain aus URL extrahieren ====
    function extractDomain(url) {
        if (!url)
            return "";

        var s = url.toString();
        s = s.replace(/^https?:\/\//, "");
        s = s.split('/')[0];
        s = s.split(':')[0];
        s = s.replace(/^www\./, "");
        return s.toLowerCase();
    }

    // ==== Zentrale Hover-Statusverwaltung ====
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

    hideTimer: Timer {
        interval: 400
        onTriggered: root.dropdownOpen = false
    }

    playerUpdateTimer: Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: {
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
