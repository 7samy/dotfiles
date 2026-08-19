import QtQuick
import Quickshell
import Quickshell.Services.Mpris
pragma Singleton

QtObject {
    // Kein Player spielt -> lastActivePlayer beibehalten

    id: root

    // ==== Audio-Icon-Zustand ====
    property real iconCenterX: 0
    property bool dropdownOpen: false
    property bool buttonHovered: false
    property bool muted: false
    property real volumePercent: 50
    // ==== MPRIS-Player ====
    property MprisPlayer lastActivePlayer: null
    readonly property MprisPlayer activePlayer: {
        const players = Mpris.players.values;
        if (root.lastActivePlayer && players.indexOf(root.lastActivePlayer) !== -1)
            return root.lastActivePlayer;

        return players.length > 0 ? players[0] : null;
    }
    readonly property bool hasPlayer: activePlayer !== null
    readonly property bool isPlaying: hasPlayer && activePlayer.playbackState === MprisPlaybackState.Playing
    readonly property string title: hasPlayer ? (activePlayer.trackTitle ?? "") : ""
    readonly property string artist: hasPlayer ? (activePlayer.trackArtist ?? "") : ""
    readonly property string artUrl: hasPlayer ? (activePlayer.trackArtUrl ?? "") : ""
    // ==== Website-Icon (Vorrang für Browser) ====
    readonly property string websiteIcon: {
        if (!hasPlayer)
            return "";

        var domain = "";
        if (activePlayer.metadata && activePlayer.metadata["xesam:url"])
            domain = extractDomain(activePlayer.metadata["xesam:url"]);
        else if (activePlayer.trackId)
            domain = extractDomain(activePlayer.trackId);
        // YouTube erkennen (inkl. youtu.be, youtube-nocookie, music.youtube)
        if (domain.includes("youtube") || domain.includes("youtu.be"))
            return "\uf167"; // YouTube

        // Twitch
        if (domain.includes("twitch"))
            return "\uf1e8"; // Twitch

        // TikTok
        if (domain.includes("tiktok"))
            return "\ue07b"; // TikTok

        // Fallback: Player-Icon
        var identity = activePlayer.identity.toLowerCase();
        if (identity.includes("zen") || identity.includes("firefox"))
            return "\uf269";
 // Firefox
        if (identity.includes("chrome") || identity.includes("chromium"))
            return "\uf268";
 // Chrome
        return "󰝚"; // generisches Musik-Icon
    }
    // ==== Soll das Website-Icon anstelle des Covers angezeigt werden? ====
    readonly property bool showWebsiteIcon: hasPlayer && isBrowser(activePlayer)
    // ==== Dropdown-Timer (als Property) ====
    property Timer hideTimer

    hideTimer: Timer {
        interval: 200
        onTriggered: root.dropdownOpen = false
    }

    // ==== Timer zur Aktualisierung des lastActivePlayer (als Property) ====
    property Timer playerUpdateTimer

    playerUpdateTimer: Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: {
            const players = Mpris.players.values;
            for (const p of players) {
                if (p.playbackState === MprisPlaybackState.Playing) {
                    if (root.lastActivePlayer !== p)
                        root.lastActivePlayer = p;

                    return ;
                }
            }
        }
    }

    // ==== Browser-Erkennung ====
    function isBrowser(player) {
        if (!player)
            return false;

        var identity = player.identity.toLowerCase();
        var desktopEntry = player.desktopEntry ? player.desktopEntry.toLowerCase() : "";
        return identity.includes("firefox") || identity.includes("zen") || identity.includes("chrome") || identity.includes("chromium") || desktopEntry.includes("firefox") || desktopEntry.includes("zen") || desktopEntry.includes("chrome") || desktopEntry.includes("chromium");
    }

    // ==== Domain aus URL extrahieren (robust) ====
    function extractDomain(url) {
        if (!url)
            return "";

        var s = url.toString();
        // Protokoll entfernen
        s = s.replace(/^https?:\/\//, "");
        // Pfad/Query entfernen
        s = s.split('/')[0];
        // Port entfernen
        s = s.split(':')[0];
        // Optional www. entfernen
        s = s.replace(/^www\./, "");
        return s.toLowerCase();
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

}
