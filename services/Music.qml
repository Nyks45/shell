pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Caelestia.I18n
import qs.services
import qs.utils

// The island's music: Spotify's library (caelestia-spotify: playlists, liked songs, recent) and
// playing it in the Spotify app, which is started hidden (a special workspace) when it isn't
// running. The last track played is remembered, so it shows (and plays) while Spotify is closed.
Singleton {
    id: root

    readonly property string helper: `${Paths.libdir}/caelestia-spotify`
    readonly property MprisPlayer spotify: Players.list.find(p => (p.identity ?? "").toLowerCase().includes("spotify")) ?? null

    property bool loggedIn
    property string user
    property bool loading
    property string error
    property var playlists: []
    property var recent: []
    // The playlist opened in the library: {id, name, context, tracks}
    property var openList: null

    // A search: its text and the results (songs, artists, albums, playlists in one list)
    property string query
    property var results: []
    property bool searching

    // The last thing played (any player), kept in the state dir
    property var last: null

    // Waiting for Spotify to start, to play this
    property string pendingUri
    // Spotify started by the shell to play: its window is never seen. It opens on a hidden
    // workspace (only while it starts: closing it earlier makes Spotify show it again) and, once
    // playing, is closed to the tray (Spotify's "minimize to tray": it keeps running there). Its
    // tray's "Show Spotify" then opens it normally, on the current workspace.
    readonly property string holdWs: "special:caelestia-hold"
    property bool hideNext

    // Its window, if it's still in the hidden holding place (never one the user brought up)
    function closeHeldWindow(): void {
        hideNext = false;
        const t = Hyprland.toplevels.values.find(t => /spotify/i.test(t.lastIpcObject?.class ?? "") && t.workspace?.name === holdWs);
        if (t)
            Hypr.dispatch(`hl.dsp.window.close({ window = "address:0x${t.address}" })`);
    }

    Timer {
        id: closeHeld

        // (after the song was handed to it, playLater: Spotify has settled by then)
        interval: 2500
        onTriggered: root.closeHeldWindow()
    }

    function refresh(): void {
        statusProc.running = true;
    }

    function login(): void {
        error = "";
        loginProc.running = true;
    }

    function logout(): void {
        Quickshell.execDetached([helper, "logout"]);
        loggedIn = false;
        playlists = [];
        recent = [];
        openList = null;
    }

    function loadLibrary(): void {
        if (!loggedIn)
            return;
        listsProc.running = true;
        recentProc.running = true;
    }

    // Searched as it's typed (a short pause first; the newest search wins)
    function search(text: string): void {
        query = text.trim();
        if (!query) {
            results = [];
            searchDelay.stop();
            return;
        }
        searchDelay.restart();
    }

    Timer {
        id: searchDelay

        interval: 350
        onTriggered: {
            searchProc.running = false;
            searchProc.asked = root.query;
            searchProc.command = [root.helper, "search", root.query];
            searchProc.running = true;
        }
    }

    function openPlaylist(p: var): void {
        openList = {
            id: p.id,
            name: p.name,
            context: "",
            tracks: []
        };
        tracksProc.command = [helper, "tracks", p.id];
        tracksProc.running = true;
    }

    // Play a Spotify URI (a track, a playlist): in the running app, else start it hidden first
    function play(uri: string): void {
        if (!uri)
            return;
        if (spotify) {
            spotify.openUri(uri);
            Players.manualActive = spotify;
            return;
        }
        pendingUri = uri;
        // Started for this, so out of sight (see holdWs; launch rules only apply to this first
        // window, so Spotify opened later is a normal window)
        hideNext = true;
        Hypr.dispatch(`hl.dsp.exec_cmd("spotify", { workspace = "${holdWs} silent", no_initial_focus = true, no_focus = true, no_anim = true })`);
        pendingTimeout.restart();
    }

    // Play/pause: the active player; nothing playing, the last track (Spotify started hidden)
    function toggle(): void {
        if (Players.active)
            Players.active.togglePlaying();
        else if (last?.uri)
            play(last.uri);
        else
            play("spotify:collection:tracks");
    }

    onSpotifyChanged: {
        if (spotify && pendingUri) {
            const uri = pendingUri;
            pendingUri = "";
            // (it takes a moment to accept commands after it appears)
            Qt.callLater(() => playLater.start());
            playLater.uri = uri;
        }
    }

    Timer {
        id: playLater

        property string uri

        interval: 1500
        onTriggered: {
            root.spotify?.openUri(uri);
            if (root.spotify)
                Players.manualActive = root.spotify;
            if (root.hideNext)
                closeHeld.restart();
        }
    }

    Timer {
        id: pendingTimeout

        interval: 30000
        onTriggered: {
            root.pendingUri = "";
            root.hideNext = false;
        }
    }

    // Remember what's playing (Spotify's track URI when it's Spotify)
    Connections {
        function onPostTrackChanged(): void {
            root.remember();
        }

        target: Players.active
        ignoreUnknownSignals: true
    }

    function remember(): void {
        const p = Players.active;
        if (!p || !p.trackTitle)
            return;
        const id = String(p.metadata?.["mpris:trackid"] ?? "");
        const uri = id.startsWith("spotify:") ? id : id.includes("/com/spotify/track/") ? "spotify:track:" + id.split("/").pop() : "";
        const next = {
            title: p.trackTitle,
            artist: p.trackArtist,
            art: Players.getArtUrl(p),
            player: Players.getIdentity(p),
            uri: uri
        };
        if (JSON.stringify(next) === JSON.stringify(last))
            return;
        last = next;
        lastFile.setText(JSON.stringify(next));
    }

    Component.onCompleted: refresh()

    FileView {
        id: lastFile

        path: `${Paths.state}/music-last.json`
        printErrors: false
        onLoaded: {
            try {
                root.last = JSON.parse(text());
            } catch (e) {}
        }
    }

    Process {
        id: statusProc

        command: [root.helper, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const s = JSON.parse(text);
                    root.loggedIn = s.loggedIn;
                    root.user = s.user ?? "";
                    if (root.loggedIn && root.playlists.length === 0)
                        root.loadLibrary();
                } catch (e) {}
            }
        }
    }

    Process {
        id: loginProc

        command: [root.helper, "login"]
        stdout: StdioCollector {
            onStreamFinished: root.refresh()
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    root.error = text.trim();
            }
        }
    }

    Process {
        id: listsProc

        command: [root.helper, "playlists"]
        onRunningChanged: root.loading = running
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.playlists = JSON.parse(text);
                } catch (e) {}
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    root.error = text.trim();
            }
        }
    }

    Process {
        id: recentProc

        command: [root.helper, "recent"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.recent = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    Process {
        id: searchProc

        property string asked

        onRunningChanged: root.searching = running
        stdout: StdioCollector {
            onStreamFinished: {
                if (searchProc.asked !== root.query)
                    return;
                try {
                    const r = JSON.parse(text);
                    // Songs first, then the rest under their own headings
                    const head = (key, title) => r[key]?.length ? [
                        {
                            header: title
                        }
                    ].concat(r[key]) : [];
                    root.results = r.tracks.concat(head("artists", Tr.tr("Artists")), head("albums", Tr.tr("Albums")), head("playlists", Tr.tr("Playlists")));
                } catch (e) {}
            }
        }
    }

    Process {
        id: tracksProc

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    root.openList = Object.assign({}, root.openList, {
                        context: r.context,
                        tracks: r.tracks,
                        restricted: !!r.restricted,
                        loaded: true
                    });
                } catch (e) {}
            }
        }
    }
}
