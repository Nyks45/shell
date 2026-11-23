pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services

Singleton {
    id: root

    property string previousSinkName: ""
    property string previousSourceName: ""

    property list<PwNode> sinks: []
    property list<PwNode> sources: []
    property list<PwNode> streams: []
    property list<PwNode> recordingStreams: []
    // [{ name, label, activeProfile, profiles: [{ name, description }] }]
    property var cards: []
    // Pages showing the cards (openCards/closeCards): only then are they read
    // again on PipeWire changes (each read runs pactl)
    property int cardsUsers: 0

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property bool muted: !!sink?.audio?.muted
    readonly property real volume: sink?.audio?.volume ?? 0

    readonly property bool sourceMuted: !!source?.audio?.muted
    readonly property real sourceVolume: source?.audio?.volume ?? 0

    readonly property alias cava: cava
    readonly property alias beatTracker: beatTracker

    function setVolume(newVolume: real): void {
        if (sink?.ready && sink?.audio) {
            sink.audio.muted = false;
            sink.audio.volume = Math.max(0, Math.min(GlobalConfig.services.maxVolume, newVolume));
        }
    }

    function incrementVolume(amount: real): void {
        setVolume(volume + (amount || GlobalConfig.services.audioIncrement));
    }

    function decrementVolume(amount: real): void {
        setVolume(volume - (amount || GlobalConfig.services.audioIncrement));
    }

    function setSourceVolume(newVolume: real): void {
        if (source?.ready && source?.audio) {
            source.audio.muted = false;
            source.audio.volume = Math.max(0, Math.min(GlobalConfig.services.maxVolume, newVolume));
        }
    }

    function incrementSourceVolume(amount: real): void {
        setSourceVolume(sourceVolume + (amount || GlobalConfig.services.audioIncrement));
    }

    function decrementSourceVolume(amount: real): void {
        setSourceVolume(sourceVolume - (amount || GlobalConfig.services.audioIncrement));
    }

    function setAudioSink(newSink: PwNode): void {
        Pipewire.preferredDefaultAudioSink = newSink;
    }

    function setAudioSource(newSource: PwNode): void {
        Pipewire.preferredDefaultAudioSource = newSource;
    }

    function cycleNextAudioOutput(): void {
        if (sinks.length === 0)
            return;

        const currentIndex = sinks.findIndex(s => s === sink);
        const nextIndex = (currentIndex + 1) % sinks.length;
        setAudioSink(sinks[nextIndex]);
    }

    function setStreamVolume(stream: PwNode, newVolume: real): void {
        if (stream?.ready && stream?.audio) {
            stream.audio.muted = false;
            stream.audio.volume = Math.max(0, Math.min(GlobalConfig.services.maxVolume, newVolume));
        }
    }

    function setStreamMuted(stream: PwNode, muted: bool): void {
        if (stream?.ready && stream?.audio) {
            stream.audio.muted = muted;
        }
    }

    function getStreamVolume(stream: PwNode): real {
        return stream?.audio?.volume ?? 0;
    }

    function getStreamMuted(stream: PwNode): bool {
        return !!stream?.audio?.muted;
    }

    function getStreamName(stream: PwNode): string {
        if (!stream)
            return Tr.trCtx("Unknown", "unknown audio stream");
        // Try application name first, then description, then name
        return stream.properties["application.name"] || stream.description || stream.name || Tr.trCtx("Unknown application", "unknown application audio stream");
    }

    // Friendly device name for Settings dropdowns and lists.
    function friendlyDeviceName(node: PwNode): string {
        if (!node)
            return Tr.trCtx("Unknown", "unknown audio device");
        const nick = node.properties?.["node.nick"];
        const raw = nick || node.description || node.name || "";
        return raw.replace(/\s*High Definition Audio Controller\b/g, "").replace(/\s{2,}/g, " ").trim() || Tr.trCtx("Unknown", "unknown audio device");
    }

    function moveStreamToSink(stream: PwNode, targetSink: PwNode): void {
        const serial = stream?.properties?.["object.serial"];
        if (serial && targetSink?.name)
            Quickshell.execDetached(["pactl", "move-sink-input", String(serial), targetSink.name]);
    }

    function moveRecordingToSource(stream: PwNode, targetSource: PwNode): void {
        const serial = stream?.properties?.["object.serial"];
        if (serial && targetSource?.name)
            Quickshell.execDetached(["pactl", "move-source-output", String(serial), targetSource.name]);
    }

    function refreshCards(): void {
        if (!cardsProc.running)
            cardsProc.running = true;
    }

    function openCards(): void {
        cardsUsers++;
        refreshCards();
    }

    function closeCards(): void {
        cardsUsers = Math.max(0, cardsUsers - 1);
    }

    function setCardProfile(cardName: string, profileName: string): void {
        if (!cardName || !profileName)
            return;
        setProfileProc.command = ["pactl", "set-card-profile", cardName, profileName];
        setProfileProc.running = false;
        setProfileProc.running = true;
    }

    function refreshNodes(): void {
        const newSinks = [];
        const newSources = [];
        const newStreams = [];
        const newRec = [];

        for (const node of Pipewire.nodes.values) {
            if (!node.isStream) {
                if (node.isSink)
                    newSinks.push(node);
                else if (node.audio)
                    newSources.push(node);
            } else if (node.audio && node.type === PwNodeType.AudioOutStream) {
                newStreams.push(node);
            } else if (node.audio && node.type === PwNodeType.AudioInStream) {
                const app = node.properties?.["application.name"] ?? node.name ?? "";
                if (node.properties?.["stream.monitor"] === "true" || /^(cava|caelestia|quickshell|qs)$/i.test(app))
                    continue;
                newRec.push(node);
            }
        }

        root.sinks = newSinks;
        root.sources = newSources;
        root.streams = newStreams;
        root.recordingStreams = newRec;
    }

    onSinkChanged: {
        if (!sink?.ready)
            return;

        const newSinkName = sink.description || sink.name || Tr.trCtx("Unknown device", "unknown audio device");

        if (previousSinkName && previousSinkName !== newSinkName && GlobalConfig.utilities.toasts.audioOutputChanged)
            Toaster.toast(Tr.tr("Audio output changed"), Tr.tr("Now using: %1").arg(newSinkName), "volume_up");

        previousSinkName = newSinkName;
    }

    onSourceChanged: {
        if (!source?.ready)
            return;

        const newSourceName = source.description || source.name || Tr.trCtx("Unknown device", "unknown audio device");

        if (previousSourceName && previousSourceName !== newSourceName && GlobalConfig.utilities.toasts.audioInputChanged)
            Toaster.toast(Tr.tr("Audio input changed"), Tr.tr("Now using: %1").arg(newSourceName), "mic");

        previousSourceName = newSourceName;
    }

    // Populate immediately: Pipewire.nodes may already be filled by the time this
    // lazily-loaded singleton is created, so onValuesChanged would never fire.
    Component.onCompleted: {
        refreshNodes();
        previousSinkName = sink?.description || sink?.name || Tr.trCtx("Unknown device", "unknown audio device");
        previousSourceName = source?.description || source?.name || Tr.trCtx("Unknown device", "unknown audio device");
    }

    Connections {
        function onValuesChanged(): void {
            root.refreshNodes();
            if (root.cardsUsers > 0)
                cardsRefreshTimer.restart();
        }

        target: Pipewire.nodes
    }

    Timer {
        id: cardsRefreshTimer

        interval: 300
        onTriggered: root.refreshCards()
    }

    Process {
        id: cardsProc

        command: ["pactl", "-f", "json", "list", "cards"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const raw = JSON.parse(text);
                    const out = [];
                    for (const c of Array.isArray(raw) ? raw : []) {
                        const props = c.properties ?? {};
                        const label = String(props["device.description"] || props["alsa.card_name"] || c.name || "").replace(/\s*High Definition Audio Controller\b/g, "").replace(/\s{2,}/g, " ").trim();
                        const profiles = [];
                        for (const [pname, pinfo] of Object.entries(c.profiles ?? {})) {
                            if (pinfo && pinfo.available !== false && pinfo.available !== "no")
                                profiles.push({
                                    name: pname,
                                    description: String(pinfo.description || pname)
                                });
                        }
                        if (profiles.length > 1)
                            out.push({
                                name: String(c.name ?? ""),
                                label: label || String(c.name ?? ""),
                                activeProfile: String(c.active_profile ?? ""),
                                profiles
                            });
                    }
                    // Unchanged: kept (a new list rebuilds the rows, closing an open menu)
                    if (JSON.stringify(out) !== JSON.stringify(root.cards))
                        root.cards = out;
                } catch (e) {}
            }
        }
    }

    Process {
        id: setProfileProc

        onExited: code => {
            if (code === 0) {
                root.refreshCards();
                cardsRefreshTimer.restart();
            }
        }
    }

    // Always track the current defaults so volume/mute bind even if the lists
    // momentarily lag behind the default node.
    PwObjectTracker {
        objects: [root.sink, root.source, ...root.sinks, ...root.sources, ...root.streams, ...root.recordingStreams].filter(n => n)
    }

    CavaProvider {
        id: cava

        bars: GlobalConfig.services.visualiserBars
    }

    BeatTracker {
        id: beatTracker
    }

    IpcHandler {
        function cycleOutput(): void {
            root.cycleNextAudioOutput();
        }

        target: "audio"
    }
}
