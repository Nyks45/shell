pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.utils

Singleton {
    id: root

    property bool connected: false
    property var status: ({
            connected: false,
            state: "disconnected",
            reason: "",
            authUrl: "",
            server: ""
        })

    property bool connectPending: false
    property bool disconnectPending: false
    readonly property bool connecting: connectProc.running || connectPending
    readonly property bool disconnecting: disconnectProc.running || disconnectPending

    // Internal id of the currently selected provider (persisted). Only one
    // provider can be selected at a time; empty means none. Keyed by id rather
    // than name so the selection survives renames.
    readonly property string selectedProvider: GlobalConfig.utilities.vpn.selectedProvider

    // Live connection stats, refreshed on demand by the UI via refreshStats().
    property double connectedSince: 0
    property string bytesIn: ""
    property string bytesOut: ""
    property int pingMs: -1
    property string serverLocation: ""

    // Tracks an in-flight provider switch (by id) that must wait for disconnect.
    property string pendingSwitchProvider: ""
    property bool pendingConnectAfterSelect: false

    // Tracks on-demand registration (e.g. Cloudflare WARP TOS registration).
    property bool connectAfterRegister: false
    property bool registerAttempted: false

    // CLI binary & systemd daemon availability (plain JS objects; avoid Map in QML).
    property var cliInstalled: ({})
    property var serviceStates: ({})
    property bool availabilityChecked: false

    // Per-app VPN split tunneling state (driven by caelestia-vpn-split).
    property string splitMode: "all" // "all", "include", "exclude"
    property var splitApps: []
    property bool splitActive: false
    property bool splitServiceActive: false
    property string splitVpnIface: ""
    property string splitUplinkIface: ""
    property int splitMatchedPids: 0
    property var splitRunningByApp: ({})
    property bool splitLoaded: false
    property bool splitBusy: false

    // To track whether connect/disconnect/status procs actually ran
    property bool connectExited
    property bool disconnectExited
    property bool statusExited

    // For auto connect on init from config
    property bool autoConnectPending

    // The selected provider entry, or null when nothing valid is selected.
    readonly property var selected: root.providers.find(p => p.id === root.selectedProvider) ?? null

    // The single point where every configured provider - a customised built-in
    // or a fully user-defined entry - is folded into one uniform endpoint
    // object. Built-in knowledge lives in the adapters below; config values
    // override adapter defaults; anything unknown falls back to generic
    // `<name> up/down` commands with an interface-presence status check.
    // Everything downstream runs off this object and never branches on a
    // provider name.
    readonly property var active: {
        const custom = root.selected;
        const name = custom ? (custom.name || "custom") : "wireguard";
        const adapter = adapters.find(a => a.name === name) ?? null;
        const iface = (custom ? custom.interface : "") || (adapter ? adapter.iface : "") || (adapter ? "" : name);
        const resolve = c => typeof c === "function" ? c(iface) : c;
        return {
            name: name,
            displayName: (custom ? custom.displayName : "") || resolve(adapter ? adapter.display : null) || name,
            interface: iface,
            connectCmd: (custom && custom.connectCmd.length > 0 ? custom.connectCmd : resolve(adapter ? adapter.connectCmd : null)) || [name, "up"],
            disconnectCmd: (custom && custom.disconnectCmd.length > 0 ? custom.disconnectCmd : resolve(adapter ? adapter.disconnectCmd : null)) || [name, "down"],
            statusCmd: resolve(adapter ? adapter.statusCmd : null) || ["ip", "link", "show"],
            parse: (adapter ? adapter.parse : null) ? (out => adapter.parse(out, iface)) : (out => root.parseInterfaceStatus(out, iface)),
            service: adapter ? adapter.service : `${name}d`,
            cliBin: adapter ? adapter.cliBin : "",
            pkgName: adapter ? adapter.pkgName : "",
            pkgSource: adapter ? adapter.pkgSource : "repo",
            pkgLabel: adapter ? adapter.pkgLabel : "",
            connectHint: adapter ? adapter.connectHint : null,
            registerCmd: adapter ? adapter.registerCmd : null,
            serverCmd: adapter ? adapter.serverCmd : null,
            parseServer: adapter ? adapter.parseServer : null
        };
    }

    readonly property bool activeCliMissing: availabilityChecked && active.cliBin.length > 0 && !isInstalled(active.name)
    readonly property bool activeServiceStopped: availabilityChecked && !activeCliMissing && active.service.length > 0 && active.service !== "NetworkManager" && serviceStates[active.service] !== undefined && serviceStates[active.service] !== "active"
    readonly property string activeServiceUnit: active.service
    readonly property string activeDevice: (status.device && status.device.length > 0) ? status.device : active.interface

    // Kept as thin readouts for the UI.
    readonly property string providerName: active.name
    readonly property string interfaceName: active.interface
    readonly property var currentConfig: active

    readonly property var adapters: [wireguardAdapter, nmAdapter, warpAdapter, netbirdAdapter, tailscaleAdapter]

    // Live list of configured providers, straight from the typed config list.
    // Each entry is a config node with id/name/displayName/interface and the
    // optional connect/disconnect commands.
    readonly property var providers: GlobalConfig.utilities.vpn.provider.values

    // Provider entry keys which are cleared when empty instead of written.
    readonly property list<string> optionalKeys: ["displayName", "interface", "connectCmd", "disconnectCmd"]

    // Generate a stable, opaque internal id for a provider entry.
    function generateId(): string {
        return `vpn-${Date.now().toString(36)}-${Math.floor(Math.random() * 0x1000000).toString(36)}`;
    }

    // Write a value to a provider entry, clearing the option when empty so the
    // config stays sparse.
    function setOrReset(provider: var, key: string, value: var): void {
        if (value.length > 0)
            provider[key] = value;
        else
            provider.resetOption(key);
    }

    // Build the props for a new provider entry, omitting empty optional values.
    // `id` is the provider's stable internal id.
    function buildProviderProps(id: string, data: var): var {
        const props = {
            id: id,
            name: data.name
        };
        for (const key of root.optionalKeys)
            if (data[key].length > 0)
                props[key] = data[key];
        return props;
    }

    // Resolve the stable internal id of the provider entry at `index`.
    function providerIdAt(index: int): string {
        return GlobalConfig.utilities.vpn.provider.at(index)?.id ?? "";
    }

    // Add a new provider. data: { name, displayName, interface, connectCmd[],
    // disconnectCmd[] }. Newly added providers are not selected by default.
    function addProvider(data: var): void {
        GlobalConfig.utilities.vpn.provider.insert(root.buildProviderProps(root.generateId(), data));
    }

    // Update an existing provider (by index), preserving its internal id so the
    // selection sticks even when the name changes.
    function updateProvider(index: int, data: var): void {
        const provider = GlobalConfig.utilities.vpn.provider.at(index);
        if (!provider)
            return;
        if (provider.id.length === 0)
            provider.id = root.generateId();
        provider.name = data.name;
        for (const key of root.optionalKeys)
            root.setOrReset(provider, key, data[key]);
    }

    // Delete a provider by index. ensureSelection() re-homes the selection to
    // the first remaining provider if the deleted one was selected.
    function deleteProvider(index: int): void {
        GlobalConfig.utilities.vpn.provider.remove(index);
    }

    // Make the provider at `index` the selected one. If a VPN is currently
    // connected, disconnect first, switch, then reconnect.
    function setActiveProvider(index: int): void {
        const id = root.providerIdAt(index);
        if (id.length === 0)
            return;
        if (root.connected) {
            root.pendingSwitchProvider = id;
            root.disconnect();
        } else {
            applySelectedProvider(id);
        }
    }

    function adapterFor(typeId: string): var {
        return adapters.find(a => a.name === typeId) ?? null;
    }

    function isInstalled(typeId: string): bool {
        if (!availabilityChecked)
            return true;
        const adapter = adapterFor(typeId);
        if (!adapter || !adapter.cliBin)
            return true;
        return cliInstalled[adapter.cliBin] === true;
    }

    function isServiceActive(typeId: string): bool {
        if (!availabilityChecked)
            return true;
        const adapter = adapterFor(typeId);
        if (!adapter || !adapter.service)
            return true;
        const st = serviceStates[adapter.service];
        return st === undefined || st === "active";
    }

    function refreshAvailability(): void {
        availProc.running = false;
        availProc.running = true;
    }

    function applySelectedProvider(id: string): void {
        GlobalConfig.utilities.vpn.selectedProvider = id;
    }

    // Guarantee there is always a valid selection while any provider exists: if
    // the stored id matches no configured provider, fall back to the first one
    // (or clear it when the list is empty).
    function ensureSelection(): void {
        const providers = root.providers;
        if (providers.some(p => p.id === root.selectedProvider))
            return;
        const next = providers.length > 0 ? providers[0].id : "";
        if (next !== root.selectedProvider)
            GlobalConfig.utilities.vpn.selectedProvider = next;
    }

    function connectProvider(id: string): void {
        if (!id)
            return;
        if (id === root.selectedProvider) {
            root.connect();
        } else if (root.connected) {
            root.pendingSwitchProvider = id;
            root.disconnect();
        } else {
            root.pendingConnectAfterSelect = true;
            applySelectedProvider(id);
        }
    }

    function connect(): void {
        if (activeCliMissing) {
            reportConnectFailure(Tr.tr("%1 is not installed").arg(active.displayName), "missing-cli");
            return;
        }
        if (activeServiceStopped || status.state === "service-stopped") {
            reportConnectFailure(Tr.tr("%1 service is not running").arg(active.displayName), "service-stopped");
            return;
        }
        if (status.state === "needs-auth" && active.registerCmd && !registerProc.running) {
            connectAfterRegister = true;
            connectPending = true;
            registerAttempted = true;
            registerProc.errText = "";
            registerProc.exec(active.registerCmd);
            return;
        }
        if (status.state === "needs-auth" && status.authUrl) {
            emitStatusToast(status, status.state);
            return;
        }
        if (!connected && !connecting) {
            connectPending = true;
            connectProc.errText = "";
            connectProc.outText = "";
            connectProc.exec(active.connectCmd);
        }
    }

    function disconnect(): void {
        if (connected && !connecting) {
            disconnectPending = true;
            disconnectProc.exec(active.disconnectCmd);
        }
    }

    function toggle(): void {
        connected ? disconnect() : connect();
    }

    function reportConnectFailure(reason: string, nextState = "error"): void {
        connectPending = false;
        connected = false;
        status = {
            connected: false,
            state: nextState,
            reason: reason,
            authUrl: "",
            server: ""
        };
        connectedChanged(); // Force bindings to reeval (mainly for switches)
        if (GlobalConfig.utilities.toasts.vpnChanged)
            Toaster.toast(Tr.tr("VPN connection failed"), reason, "vpn_key_alert");
    }

    function reportDisconnectFailure(reason: string): void {
        disconnectPending = false;
        connectedChanged(); // Force bindings to reeval (mainly for switches)
        if (GlobalConfig.utilities.toasts.vpnChanged)
            Toaster.toast(Tr.tr("VPN disconnection failed"), reason, "vpn_key_alert");
    }

    function checkStatus(): void {
        if (root.selectedProvider.length === 0)
            return;
        if (root.activeCliMissing) {
            updateStatus({
                connected: false,
                state: "missing-cli",
                reason: Tr.mark("%1 is not installed", [root.active.displayName]),
                authUrl: "",
                server: ""
            });
            return;
        }
        if (statusProc.running)
            return;
        statusProc.outText = "";
        statusProc.errText = "";
        statusProc.exitCode = 0;
        statusProc.pending = 3;
        statusProc.running = true;
    }

    // Refresh live In/Out byte counters, tunnel latency and - for providers
    // that expose one - the server location.
    function refreshStats(): void {
        if (!connected)
            return;
        const dev = activeDevice;
        if (dev.length > 0) {
            statsProc.command = ["sh", "-c", 'cat "/sys/class/net/$1/statistics/rx_bytes" "/sys/class/net/$1/statistics/tx_bytes" 2>/dev/null', "_", dev];
            statsProc.running = true;
            // Measure latency over the tunnel by binding the ping to the VPN
            // interface (-I), so the result reflects the VPN path, not the LAN.
            if (!pingProc.running) {
                pingProc.command = ["sh", "-c", 'ping -c1 -W2 -I "$1" 1.1.1.1 2>/dev/null || ping -c1 -W2 1.1.1.1 2>/dev/null', "_", dev];
                pingProc.running = true;
            }
        }
        if (active.serverCmd && serverLocation.length === 0)
            serverProc.exec(active.serverCmd);
    }

    function parseTailscaleStatus(output: string): var {
        const status = {
            connected: false,
            state: "disconnected",
            reason: "",
            authUrl: "",
            server: ""
        };

        // Handle empty or whitespace-only output
        if (!output || output.trim().length === 0) {
            return status;
        }

        // Check for common non-JSON states first
        if (output.includes("Logged out") || output.includes("Stopped") || output.includes("not running") || output.includes("Tailscale is not running")) {
            status.state = "disconnected";
            return status;
        }

        // Try to parse as JSON
        try {
            const data = JSON.parse(output);
            const backendState = data.BackendState || "";

            if (backendState === "Running") {
                status.connected = true;
                status.state = "connected";

                // Exit node, if one is in use, is the most meaningful "server".
                try {
                    const peers = data.Peer || {};
                    for (const key in peers) {
                        const p = peers[key];
                        if (p && p.ExitNode) {
                            status.server = (p.DNSName || p.HostName || "").replace(/\.$/, "");
                            break;
                        }
                    }
                } catch (e2) {}
            } else if (backendState === "Starting") {
                status.state = "connecting";
            } else if (backendState === "NeedsLogin" || backendState === "NeedsMachineAuth") {
                status.state = "needs-auth";
                status.reason = backendState === "NeedsLogin" ? Tr.mark("Login required") : Tr.mark("Machine authorisation required");
                status.authUrl = data.AuthURL || "";
            }
        } catch (e) {
            // JSON parsing failed - treat as disconnected unless it looks like an error
            if (output.includes("error") || output.includes("Error") || output.includes("failed")) {
                status.state = "disconnected";
                status.reason = Tr.mark("Tailscale may not be running");
            } else {
                status.state = "disconnected";
            }
        }
        return status;
    }

    function parseNetBirdStatus(output: string): var {
        const status = {
            connected: false,
            state: "disconnected",
            reason: "",
            authUrl: "",
            server: ""
        };
        try {
            const data = JSON.parse(output);
            const mgmtConnected = data.management?.connected;
            const signalConnected = data.signal?.connected;

            if (mgmtConnected && signalConnected) {
                status.connected = true;
                status.state = "connected";
                // The management server URL is the most stable "server" value.
                const url = data.management?.url || data.management?.URL || "";
                if (url)
                    status.server = url.replace(/^https?:\/\//, "").replace(/:\d+$/, "");
            } else if (data.management?.error) {
                const error = data.management.error;
                if (error.includes("auth") || error.includes("login")) {
                    status.state = "needs-auth";
                    status.reason = Tr.mark("Authentication required");
                } else {
                    status.reason = error;
                }
            }
        } catch (e) {
            status.state = "error";
            status.reason = Tr.mark("Failed to parse status");
        }
        return status;
    }

    function parseWarpStatus(output: string): var {
        if (!output || output.trim().length === 0)
            return null;

        const status = {
            connected: false,
            state: "disconnected",
            reason: "",
            authUrl: "",
            server: ""
        };

        // Check daemon-down first ("Unable to connect to the CloudflareWARP daemon").
        if (output.includes("Unable to connect to the CloudflareWARP") || output.includes("daemon is not running") || output.includes("warp-svc")) {
            status.state = "service-stopped";
            status.reason = Tr.mark("Cloudflare WARP service is not running");
        } else if (output.includes("Registration Missing") || output.includes("Missing registration") || output.includes("registration") || output.includes("register")) {
            status.state = "needs-auth";
            status.reason = Tr.mark("WARP registration required");
        } else if (output.includes("Unable")) {
            const m = output.match(/Reason:\s*(.+)/);
            status.state = "error";
            status.reason = m ? m[1].trim() : Tr.mark("WARP connection unable");
        } else if (output.includes("Disconnected")) {
            status.state = "disconnected";
        } else if (output.includes("Connecting")) {
            status.state = "connecting";
        } else if (output.includes("Connected")) {
            status.connected = true;
            status.state = "connected";
        } else {
            status.state = "error";
            status.reason = Tr.mark("Unknown WARP status");
        }
        return status;
    }

    // Generic status for providers without a status command: the tunnel is up
    // if its interface shows up in `ip link show`.
    function parseInterfaceStatus(output: string, iface: string): var {
        const status = {
            connected: false,
            state: "disconnected",
            reason: "",
            authUrl: "",
            server: ""
        };

        if (iface && output.includes(iface + ":")) {
            status.connected = true;
            status.state = "connected";
        }
        return status;
    }

    function parseNmVpnStatus(output: string, connName: string): var {
        const status = {
            connected: false,
            state: "disconnected",
            reason: "",
            authUrl: "",
            server: ""
        };
        if (!connName)
            return status;
        for (const raw of (output || "").split("\n")) {
            if (!raw)
                continue;
            const fields = [];
            let cur = "";
            for (let i = 0; i < raw.length; i++) {
                if (raw[i] === "\\" && i + 1 < raw.length && (raw[i + 1] === ":" || raw[i + 1] === "\\")) {
                    cur += raw[++i];
                } else if (raw[i] === ":") {
                    fields.push(cur);
                    cur = "";
                } else {
                    cur += raw[i];
                }
            }
            fields.push(cur);
            if (fields[0] === connName && (fields[3] === "activated" || fields[3] === "activating")) {
                status.connected = fields[3] === "activated";
                status.state = status.connected ? "connected" : "connecting";
                status.device = fields[2] || "";
                break;
            }
        }
        return status;
    }

    function parseWarpServer(output: string): string {
        let colo = "";
        let endpoint = "";
        for (const line of output.split("\n")) {
            if (!colo) {
                const cm = line.match(/Colo:\s*([A-Za-z0-9_-]+)/i);
                if (cm)
                    colo = cm[1];
            }
            if (!endpoint) {
                const em = line.match(/Endpoints?:\s*([^\s,]+)/i);
                if (em)
                    endpoint = em[1];
            }
        }
        return colo || endpoint;
    }

    function extractAuthUrl(text: string): string {
        const urlMatch = text.match(/(https?:\/\/[^\s]+)/);
        return urlMatch ? urlMatch[1] : "";
    }

    function createAuthStatus(authUrl: string): var {
        return {
            connected: false,
            state: "needs-auth",
            reason: Tr.mark("Authentication required"),
            authUrl: authUrl,
            server: ""
        };
    }

    function updateStatus(newStatus: var): void {
        if (!newStatus)
            return;
        const oldState = status.state;
        if (newStatus.state === "needs-auth" && !newStatus.authUrl && status.authUrl) {
            newStatus.authUrl = status.authUrl;
        }

        status = newStatus;
        root.connected = newStatus.connected;
        if (newStatus.state === "connected")
            root.registerAttempted = false;

        // A fresh status is authoritative; drop any in-flight connect/disconnect wait.
        root.connectPending = false;
        root.disconnectPending = false;

        // Surface a server parsed straight out of the status output; providers
        // with a dedicated server command fill this via refreshStats() instead.
        if (newStatus.connected && newStatus.server)
            root.serverLocation = newStatus.server;

        if (oldState !== newStatus.state) {
            emitStatusToast(newStatus, oldState);
        }

        if (newStatus.state === "connecting")
            statusCheckTimer.restart();

        // Auto connect if config was enabled on init
        if (root.autoConnectPending) {
            root.autoConnectPending = false;
            if (!newStatus.connected)
                root.connect();
        }
    }

    function emitStatusToast(statusObj: var, oldState: string): void {
        if (!GlobalConfig.utilities.toasts.vpnChanged)
            return;

        const displayName = active.displayName || Tr.tr("VPN");

        switch (statusObj.state) {
        case "connected":
            Toaster.toast(Tr.tr("VPN connected"), Tr.tr("Connected to %1").arg(displayName), "vpn_key");
            break;
        case "disconnected":
            if (oldState === "connected" || oldState === "connecting")
                Toaster.toast(Tr.tr("VPN disconnected"), Tr.tr("Disconnected from %1").arg(displayName), "vpn_key_off");
            break;
        case "needs-auth":
            {
                const authMsg = statusObj.reason ? Tr.trMarked(statusObj.reason) : Tr.tr("Authentication required");
                Toaster.toast(Tr.tr("VPN authentication required"), Tr.trCtx("%1: %2", "vpn name and reason").arg(displayName).arg(authMsg), "vpn_lock");
                break;
            }
        case "service-stopped":
            {
                const svcMsg = statusObj.reason ? Tr.trMarked(statusObj.reason) : Tr.tr("Service not running");
                Toaster.toast(Tr.tr("VPN service stopped"), Tr.trCtx("%1: %2", "vpn name and reason").arg(displayName).arg(svcMsg), "error");
                break;
            }
        case "error":
            if (oldState === "connected" || oldState === "connecting" || oldState === "needs-auth" || root.connectPending) {
                const errMsg = statusObj.reason ? Tr.trMarked(statusObj.reason) : Tr.tr("Unknown error");
                Toaster.toast(Tr.tr("VPN error"), Tr.trCtx("%1: %2", "vpn name and reason").arg(displayName).arg(errMsg), "error");
            }
            break;
        }
    }

    // Backfill a stable internal id for entries that lack one (hand-written
    // config entries). Runs once at startup.
    function ensureProviderIds(): void {
        for (const provider of root.providers)
            if (provider.id.length === 0)
                provider.id = root.generateId();
    }

    onConnectedChanged: {
        // Stamp / clear the connection start time and the per-connection stats.
        if (connected) {
            if (connectedSince === 0)
                connectedSince = Date.now();
            Qt.callLater(() => root.refreshStats());
        } else {
            connectedSince = 0;
            bytesIn = "";
            bytesOut = "";
            serverLocation = "";
            pingMs = -1;
        }

        // Update config flag, but not on provider switch
        if (pendingSwitchProvider.length === 0 && GlobalConfig.utilities.vpn.enabled !== connected)
            GlobalConfig.utilities.vpn.enabled = connected;

        if (!connected && pendingSwitchProvider.length > 0) {
            const id = pendingSwitchProvider;
            pendingSwitchProvider = "";
            Qt.callLater(() => {
                root.pendingConnectAfterSelect = true;
                applySelectedProvider(id);
            });
        }
        Qt.callLater(() => root.refreshSplit());
    }

    onStatusChanged: {
        // Providers that can self-register (WARP) do so on demand (once per selection/cycle).
        if (status.state === "needs-auth" && active.registerCmd && !registerProc.running && !registerAttempted) {
            registerAttempted = true;
            registerProc.errText = "";
            registerProc.exec(active.registerCmd);
        }
    }

    onProvidersChanged: root.ensureSelection()

    onSelectedProviderChanged: {
        status = {
            connected: false,
            state: "disconnected",
            reason: "",
            authUrl: "",
            server: ""
        };
        root.connected = false;
        root.connectPending = false;
        root.disconnectPending = false;
        root.connectAfterRegister = false;
        root.registerAttempted = false;
        root.serverLocation = "";
        root.bytesIn = "";
        root.bytesOut = "";
        root.pingMs = -1;
        if (root.pendingConnectAfterSelect) {
            root.pendingConnectAfterSelect = false;
            Qt.callLater(() => root.connect());
        } else {
            statusCheckTimer.start();
        }
    }

    function refreshSplit(): void {
        splitStatusProc.running = false;
        splitStatusProc.running = true;
    }

    function applySplit(mode: string, apps: var, done: var): void {
        splitBusy = true;
        const payload = JSON.stringify({
            mode: mode || "all",
            apps: apps ?? []
        });
        Admin.exec(["pkexec", Admin.helper, "vpn-split", "apply"], Tr.tr("Update VPN app routing"), (ok, out, cancelled) => {
            splitBusy = false;
            refreshSplit();
            if (ok)
                Toaster.toast(Tr.tr("VPN app routing updated"), "", "alt_route");
            if (typeof done === "function")
                done(ok, out, cancelled);
        }, payload);
    }

    Component.onCompleted: {
        root.ensureProviderIds();
        root.ensureSelection();
        root.refreshAvailability();
        root.refreshSplit();
        if (root.selectedProvider.length > 0) {
            root.autoConnectPending = GlobalConfig.utilities.vpn.enabled;
            statusCheckTimer.start();
        }
    }

    // ── Provider adapters ───────────────────────────────────────────────────
    // One adapter per built-in provider, holding everything that is specific
    // to it. Supporting a new provider means adding one adapter here (plus a
    // parser if it has a status command) - nothing else changes.

    Adapter {
        id: wireguardAdapter

        name: "wireguard"
        // No daemon and no CLI status; the interface comes from config and the
        // generic interface-presence check reports the state.
        display: iface => iface
        cliBin: "wg-quick"
        pkgName: "wireguard-tools"
        pkgSource: "repo"
        pkgLabel: "WireGuard"
        connectCmd: iface => ["pkexec", "wg-quick", "up", iface]
        disconnectCmd: iface => ["pkexec", "wg-quick", "down", iface]
        connectHint: error => {
            if (error.includes("Unknown device type") || error.includes("Protocol not supported"))
                return Tr.mark("WireGuard module not loaded. Run: %1", ["sudo modprobe wireguard"]);
            if (error.includes("does not exist") || error.includes("No such file"))
                return Tr.mark("Config file not found in /etc/wireguard — import a .conf file or create it first");
            return "";
        }
    }

    Adapter {
        id: nmAdapter

        name: "nm"
        display: iface => iface
        service: "NetworkManager"
        cliBin: "nmcli"
        pkgName: "networkmanager"
        pkgSource: "repo"
        pkgLabel: "NetworkManager"
        connectCmd: iface => ["nmcli", "connection", "up", iface]
        disconnectCmd: iface => ["nmcli", "connection", "down", iface]
        statusCmd: ["nmcli", "-t", "-f", "NAME,TYPE,DEVICE,STATE", "connection", "show", "--active"]
        parse: (out, iface) => root.parseNmVpnStatus(out, iface)
    }

    Adapter {
        id: warpAdapter

        name: "warp"
        display: "Cloudflare WARP"
        iface: "CloudflareWARP"
        service: "warp-svc"
        cliBin: "warp-cli"
        pkgName: "cloudflare-warp-bin"
        pkgSource: "repo"
        pkgLabel: "Cloudflare WARP"
        connectCmd: ["warp-cli", "--accept-tos", "connect"]
        disconnectCmd: ["warp-cli", "--accept-tos", "disconnect"]
        statusCmd: ["warp-cli", "--accept-tos", "status"]
        parse: out => root.parseWarpStatus(out)
        registerCmd: ["warp-cli", "--accept-tos", "registration", "new"]
        serverCmd: ["warp-cli", "--accept-tos", "tunnel", "stats"]
        parseServer: out => root.parseWarpServer(out)
        connectHint: error => {
            if (error.includes("Unable to connect to the CloudflareWARP") || error.includes("daemon is not running"))
                return Tr.mark("Cloudflare WARP service is not running");
            if (error.includes("Registration Missing") || error.includes("Missing registration"))
                return Tr.mark("WARP registration required");
            return "";
        }
    }

    Adapter {
        id: netbirdAdapter

        name: "netbird"
        display: "NetBird"
        iface: "wt0"
        service: "netbird"
        cliBin: "netbird"
        pkgName: "netbird"
        pkgSource: "aur"
        pkgLabel: "NetBird"
        connectCmd: ["netbird", "up", "--no-browser"]
        disconnectCmd: ["netbird", "down"]
        statusCmd: ["netbird", "status", "--json"]
        parse: out => root.parseNetBirdStatus(out)
    }

    Adapter {
        id: tailscaleAdapter

        name: "tailscale"
        display: "Tailscale"
        iface: "tailscale0"
        service: "tailscaled"
        cliBin: "tailscale"
        pkgName: "tailscale"
        pkgSource: "repo"
        pkgLabel: "Tailscale"
        connectCmd: ["tailscale", "up"]
        disconnectCmd: ["tailscale", "down"]
        statusCmd: ["tailscale", "status", "--json"]
        parse: out => root.parseTailscaleStatus(out)
        // TRANSLATORS: %1 = a shell command, leave it untranslated
        connectHint: error => error.includes("Access denied") || error.includes("checkprefs access denied") ? Tr.mark("Permission denied. Run in terminal: %1", ["sudo tailscale set --operator=$USER"]) : ""
    }

    // ── Generic engine ──────────────────────────────────────────────────────

    Process {
        id: availProc

        command: ["sh", "-c", 'python3 -I -c "import json, shutil, subprocess\nbins = {b: bool(shutil.which(b)) for b in (\'wg-quick\', \'nmcli\', \'warp-cli\', \'tailscale\', \'netbird\')}\nsvcs = {s: subprocess.run([\'systemctl\', \'is-active\', s], text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip() or \'inactive\' for s in (\'warp-svc\', \'tailscaled\', \'netbird\')}\nprint(json.dumps({\'bins\': bins, \'services\': svcs}))"']
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.cliInstalled = d.bins ?? ({});
                    root.serviceStates = d.services ?? ({});
                    root.availabilityChecked = true;
                    if (root.selectedProvider.length > 0 && !statusProc.running)
                        statusCheckTimer.restart();
                } catch (e) {}
            }
        }
    }

    Process {
        id: nmMonitor

        running: root.selectedProvider.length > 0
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: statusCheckTimer.restart()
        }
    }

    Process {
        id: statusProc

        property string outText: ""
        property string errText: ""
        property int exitCode: 0
        property int pending: 0

        function settle(): void {
            if (--pending > 0)
                return;
            const out = outText;
            const err = errText;
            const combined = `${out}\n${err}`;
            const daemonDown = combined.includes("doesn't appear to be running") || combined.includes("failed to connect") || combined.includes("daemon is not running") || combined.includes("Unable to connect to the CloudflareWARP") || (combined.includes("not running") && root.active.service);
            if (daemonDown && root.active.service) {
                root.updateStatus({
                    connected: false,
                    state: "service-stopped",
                    reason: Tr.mark("%1 service is not running", [root.active.displayName]),
                    authUrl: "",
                    server: ""
                });
                return;
            }
            const parsed = root.active.parse(out);
            if (parsed) {
                root.updateStatus(parsed);
            } else if (err.trim().length > 0) {
                root.updateStatus({
                    connected: false,
                    state: "error",
                    reason: err.trim().split("\n")[0],
                    authUrl: "",
                    server: ""
                });
            }
        }

        command: root.active.statusCmd
        // qmllint disable incompatible-type
        environment: ({
                // qmllint enable incompatible-type
                LANG: "C.UTF-8",
                LC_ALL: "C.UTF-8"
            })
        onRunningChanged: {
            if (running) {
                root.statusExited = false;
                return;
            }
            if (!root.statusExited && pending > 0) {
                pending = 0;
                root.refreshAvailability();
                root.updateStatus({
                    connected: false,
                    state: root.active.cliBin ? "missing-cli" : "error",
                    reason: Tr.mark("%1 is not installed", [root.active.displayName]),
                    authUrl: "",
                    server: ""
                });
            }
        }
        onExited: code => {
            root.statusExited = true;
            exitCode = code;
            settle();
        }
        stdout: StdioCollector {
            onStreamFinished: {
                statusProc.outText = text;
                statusProc.settle();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                statusProc.errText = text;
                statusProc.settle();
            }
        }
    }

    Process {
        id: connectProc

        property string outText: ""
        property string errText: ""
        property int exitCode: -1

        onRunningChanged: {
            if (running) {
                root.connectExited = false;
                errText = "";
                outText = "";
                return;
            }

            if (!root.connectExited) {
                console.warn(lc, `Failed to start connect command '${command.join(" ")}'`);
                root.refreshAvailability();
                root.reportConnectFailure(Tr.tr("Could not start %1. Is it installed?").arg(root.active.displayName), root.active.cliBin ? "missing-cli" : "error");
            }
        }

        onExited: code => {
            root.connectExited = true;
            exitCode = code;

            // Deferred so SplitParser delivers trailing lines on stdout/stderr before settling.
            Qt.callLater(() => {
                const combined = `${outText}\n${errText}`.trim();
                const hint = root.active.connectHint ? root.active.connectHint(combined) : "";
                if (hint) {
                    const isTsOp = root.active.name === "tailscale" && (combined.includes("Access denied") || combined.includes("checkprefs access denied"));
                    const nextState = isTsOp ? "needs-operator" : ((combined.includes("Registration Missing") || combined.includes("Missing registration")) ? "needs-auth" : ((combined.includes("daemon") || combined.includes("Unable to connect to the CloudflareWARP")) ? "service-stopped" : "error"));
                    root.connectPending = false;
                    root.connected = false;
                    root.updateStatus({
                        connected: false,
                        state: nextState,
                        reason: isTsOp ? Tr.mark("Permission needed for your user to control Tailscale") : hint,
                        authUrl: "",
                        server: ""
                    });
                    return;
                }

                const authUrl = root.extractAuthUrl(combined);
                if (authUrl) {
                    root.updateStatus(root.createAuthStatus(authUrl));
                    return;
                }
                if (combined.includes("already exists")) {
                    root.connectPending = false;
                    root.connected = true;
                    return;
                }

                if (root.status.state === "needs-auth" || root.status.state === "service-stopped" || root.status.state === "needs-operator")
                    return;

                if (exitCode !== 0) {
                    console.warn(lc, `Connect command '${command.join(" ")}' failed with exit code`, exitCode, combined);
                    const lines = combined ? combined.split("\n").map(l => l.trim()).filter(l => l.length > 0 && !l.startsWith("[#]")) : [];
                    root.reportConnectFailure(lines[0] || Tr.tr("Could not connect to %1").arg(root.active.displayName));
                    return;
                }

                statusCheckTimer.restart();
            });
        }
        stdout: SplitParser {
            onRead: data => {
                connectProc.outText += data + "\n";
                const authUrl = root.extractAuthUrl(data);
                if (authUrl) {
                    root.updateStatus(root.createAuthStatus(authUrl));
                }
            }
        }
        stderr: SplitParser {
            onRead: data => {
                connectProc.errText += data + "\n";
                const authUrl = root.extractAuthUrl(data);
                if (authUrl) {
                    root.updateStatus(root.createAuthStatus(authUrl));
                }
            }
        }
    }

    Process {
        id: disconnectProc

        onRunningChanged: {
            if (running) {
                root.disconnectExited = false;
                return;
            }

            if (!root.disconnectExited) {
                console.warn(lc, `Failed to start disconnect command '${command.join(" ")}'`);
                root.reportDisconnectFailure(Tr.tr("Could not start %1. Is it installed?").arg(root.active.displayName));
            }
        }

        onExited: {
            root.disconnectExited = true;
            statusCheckTimer.start();
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const error = text.trim();
                if (error && !error.includes("[#]")) {
                    console.warn(lc, "Disconnection error:", error);
                }
            }
        }
    }

    Process {
        id: registerProc

        property string errText: ""
        property int exitCode: -1
        property int pending: 0

        function settle(): void {
            if (--pending > 0)
                return;
            if (exitCode === 0) {
                if (root.connectAfterRegister) {
                    root.connectAfterRegister = false;
                    root.connectPending = true;
                    connectProc.exec(root.active.connectCmd);
                } else {
                    statusCheckTimer.restart();
                }
            } else {
                const wantConnect = root.connectAfterRegister;
                root.connectAfterRegister = false;
                const msg = errText.trim().split("\n")[0] || Tr.tr("Could not register %1").arg(root.active.displayName);
                if (wantConnect)
                    root.reportConnectFailure(msg);
                else
                    root.updateStatus({
                        connected: false,
                        state: "error",
                        reason: msg,
                        authUrl: "",
                        server: ""
                    });
            }
        }

        onRunningChanged: {
            if (running) {
                errText = "";
                pending = 2;
            }
        }
        onExited: code => {
            exitCode = code;
            settle();
        }
        stderr: StdioCollector {
            onStreamFinished: {
                registerProc.errText = text;
                registerProc.settle();
            }
        }
    }

    // Reads cumulative rx/tx bytes for the active VPN interface from sysfs.
    Process {
        id: statsProc

        stdout: StdioCollector {
            onStreamFinished: {
                const nums = text.trim().split("\n").map(n => parseInt(n.trim(), 10)).filter(n => !isNaN(n));
                if (nums.length >= 2) {
                    root.bytesIn = Units.formatBytes(nums[0]);
                    root.bytesOut = Units.formatBytes(nums[1]);
                }
            }
        }
    }

    Process {
        id: pingProc

        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/time[=<]\s*([\d.]+)\s*ms/i);
                if (m) {
                    root.pingMs = Math.round(parseFloat(m[1]));
                } else if (root.connected) {
                    // Reachable interface but no reply parsed → mark unknown.
                    root.pingMs = -1;
                }
            }
        }
    }

    Process {
        id: serverProc

        stdout: StdioCollector {
            onStreamFinished: {
                if (root.active.parseServer) {
                    const server = root.active.parseServer(text);
                    if (server)
                        root.serverLocation = server;
                }
            }
        }
    }

    Process {
        id: splitStatusProc

        command: [`${Paths.libdir}/caelestia-vpn-split`, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.splitMode = d.mode || "all";
                    root.splitApps = Array.isArray(d.apps) ? d.apps : [];
                    root.splitActive = !!d.active;
                    root.splitServiceActive = !!d.serviceActive;
                    root.splitVpnIface = d.vpnIface || "";
                    root.splitUplinkIface = d.uplinkIface || "";
                    root.splitMatchedPids = Number(d.matchedPids) || 0;
                    root.splitRunningByApp = d.runningByApp ?? ({});
                } catch (e) {}
                root.splitLoaded = true;
            }
        }
    }

    Timer {
        id: statusCheckTimer

        interval: 600
        onTriggered: root.checkStatus()
    }

    LoggingCategory {
        id: lc

        name: "caelestia.qml.services.vpn"
        defaultLogLevel: LoggingCategory.Info
    }

    // Everything a provider needs to be driven by the generic engine above.
    // Commands may be plain arrays or functions of the interface name; parse
    // hooks are optional and fall back to the interface-presence check.
    component Adapter: QtObject {
        required property string name
        property var display
        property string iface
        // Systemd unit behind the provider's CLI; used for the "service not
        // running" hint. Empty = daemonless.
        property string service
        property string cliBin
        property string pkgName
        property string pkgSource: "repo"
        property string pkgLabel
        property var connectCmd
        property var disconnectCmd
        property var statusCmd
        property var parse
        property var connectHint
        property var registerCmd
        property var serverCmd
        property var parseServer
    }
}
