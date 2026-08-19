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
    property bool muted: false
    property real volumePercent: 50
    // ==== MPRIS-Player ====
    readonly property MprisPlayer activePlayer: {
        const players = Mpris.players.values;
        for (const p of players) {
            if (p.playbackState === MprisPlaybackState.Playing)
                return p;

        }
        return players.length > 0 ? players[0] : null;
    }
    readonly property bool hasPlayer: activePlayer !== null
    readonly property bool isPlaying: hasPlayer && activePlayer.playbackState === MprisPlaybackState.Playing
    readonly property string title: hasPlayer ? (activePlayer.trackTitle ?? "") : ""
    readonly property string artist: hasPlayer ? (activePlayer.trackArtist ?? "") : ""
    readonly property string artUrl: hasPlayer ? (activePlayer.trackArtUrl ?? "") : ""

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

}
