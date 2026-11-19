pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import qs.utils

// Bluetooth pairing agent (org.bluez.Agent1 via caelestia-bt-agent):
// handles PIN entry, passkey confirmation, passkey display, and service
// authorization dialogs natively in Caelestia's style.
Singleton {
    id: root

    property var request: null
    readonly property bool active: !!request
    readonly property bool interactive: !!request && request.kind !== "displayPasskey" && request.kind !== "displayPin"

    // Focused Nexus window can host the prompt inline; otherwise BluetoothAgentOverlay shows it.
    property list<Item> hosts: []
    property Item host: null
    property bool decided

    // Never register an agent on the real system D-Bus in test sessions (private-test).
    readonly property bool testSession: Quickshell.env("CAELESTIA_POLKIT_DEMO") === "1"

    function addHost(item: Item): void {
        if (!hosts.includes(item))
            hosts.push(item);
    }

    function removeHost(item: Item): void {
        const i = hosts.indexOf(item);
        if (i >= 0)
            hosts.splice(i, 1);
        if (host === item)
            host = null;
    }

    function pickHost(): void {
        host = hosts.find(h => h.windowActive) ?? null;
        decided = true;
    }

    function clearState(): void {
        request = null;
        decided = false;
        host = null;
    }

    function sendReply(payload: var): void {
        if (agentProc.running && !testSession)
            agentProc.write(JSON.stringify(payload) + "\n");
    }

    function confirm(): void {
        if (!request)
            return;
        if (request.id > 0)
            sendReply({
                id: request.id,
                ok: true
            });
        clearState();
    }

    function submit(value: string): void {
        if (!request)
            return;
        if (request.id > 0)
            sendReply({
                id: request.id,
                ok: true,
                value
            });
        clearState();
    }

    function reject(): void {
        if (!request)
            return;
        if (request.id > 0)
            sendReply({
                id: request.id,
                ok: false,
                reason: "Cancelled"
            });
        clearState();
    }

    function dismiss(): void {
        if (!request)
            return;
        if (interactive)
            reject();
        else
            clearState();
    }

    // Close display-only prompts once pairing succeeds or ends
    Instantiator {
        model: root.request && !root.interactive ? Bluetooth.devices.values : []

        delegate: Connections {
            required property BluetoothDevice modelData

            target: modelData
            function onPairedChanged(): void {
                if (root.request && !root.interactive && modelData.paired && modelData.address === root.request.address)
                    root.clearState();
            }
            function onPairingChanged(): void {
                if (root.request && !root.interactive && !modelData.pairing && !modelData.paired && modelData.address === root.request.address)
                    root.clearState();
            }
        }
    }

    Process {
        id: agentProc

        running: !root.testSession
        stdinEnabled: true
        command: [`${Paths.libdir}/caelestia-bt-agent`]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                let msg;
                try {
                    msg = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (msg.kind === "ready" || msg.kind === "status")
                    return;
                if (msg.kind === "cancel") {
                    if (root.request && root.request.id === msg.id)
                        root.clearState();
                    return;
                }
                const sameDisplay = root.request && root.request.id === 0 && msg.id === 0 && root.request.kind === msg.kind;
                if (!sameDisplay)
                    root.pickHost();
                root.request = msg;
            }
        }
        onExited: {
            if (root.request)
                root.clearState();
            if (!root.testSession)
                restartTimer.start();
        }
    }

    Timer {
        id: restartTimer

        interval: 5000
        onTriggered: if (!root.testSession)
            agentProc.running = true
    }

    IpcHandler {
        function demo(kind: string): void {
            if (!root.testSession)
                return;
            const k = kind || "confirm";
            root.pickHost();
            if (k === "pin")
                root.request = {
                    id: 901,
                    kind: "pin",
                    device: "Keychron K8 Pro",
                    address: "E4:17:D8:12:34:56"
                };
            else if (k === "passkey")
                root.request = {
                    id: 902,
                    kind: "passkey",
                    device: "Logitech MX Keys",
                    address: "DA:52:4B:99:11:22"
                };
            else if (k === "displayPasskey")
                root.request = {
                    id: 0,
                    kind: "displayPasskey",
                    device: "Bluetooth Keyboard",
                    address: "AA:BB:CC:DD:EE:FF",
                    passkey: "482915",
                    entered: 2
                };
            else if (k === "authorize")
                root.request = {
                    id: 903,
                    kind: "authorizeService",
                    device: "Sony WH-1000XM5",
                    address: "14:3F:A6:11:22:33",
                    service: "Audio Output"
                };
            else
                root.request = {
                    id: 900,
                    kind: "confirm",
                    device: "Pixel 9 Pro",
                    address: "9C:76:0E:AA:BB:CC",
                    passkey: "738291"
                };
        }

        function clear(): void {
            if (root.testSession)
                root.clearState();
        }

        target: "bluetoothAgent"
    }
}
