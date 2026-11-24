pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.modules.nexus.common

// Per-app VPN split tunneling: chooses whether all apps use the VPN, only
// chosen apps use it, or chosen apps bypass it directly via the physical uplink.
PageBase {
    id: root

    property string draftMode: "all"
    property var draftApps: []
    property bool initialized: false

    readonly property bool dirty: initialized && (draftMode !== VPN.splitMode || JSON.stringify(draftApps) !== JSON.stringify(VPN.splitApps ?? []))
    readonly property string effectiveSubtext: draftMode === "include"
        ? Tr.tr("Only apps in this list route through the VPN; all other apps connect directly")
        : draftMode === "exclude"
            ? Tr.tr("Apps in this list bypass the VPN and connect directly")
            : Tr.tr("Every app follows the active VPN connection normally")

    function syncFromService(force: bool): void {
        if (!VPN.splitLoaded)
            return;
        if (!force && initialized && dirty)
            return;
        draftMode = VPN.splitMode || "all";
        draftApps = (VPN.splitApps ?? []).map(a => ({
                id: a.id,
                name: a.name,
                icon: a.icon ?? "",
                binaries: [...(a.binaries ?? [])]
            }));
        initialized = true;
    }

    function extractBinaries(picked: var): var {
        const wrappers = new Set(["env", "sh", "bash", "dash", "zsh", "gamemoderun", "mangohud", "prime-run", "flatpak", "umu-run", "python", "python3"]);
        const binRe = /^[A-Za-z0-9._+@:-]{1,128}$/;
        const out = [];
        const add = raw => {
            const cleaned = String(raw ?? "").trim().replace(/^['"]|['"]$/g, "");
            if (!cleaned)
                return;
            const base = cleaned.split("/").pop();
            if (!base || wrappers.has(base.toLowerCase()) || !binRe.test(base))
                return;
            if (!out.some(x => x.toLowerCase() === base.toLowerCase()))
                out.push(base);
        };

        // DesktopEntry.command argv is cleanest; fallback to splitting command string.
        const rawCmd = picked.desktopEntry?.command ?? [];
        const argv = rawCmd.length > 0 ? Array.from(rawCmd) : String(picked.command ?? "").match(/(?:[^\s"']+|"[^"]*"|'[^']*')+/g) ?? [];
        for (let i = 0; i < argv.length; i++) {
            const tok = String(argv[i]).replace(/^['"]|['"]$/g, "");
            if (!tok || tok.startsWith("%"))
                continue;
            const base = tok.split("/").pop().toLowerCase();
            if (tok.includes("=") && !tok.startsWith("/") && !tok.startsWith("."))
                continue;
            if (wrappers.has(base))
                continue;
            if (tok.startsWith("-"))
                continue;
            add(tok);
            break;
        }

        if (picked.wmClass)
            add(String(picked.wmClass).toLowerCase());
        if (picked.classAlt)
            add(String(picked.classAlt).toLowerCase());
        if (picked.id) {
            const parts = String(picked.id).split(".");
            add(parts[parts.length - 1].toLowerCase());
        }
        return out.slice(0, 6);
    }

    function addApp(picked: var): void {
        if (!picked)
            return;
        const bins = extractBinaries(picked);
        if (bins.length === 0) {
            Toaster.toast(Tr.tr("Could not identify app binary"), picked.name || "", "error");
            return;
        }
        const entry = {
            id: String(picked.id || bins[0]),
            name: String(picked.name || picked.id || bins[0]),
            icon: String(picked.icon || ""),
            binaries: bins
        };
        if (draftApps.some(a => a.id === entry.id))
            return;
        draftApps = [...draftApps, entry];
    }

    function removeApp(appId: string): void {
        draftApps = draftApps.filter(a => a.id !== appId);
    }

    function applyChanges(): void {
        const targetMode = (draftMode !== "all" && draftApps.length === 0) ? "all" : draftMode;
        const targetApps = targetMode === "all" ? [] : draftApps;
        VPN.applySplit(targetMode, targetApps, ok => {
            if (ok)
                root.syncFromService(true);
        });
    }

    title: Tr.tr("App routing")
    isSubPage: true

    Component.onCompleted: {
        syncFromService(true);
        VPN.refreshSplit();
    }

    onVisibleChanged: {
        if (visible)
            VPN.refreshSplit();
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Connections {
            function onSplitLoadedChanged(): void {
                root.syncFromService(false);
            }

            function onSplitModeChanged(): void {
                root.syncFromService(false);
            }

            function onSplitAppsChanged(): void {
                root.syncFromService(false);
            }

            target: VPN
        }

        Timer {
            interval: 4000
            repeat: true
            running: root.visible && VPN.splitMode !== "all"
            onTriggered: VPN.refreshSplit()
        }

        SectionHeader {
            text: Tr.tr("Split tunneling")
        }

        InfoRow {
            icon: VPN.splitActive ? "alt_route" : "public"
            label: VPN.splitActive
                ? Tr.tr("Active")
                : VPN.splitServiceActive && !VPN.splitVpnIface
                    ? Tr.tr("Standby (VPN disconnected)")
                    : Tr.tr("All apps use the VPN")
            value: VPN.splitMode === "all"
                ? Tr.tr("Disabled")
                : Tr.trN("%n app", "%n apps", VPN.splitApps.length)
            subtext: !VPN.splitVpnIface
                ? Tr.tr("Connect a VPN (Cloudflare WARP, WireGuard, Tailscale, NetBird) for app rules to take effect")
                : VPN.splitActive
                    ? Tr.tr("%1 tunnel (%2) · Uplink %3 · %4 active processes matched").arg(VPN.active.displayName || Tr.tr("VPN")).arg(VPN.splitVpnIface).arg(VPN.splitUplinkIface || "?").arg(VPN.splitMatchedPids)
                    : Tr.tr("VPN active on %1 · Configure included or excluded apps below").arg(VPN.splitVpnIface)
        }

        SectionHeader {
            text: Tr.tr("Routing mode")
        }

        SelectRow {
            id: modeRow

            label: Tr.tr("Which apps use the VPN")
            subtext: root.effectiveSubtext
            menuItems: [modeAll, modeInclude, modeExclude]
            active: root.draftMode === "include" ? modeInclude : root.draftMode === "exclude" ? modeExclude : modeAll
            onSelected: item => root.draftMode = item.key

            MenuItem {
                id: modeAll

                readonly property string key: "all"

                text: Tr.tr("All apps")
            }

            MenuItem {
                id: modeInclude

                readonly property string key: "include"

                text: Tr.tr("Only selected")
            }

            MenuItem {
                id: modeExclude

                readonly property string key: "exclude"

                text: Tr.tr("Bypass VPN")
            }
        }

        RowButton {
            visible: root.dirty
            icon: "check_circle"
            text: root.draftMode !== "all" && root.draftApps.length === 0
                ? Tr.tr("Disable split tunneling (no apps selected)")
                : Tr.tr("Apply routing changes")
            subtext: VPN.splitBusy ? Tr.tr("Applying network rules…") : Tr.tr("Saves rules and updates nftables / policy routing")
            disabled: VPN.splitBusy
            onClicked: root.applyChanges()
        }

        RowButton {
            visible: root.dirty
            icon: "undo"
            text: Tr.tr("Discard changes")
            disabled: VPN.splitBusy
            onClicked: root.syncFromService(true)
        }

        SectionHeader {
            visible: root.draftMode !== "all"
            text: root.draftMode === "include" ? Tr.tr("Apps using the VPN") : Tr.tr("Apps bypassing the VPN")
            subtext: root.draftMode === "include"
                ? Tr.tr("Only these apps go through the VPN; all other user apps and browsers use the direct connection")
                : Tr.tr("These apps bypass the VPN and connect directly via your physical network interface")
        }

        Repeater {
            model: root.draftMode !== "all" ? root.draftApps : []

            ConnectedRect {
                id: appRow

                required property var modelData
                readonly property string iconSource: appRow.modelData.icon ? Quickshell.iconPath(appRow.modelData.icon, true) : ""
                readonly property int runningCount: VPN.splitRunningByApp[appRow.modelData.id] ?? 0

                Layout.fillWidth: true
                implicitHeight: Math.ceil(appLayout.implicitHeight) + Tokens.padding.medium * 2

                RowLayout {
                    id: appLayout

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.largeIncreased
                    spacing: Tokens.spacing.medium

                    Item {
                        implicitWidth: 28
                        implicitHeight: 28

                        IconImage {
                            anchors.fill: parent
                            visible: appRow.iconSource !== ""
                            source: appRow.iconSource
                            asynchronous: true
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            visible: appRow.iconSource === ""
                            text: "apps"
                            color: Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.medium
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: appRow.modelData.name
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: `${(appRow.modelData.binaries ?? []).join(", ")}${appRow.runningCount > 0 ? " · " + Tr.trN("%n running process", "%n running processes", appRow.runningCount) : ""}`
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }

                    IconButton {
                        type: IconButton.Text
                        icon: "close"
                        onClicked: root.removeApp(appRow.modelData.id)
                    }
                }
            }
        }

        RowButton {
            visible: root.draftMode !== "all"
            icon: "add"
            text: Tr.tr("Add app")
            subtext: Tr.tr("Choose an installed or open app, or enter a binary name")
            onClicked: appPicker.openPicker({
                header: root.draftMode === "include" ? Tr.tr("Choose app to use VPN") : Tr.tr("Choose app to bypass VPN"),
                includeRunning: true,
                allowCustom: true,
                customValidate: q => /^[A-Za-z0-9._+@:-]{1,128}$/.test(q),
                customHint: Tr.tr('Add custom binary "%1"'),
                excludeIds: root.draftApps.map(a => a.id),
                onPicked: item => root.addApp(item)
            })
        }

        RowButton {
            visible: !root.dirty && (VPN.splitMode !== "all" || (VPN.splitApps ?? []).length > 0)
            icon: "restart_alt"
            text: Tr.tr("Reset to all apps")
            subtext: Tr.tr("Turn off per-app routing and route all traffic normally")
            disabled: VPN.splitBusy
            onClicked: VPN.applySplit("all", [], ok => {
                if (ok)
                    root.syncFromService(true);
            })
        }

        AppPickerDialog {
            id: appPicker

            hostFlickable: root.flickable
        }
    }
}
