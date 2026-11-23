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
    // Every sound card (including Off / single-profile cards) + per-node port & latency metadata
    property var allCards: []
    property var sinkMeta: ({})
    property var sourceMeta: ({})
    property var sinkInputMeta: ({})
    property var sourceOutputMeta: ({})
    property var monitorSources: []
    property var _pendingMonVol: ({})
    property int _mutationGen: 0
    // Pages showing the cards (openCards/closeCards): only then are they read
    // again on PipeWire changes (each read runs pactl)
    property int cardsUsers: 0
    property int mixerUsers: 0

    property bool beepOnVolumeChange: false
    property bool showMonitors: false
    property string lastMixerTab: ""
    property var channelLocks: ({})
    property real _lastBeepMs: 0

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

    function streamRouteName(kind: string, node: PwNode, linkedDevice: PwNode): string {
        if (!node)
            return "";
        const serial = nodeKey(node);
        if (kind === "playback") {
            const fromPactl = sinkInputMeta[serial]?.sinkName ?? "";
            if (fromPactl)
                return fromPactl;
            return linkedDevice?.name || sink?.name || "";
        }
        const fromPactl = sourceOutputMeta[serial]?.sourceName ?? "";
        if (fromPactl)
            return fromPactl;
        if (node.properties?.["stream.capture.sink"] === "true") {
            const target = String(node.properties?.["target.object"] ?? linkedDevice?.name ?? sink?.name ?? "");
            if (target)
                return target.endsWith(".monitor") ? target : `${target}.monitor`;
        }
        if (linkedDevice)
            return linkedDevice.isSink ? `${linkedDevice.name}.monitor` : (linkedDevice.name ?? "");
        return source?.name ?? "";
    }

    function moveStreamToSink(stream: PwNode, targetSink: PwNode): void {
        const serial = nodeKey(stream);
        if (!serial || !targetSink?.name)
            return;
        const idx = String(sinkInputMeta[serial]?.index ?? serial);
        const next = Object.assign({}, sinkInputMeta);
        next[serial] = {
            index: Number(idx) || 0,
            sinkName: String(targetSink.name)
        };
        sinkInputMeta = next;
        _mutationGen++;
        Quickshell.execDetached(["pactl", "move-sink-input", idx, targetSink.name]);
        cardsRefreshTimer.restart();
    }

    function moveRecordingToSource(stream: PwNode, targetSource: PwNode): void {
        const serial = nodeKey(stream);
        if (serial && targetSource?.name)
            moveRecordingToSourceName(stream, targetSource.name);
    }

    function moveRecordingToSourceName(stream: PwNode, targetSourceName: string): void {
        const serial = nodeKey(stream);
        if (!serial || !targetSourceName)
            return;
        const idx = String(sourceOutputMeta[serial]?.index ?? serial);
        const next = Object.assign({}, sourceOutputMeta);
        next[serial] = {
            index: Number(idx) || 0,
            sourceName: String(targetSourceName)
        };
        sourceOutputMeta = next;
        _mutationGen++;
        Quickshell.execDetached(["pactl", "move-source-output", idx, targetSourceName]);
        cardsRefreshTimer.restart();
    }

    function openMixerRef(): void {
        mixerUsers++;
        openCards();
    }

    function closeMixerRef(): void {
        mixerUsers = Math.max(0, mixerUsers - 1);
        closeCards();
    }

    function runPactlAction(args: var): void {
        _mutationGen++;
        Quickshell.execDetached(["pactl", ...args]);
        cardsRefreshTimer.restart();
    }

    function setSinkPort(sinkName: string, portName: string): void {
        if (!sinkName || !portName)
            return;
        if (sinkMeta[sinkName]) {
            const next = Object.assign({}, sinkMeta);
            next[sinkName] = Object.assign({}, next[sinkName], {
                activePort: portName
            });
            sinkMeta = next;
        }
        runPactlAction(["set-sink-port", sinkName, portName]);
    }

    function setSourcePort(sourceName: string, portName: string): void {
        if (!sourceName || !portName)
            return;
        if (sourceMeta[sourceName]) {
            const next = Object.assign({}, sourceMeta);
            next[sourceName] = Object.assign({}, next[sourceName], {
                activePort: portName
            });
            sourceMeta = next;
        }
        runPactlAction(["set-source-port", sourceName, portName]);
    }

    function setPortLatencyOffset(cardName: string, portName: string, offsetMs: int): void {
        if (!cardName || !portName)
            return;
        const clamped = Math.max(-500, Math.min(2000, Math.round(offsetMs)));
        allCards = (allCards ?? []).map(c => {
            if (c.name !== cardName)
                return c;
            return Object.assign({}, c, {
                ports: (c.ports ?? []).map(p => p.name === portName ? Object.assign({}, p, {
                        latencyOffsetMs: clamped
                    }) : p)
            });
        });
        const nextSinkMeta = Object.assign({}, sinkMeta);
        let sinkChanged = false;
        for (const [k, v] of Object.entries(nextSinkMeta)) {
            if (v && v.cardName === cardName && v.activePort === portName) {
                nextSinkMeta[k] = Object.assign({}, v, {
                    latencyOffsetMs: clamped
                });
                sinkChanged = true;
            }
        }
        if (sinkChanged)
            sinkMeta = nextSinkMeta;
        const nextSourceMeta = Object.assign({}, sourceMeta);
        let srcChanged = false;
        for (const [k, v] of Object.entries(nextSourceMeta)) {
            if (v && v.cardName === cardName && v.activePort === portName) {
                nextSourceMeta[k] = Object.assign({}, v, {
                    latencyOffsetMs: clamped
                });
                srcChanged = true;
            }
        }
        if (srcChanged)
            sourceMeta = nextSourceMeta;
        runPactlAction(["set-port-latency-offset", cardName, portName, String(Math.round(clamped * 1000))]);
    }

    function setMonitorMuted(sourceName: string, muted: bool): void {
        if (!sourceName)
            return;
        monitorSources = (monitorSources ?? []).map(m => m.name === sourceName ? Object.assign({}, m, {
                mute: !!muted
            }) : m);
        runPactlAction(["set-source-mute", sourceName, muted ? "1" : "0"]);
    }

    function setMonitorVolume(sourceName: string, newVolume: real): void {
        if (!sourceName)
            return;
        const maxVol = Math.max(1, GlobalConfig.services.maxVolume);
        const clamped = Math.max(0, Math.min(maxVol, newVolume));
        const pct = Math.round(clamped * 100);
        monitorSources = (monitorSources ?? []).map(m => m.name === sourceName ? Object.assign({}, m, {
                volume: clamped,
                mute: false
            }) : m);
        const pend = Object.assign({}, _pendingMonVol);
        pend[sourceName] = pct;
        _pendingMonVol = pend;
        _mutationGen++;
        monVolTimer.restart();
    }

    function nodeKey(node: PwNode): string {
        return String(node?.properties?.["object.serial"] ?? node?.id ?? "");
    }

    function isChannelLocked(node: PwNode): bool {
        const key = nodeKey(node);
        if (!key)
            return true;
        if (key in channelLocks)
            return !!channelLocks[key];
        const vols = Array.from(node?.audio?.volumes ?? []).map(v => Number(v));
        if (vols.length <= 1)
            return true;
        return (Math.max(...vols) - Math.min(...vols)) <= 0.005;
    }

    function setChannelLocked(node: PwNode, locked: bool): void {
        const key = nodeKey(node);
        if (!key)
            return;
        const next = Object.assign({}, channelLocks);
        next[key] = !!locked;
        channelLocks = next;
        if (locked && node?.ready && node?.audio) {
            const vols = Array.from(node.audio.volumes ?? []).map(v => Number(v));
            if (vols.length > 1) {
                const target = vols.reduce((a, b) => a + b, 0) / vols.length;
                node.audio.volumes = vols.map(() => target);
            } else {
                node.audio.volume = node.audio.volume;
            }
        }
    }

    function setNodeVolume(node: PwNode, newVolume: real): void {
        if (!node?.ready || !node?.audio)
            return;
        const maxVol = Math.max(1, GlobalConfig.services.maxVolume);
        node.audio.muted = false;
        node.audio.volume = Math.max(0, Math.min(maxVol, newVolume));
    }

    function setNodeChannelVolume(node: PwNode, channelIdx: int, newVolume: real): void {
        if (!node?.ready || !node?.audio)
            return;
        const maxVol = Math.max(1, GlobalConfig.services.maxVolume);
        const next = Array.from(node.audio.volumes ?? []).map(v => Number(v));
        if (channelIdx < 0 || channelIdx >= next.length)
            return;
        next[channelIdx] = Math.max(0, Math.min(maxVol, newVolume));
        node.audio.muted = false;
        node.audio.volumes = next;
    }

    function channelName(ch: int): string {
        switch (ch) {
        case PwAudioChannel.Mono:
            return Tr.tr("Mono");
        case PwAudioChannel.FrontCenter:
            return Tr.tr("Front Center");
        case PwAudioChannel.FrontLeft:
            return Tr.tr("Front Left");
        case PwAudioChannel.FrontRight:
            return Tr.tr("Front Right");
        case PwAudioChannel.FrontLeftCenter:
            return Tr.tr("Front Left Center");
        case PwAudioChannel.FrontRightCenter:
            return Tr.tr("Front Right Center");
        case PwAudioChannel.LowFrequencyEffects:
            return Tr.tr("Subwoofer");
        case PwAudioChannel.SideLeft:
            return Tr.tr("Side Left");
        case PwAudioChannel.SideRight:
            return Tr.tr("Side Right");
        case PwAudioChannel.RearCenter:
            return Tr.tr("Rear Center");
        case PwAudioChannel.RearLeft:
            return Tr.tr("Rear Left");
        case PwAudioChannel.RearRight:
            return Tr.tr("Rear Right");
        default: {
            const raw = String(PwAudioChannel.toString(ch) ?? "");
            return raw ? raw.replace(/([a-z])([A-Z])/g, "$1 $2") : Tr.tr("Channel");
        }
        }
    }

    function volumeDb(v: real): string {
        const n = Number(v ?? 0);
        if (!(n > 0.0001))
            return Tr.tr("-∞ dB");
        return `${(60 * Math.log10(n)).toFixed(1)} dB`;
    }

    function playVolumeBeep(): void {
        if (!beepOnVolumeChange)
            return;
        const now = Date.now();
        if (now - _lastBeepMs < 140)
            return;
        _lastBeepMs = now;
        Quickshell.execDetached(["pw-play", "/usr/share/sounds/freedesktop/stereo/audio-volume-change.oga"]);
    }

    function parseLatencyMs(raw: var): int {
        const usec = parseInt(String(raw ?? "0").replace(/[^-\d]/g, ""), 10) || 0;
        return Math.round(usec / 1000);
    }

    function refreshCards(): void {
        if (!cardsProc.running) {
            cardsProc.capturedGen = root._mutationGen;
            cardsProc.running = true;
        } else {
            cardsRefreshTimer.restart();
        }
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
                if (node.properties?.["stream.monitor"] === "true" || /^(cava|caelestia|caelestia-meter|quickshell|qs)$/i.test(app))
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

        interval: 150
        onTriggered: root.refreshCards()
    }

    Timer {
        id: monVolTimer

        interval: 60
        onTriggered: {
            const pend = root._pendingMonVol;
            root._pendingMonVol = ({});
            for (const [sname, pct] of Object.entries(pend))
                Quickshell.execDetached(["pactl", "set-source-volume", sname, `${pct}%`]);
            cardsRefreshTimer.restart();
        }
    }

    Process {
        id: cardsProc

        property int capturedGen: 0

        command: ["sh", "-c", "printf '{\"cards\":'; pactl -f json list cards 2>/dev/null || printf '[]'; printf ',\"sinks\":'; pactl -f json list sinks 2>/dev/null || printf '[]'; printf ',\"sources\":'; pactl -f json list sources 2>/dev/null || printf '[]'; printf ',\"sinkInputs\":'; pactl -f json list sink-inputs 2>/dev/null || printf '[]'; printf ',\"sourceOutputs\":'; pactl -f json list source-outputs 2>/dev/null || printf '[]'; printf '}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (cardsProc.capturedGen !== root._mutationGen) {
                    cardsRefreshTimer.restart();
                    return;
                }
                try {
                    const data = JSON.parse(text);
                    const out = [];
                    const fullCards = [];
                    const cardPortMap = {};

                    for (const c of Array.isArray(data.cards) ? data.cards : []) {
                        const props = c.properties ?? {};
                        const cname = String(c.name ?? "");
                        const label = String(props["device.description"] || props["alsa.card_name"] || cname).replace(/\s*High Definition Audio Controller\b/g, "").replace(/\s{2,}/g, " ").trim();
                        const availProfiles = [];
                        const allProfiles = [];
                        for (const [pname, pinfo] of Object.entries(c.profiles ?? {})) {
                            if (!pinfo)
                                continue;
                            const available = pinfo.available !== false && pinfo.available !== "no";
                            const desc = String(pinfo.description || pname);
                            allProfiles.push({
                                name: pname,
                                description: desc,
                                available
                            });
                            if (available)
                                availProfiles.push({
                                    name: pname,
                                    description: desc
                                });
                        }
                        const portsList = [];
                        const pMap = {};
                        for (const [portName, portInfo] of Object.entries(c.ports ?? {})) {
                            if (!portInfo)
                                continue;
                            const latMs = root.parseLatencyMs(portInfo.latency_offset);
                            pMap[portName] = latMs;
                            portsList.push({
                                name: portName,
                                description: String(portInfo.description || portName),
                                availability: String(portInfo.availability ?? ""),
                                latencyOffsetMs: latMs
                            });
                        }
                        cardPortMap[cname] = pMap;
                        fullCards.push({
                            name: cname,
                            label: label || cname,
                            activeProfile: String(c.active_profile ?? ""),
                            profiles: allProfiles,
                            ports: portsList
                        });
                        if (availProfiles.length > 1)
                            out.push({
                                name: cname,
                                label: label || cname,
                                activeProfile: String(c.active_profile ?? ""),
                                profiles: availProfiles
                            });
                    }

                    const nextSinkMeta = {};
                    const sinkSerialByName = {};
                    const sinkNameByIndex = {};
                    const sinkFriendlyByName = {};
                    for (const s of Array.isArray(data.sinks) ? data.sinks : []) {
                        const sname = String(s.name ?? "");
                        const props = s.properties ?? {};
                        const cname = String(props["device.name"] ?? "");
                        const activePort = String(s.active_port ?? "");
                        const serial = String(props["object.serial"] ?? s.index ?? "");
                        if (sname && serial)
                            sinkSerialByName[sname] = serial;
                        if (s.index !== undefined && s.index !== null && sname)
                            sinkNameByIndex[String(s.index)] = sname;
                        const rawFriendly = String(props["node.nick"] || s.description || sname);
                        sinkFriendlyByName[sname] = rawFriendly.replace(/\s*High Definition Audio Controller\b/g, "").replace(/\s{2,}/g, " ").trim() || sname;
                        const ports = (Array.isArray(s.ports) ? s.ports : []).map(p => ({
                            name: String(p.name ?? ""),
                            description: String(p.description || p.name || ""),
                            availability: String(p.availability ?? "")
                        }));
                        nextSinkMeta[sname] = {
                            cardName: cname,
                            activePort,
                            ports,
                            latencyOffsetMs: cardPortMap[cname]?.[activePort] ?? 0
                        };
                    }

                    const nextSourceMeta = {};
                    const sourceNameByIndex = {};
                    const nextMonitors = [];
                    for (const src of Array.isArray(data.sources) ? data.sources : []) {
                        const sname = String(src.name ?? "");
                        const props = src.properties ?? {};
                        const cname = String(props["device.name"] ?? "");
                        const activePort = String(src.active_port ?? "");
                        const monOf = String(src.monitor_source ?? "");
                        const isMonitor = !!monOf || sname.endsWith(".monitor");
                        if (src.index !== undefined && src.index !== null && sname)
                            sourceNameByIndex[String(src.index)] = sname;
                        const ports = (Array.isArray(src.ports) ? src.ports : []).map(p => ({
                            name: String(p.name ?? ""),
                            description: String(p.description || p.name || ""),
                            availability: String(p.availability ?? "")
                        }));
                        nextSourceMeta[sname] = {
                            cardName: cname,
                            activePort,
                            ports,
                            latencyOffsetMs: cardPortMap[cname]?.[activePort] ?? 0,
                            isMonitor,
                            monitorOf: monOf
                        };
                        if (isMonitor) {
                            const targetSink = monOf || sname.replace(/\.monitor$/, "");
                            const vols = Object.values(src.volume ?? {});
                            const pctStr = vols.length > 0 ? String(vols[0].value_percent ?? "100%") : "100%";
                            const pct = Math.max(0, (parseInt(pctStr, 10) || 0) / 100);
                            const friendlyLabel = sinkFriendlyByName[targetSink] || String(src.description || sname).replace(/^Monitor of\s+/i, "").replace(/\s*High Definition Audio Controller\b/g, "").replace(/\s{2,}/g, " ").trim();
                            nextMonitors.push({
                                name: sname,
                                description: String(src.description || sname),
                                friendlyLabel,
                                sinkName: targetSink,
                                sinkSerial: sinkSerialByName[targetSink] ?? "",
                                cardName: cname,
                                mute: !!src.mute,
                                volume: pct
                            });
                        }
                    }

                    const nextSinkInputs = {};
                    for (const si of Array.isArray(data.sinkInputs) ? data.sinkInputs : []) {
                        const props = si.properties ?? {};
                        const serial = String(props["object.serial"] ?? si.index ?? "");
                        if (!serial)
                            continue;
                        nextSinkInputs[serial] = {
                            index: Number(si.index ?? serial),
                            sinkName: sinkNameByIndex[String(si.sink)] ?? ""
                        };
                    }

                    const nextSourceOutputs = {};
                    for (const so of Array.isArray(data.sourceOutputs) ? data.sourceOutputs : []) {
                        const props = so.properties ?? {};
                        const serial = String(props["object.serial"] ?? so.index ?? "");
                        if (!serial)
                            continue;
                        nextSourceOutputs[serial] = {
                            index: Number(so.index ?? serial),
                            sourceName: sourceNameByIndex[String(so.source)] ?? ""
                        };
                    }

                    // Unchanged: kept (a new list rebuilds the rows, closing an open menu)
                    if (JSON.stringify(out) !== JSON.stringify(root.cards))
                        root.cards = out;
                    if (JSON.stringify(fullCards) !== JSON.stringify(root.allCards))
                        root.allCards = fullCards;
                    if (JSON.stringify(nextSinkMeta) !== JSON.stringify(root.sinkMeta))
                        root.sinkMeta = nextSinkMeta;
                    if (JSON.stringify(nextSourceMeta) !== JSON.stringify(root.sourceMeta))
                        root.sourceMeta = nextSourceMeta;
                    if (JSON.stringify(nextMonitors) !== JSON.stringify(root.monitorSources))
                        root.monitorSources = nextMonitors;
                    if (JSON.stringify(nextSinkInputs) !== JSON.stringify(root.sinkInputMeta))
                        root.sinkInputMeta = nextSinkInputs;
                    if (JSON.stringify(nextSourceOutputs) !== JSON.stringify(root.sourceOutputMeta))
                        root.sourceOutputMeta = nextSourceOutputs;
                } catch (e) {
                    console.warn("Audio: failed to parse pactl snapshot:", e);
                }
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

        function openMixer(): void {
            const s = ShellState.forActive();
            if (!s)
                return;
            if (s.osd && s.osdExpanded) {
                s.osdExpanded = false;
                s.osd = false;
            } else {
                s.osdExpanded = true;
                s.osd = true;
            }
        }

        function openDashboardMixer(): void {
            const s = ShellState.forActive();
            if (!s)
                return;
            s.dashboardQuickDetail = "audio";
            s.dashboardRequest = "quick";
        }

        target: "audio"
    }
}
