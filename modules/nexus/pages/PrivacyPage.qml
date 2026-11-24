pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus
import qs.modules.nexus.common

// Privacy & security: the firewall (ufw), encryption/TPM, camera/mic/portal
// permissions, screen lock, and recent files/notifications/clipboard history.
PageBase {
    id: root

    property string firewall // "active", "inactive", "" (no ufw)
    property bool firewallPending
    property bool hasCliphist
    property string secureBootState: "unknown"
    property bool sbctlInstalled
    property bool sbctlEnrolled
    property bool setupMode
    property string tpmVersion
    property bool encrypted
    property var encryptedTargets: []
    property bool flatpakInstalled
    property bool portalAvailable
    property var permissions: []
    property var videoStreams: []
    property bool micExpanded: false
    property bool camExpanded: false
    property bool checked

    readonly property var micPermissions: (permissions ?? []).filter(p => (p.table === "devices" && p.id === "microphone") || p.table === "microphone")
    readonly property var camPermissions: (permissions ?? []).filter(p => (p.table === "devices" && p.id === "camera") || ["camera", "webcam", "screenshot", "screencast", "remote-desktop"].includes(p.table))
    readonly property var otherPermissions: (permissions ?? []).filter(p => !micPermissions.includes(p) && !camPermissions.includes(p))

    function isPermAllowed(perm: var): bool {
        const vals = Array.isArray(perm?.values) ? perm.values : String(perm?.permissions ?? "").split(",").map(s => s.trim());
        return vals.some(v => v === "yes" || v === "allow" || v === "true");
    }

    function setPortalPermission(perm: var, allow: bool): void {
        const objId = perm.id || perm.object || "";
        if (!perm.table || !objId)
            return;
        portalProc.actionKind = "set";
        portalProc.command = [`${Paths.libdir}/caelestia-system`, "portal-permission-set", perm.table, objId, perm.app ?? "", allow ? "yes" : "no"];
        portalProc.running = true;
    }

    function revokePortalPermission(perm: var): void {
        const objId = perm.id || perm.object || "";
        if (!perm.table || !objId)
            return;
        portalProc.actionKind = "delete";
        portalProc.command = [`${Paths.libdir}/caelestia-system`, "portal-permission-delete", perm.table, objId, perm.app ?? ""];
        portalProc.running = true;
    }

    function disconnectVideoStream(stream: var): void {
        if (!stream?.id)
            return;
        portalProc.actionKind = "disconnect";
        portalProc.command = [`${Paths.libdir}/caelestia-system`, "video-disconnect", String(stream.id)];
        portalProc.running = true;
    }

    function refresh(): void {
        secProc.running = false;
        secProc.running = true;
        clipProc.running = false;
        clipProc.running = true;
        videoProc.running = false;
        videoProc.running = true;
    }

    title: Tr.tr("Privacy & security")

    Component.onCompleted: refresh()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Process {
            id: secProc

            command: [`${Paths.libdir}/caelestia-system`, "security-status"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const d = JSON.parse(text);
                        root.firewall = d.firewall === "none" ? "" : (d.firewall ?? "");
                        root.secureBootState = d.secureBoot ?? "unknown";
                        root.sbctlInstalled = !!d.sbctlInstalled;
                        root.sbctlEnrolled = !!d.sbctlEnrolled;
                        root.setupMode = !!d.setupMode;
                        root.tpmVersion = d.tpmVersion ?? "";
                        root.encrypted = !!d.encrypted;
                        root.encryptedTargets = d.encryptedTargets ?? [];
                        root.flatpakInstalled = !!d.flatpakInstalled;
                        root.portalAvailable = !!d.portalAvailable;
                        root.permissions = d.permissions ?? [];
                    } catch (e) {}
                    root.firewallPending = false;
                    root.checked = true;
                }
            }
        }

        Process {
            id: clipProc

            command: ["sh", "-c", "command -v cliphist >/dev/null && echo yes || true"]
            stdout: StdioCollector {
                onStreamFinished: root.hasCliphist = text.trim() === "yes"
            }
        }

        Process {
            id: videoProc

            command: [`${Paths.libdir}/caelestia-system`, "video-streams"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        root.videoStreams = JSON.parse(text);
                    } catch (e) {
                        root.videoStreams = [];
                    }
                }
            }
        }

        Process {
            id: portalProc

            property string actionKind: ""
            property string errText: ""

            onRunningChanged: {
                if (running)
                    errText = "";
            }
            stderr: StdioCollector {
                onStreamFinished: portalProc.errText = text.trim()
            }
            onExited: code => {
                if (code === 0) {
                    if (actionKind === "set")
                        Toaster.toast(Tr.tr("Permission updated"), "", "shield");
                    else if (actionKind === "disconnect")
                        Toaster.toast(Tr.tr("Stream disconnected"), "", "videocam_off");
                    else
                        Toaster.toast(Tr.tr("Permission revoked"), "", "shield");
                } else {
                    Toaster.toast(Tr.tr("Action failed"), errText || Tr.tr("Helper exited with code %1").arg(code), "error");
                }
                root.refresh();
            }
        }

        SectionHeader {
            text: Tr.tr("Security")
        }

        RequirementRow {
            visible: root.checked && root.firewall === ""
            icon: "shield"
            text: Tr.tr("No firewall installed")
            subtext: Tr.tr("ufw blocks incoming connections the PC didn't ask for. Installing it asks for your password.")
            actionText: root.firewallPending ? "" : Tr.tr("Install")
            onAction: {
                const what = Tr.tr("Install and turn on the firewall");
                root.firewallPending = true;
                Admin.run("install", ["ufw"], what, ok => {
                    if (ok)
                        Admin.run("firewall", ["on"], what, () => {
                            if (root)
                                root.refresh();
                        });
                    else if (root)
                        root.refresh();
                });
            }
        }

        ToggleRow {
            visible: root.firewall !== ""
            text: Tr.tr("Firewall")
            subtext: root.firewallPending ? Tr.tr("Applying…") : root.firewall === "active" ? Tr.tr("Blocks incoming connections the PC didn't ask for") : Tr.tr("Off: anything on the network can reach open ports")
            checked: root.firewall === "active"
            onToggled: {
                root.firewallPending = true;
                Admin.run("firewall", [checked ? "on" : "off"], checked ? Tr.tr("Turn the firewall on") : Tr.tr("Turn the firewall off"), () => {
                    if (root)
                        root.refresh();
                });
            }
        }

        NavRow {
            icon: "shield"
            text: Tr.tr("Ad blocker")
            subtext: !AdBlocker.configured ? Tr.tr("Block ads, trackers & phishing system-wide · Manage in Network") : AdBlocker.active ? Tr.tr("Active · %1 blocked · Manage in Network").arg(AdBlocker.formatCompactCount(AdBlocker.stats.numBlockedFiltering ?? 0)) : AdBlocker.paused ? Tr.tr("Paused · %1 left · Manage in Network").arg(AdBlocker.formatPauseCountdown(AdBlocker.pauseRemainingSec)) : Tr.tr("Off · Manage in Network")
            onClicked: root.nState.goTo({
                page: PageRegistry.find("network"),
                path: [7]
            })
        }

        NavRow {
            icon: "lock"
            text: Tr.tr("Screen lock")
            subtext: Tr.tr("When the screen locks by itself, on Power & sleep")
            onClicked: root.nState.goTo({
                page: PageRegistry.find("power"),
                path: [],
                text: Tr.tr("Lock the screen after")
            })
        }

        NavRow {
            icon: "verified_user"
            text: Tr.tr("Secure Boot")
            subtext: root.secureBootState === "enabled" ? (root.sbctlEnrolled ? Tr.tr("Enabled · sbctl has its own keys · Manage in Recovery & boot") : Tr.tr("Enabled · Manage keys and boot entries in Recovery & boot")) : root.secureBootState === "disabled" ? (root.setupMode ? Tr.tr("Disabled (Setup Mode) · Ready for sbctl key enrolment in Recovery & boot") : Tr.tr("Disabled · Manage keys and boot entries in Recovery & boot")) : root.secureBootState === "bios" ? Tr.tr("Not available (legacy BIOS)") : Tr.tr("Status unknown")
            onClicked: root.nState.goTo({
                page: PageRegistry.find("recovery"),
                tab: "",
                path: []
            })
        }

        // What matters is the system and the home folder: one encrypted USB
        // drive (also in encryptedTargets) doesn't make this PC encrypted
        InfoRow {
            readonly property bool rootEncrypted: root.encryptedTargets.includes("/")
            readonly property bool homeEncrypted: root.encryptedTargets.includes("/home")
            readonly property var others: root.encryptedTargets.filter(t => t !== "/" && t !== "/home")

            icon: rootEncrypted ? "enhanced_encryption" : "no_encryption"
            label: Tr.tr("Disk encryption & TPM")
            value: rootEncrypted ? Tr.tr("System encrypted") : homeEncrypted ? Tr.tr("Home only") : Tr.tr("Not encrypted")
            subtext: [rootEncrypted ? Tr.tr("System (/) is LUKS-encrypted") : Tr.tr("System (/) is not encrypted"), homeEncrypted ? Tr.tr("/home is encrypted") : "", others.length ? Tr.tr("also encrypted: %1").arg(others.join(", ")) : "", root.tpmVersion ? Tr.tr("TPM %1 detected").arg(root.tpmVersion) : Tr.tr("No TPM device detected")].filter(x => x).join(" · ")
        }

        NavRow {
            icon: "system_update_alt"
            text: Tr.tr("System updates")
            subtext: Packages.total > 0 ? Tr.trN("%n update waiting", "%n updates waiting", Packages.total) : Tr.tr("Up to date · Keep packages and security patches current")
            onClicked: root.nState.goTo({
                page: PageRegistry.find("updates"),
                tab: "",
                path: []
            })
        }

        SectionHeader {
            text: Tr.tr("Camera, microphone & screen sharing")
        }

        RowButton {
            readonly property string activeList: Audio.microphoneStreams.map(s => Audio.getStreamName(s)).join(", ")

            icon: Audio.sourceMuted ? "mic_off" : Audio.microphoneStreams.length > 0 ? "mic" : "mic_none"
            text: Tr.tr("Microphone")
            subtext: Audio.microphoneStreams.length > 0
                ? Tr.tr("%1 (%2)").arg(Tr.trN("%n active app", "%n active apps", Audio.microphoneStreams.length)).arg(activeList)
                : Audio.sourceMuted
                    ? Tr.tr("Muted · Click to control microphone and app permissions")
                    : (root.micPermissions.length > 0
                        ? Tr.trN("Idle · %n stored app permission", "Idle · %n stored app permissions", root.micPermissions.length)
                        : Tr.tr("Idle · Click to control microphone and app permissions"))
            trailingIcon: root.micExpanded ? "expand_less" : "expand_more"
            onClicked: root.micExpanded = !root.micExpanded
        }

        ToggleRow {
            visible: root.micExpanded
            text: Tr.tr("Default microphone enabled")
            subtext: Audio.source ? (Audio.sourceMuted ? Tr.tr("Muted · %1").arg(Audio.friendlyDeviceName(Audio.source)) : Audio.friendlyDeviceName(Audio.source)) : Tr.tr("No microphone input device detected")
            checked: !Audio.sourceMuted
            disabled: !Audio.source?.ready
            onToggled: if (Audio.source?.ready)
                Audio.source.audio.muted = !checked
        }

        Repeater {
            model: root.micExpanded ? Audio.microphoneStreams : []

            ToggleRow {
                id: micStreamRow

                required property var modelData

                text: Audio.getStreamName(micStreamRow.modelData)
                subtext: Audio.getStreamMuted(micStreamRow.modelData) ? Tr.tr("Muted live stream") : Tr.tr("Currently recording audio")
                checked: !Audio.getStreamMuted(micStreamRow.modelData)
                onToggled: Audio.setStreamMuted(micStreamRow.modelData, !checked)
            }
        }

        Repeater {
            model: root.micExpanded ? root.micPermissions : []

            PermissionEntryRow {}
        }

        InfoRow {
            visible: root.micExpanded && Audio.microphoneStreams.length === 0 && root.micPermissions.length === 0
            icon: "mic_none"
            label: Tr.tr("No active mic apps or stored portal permissions")
            subtext: Tr.tr("Apps using your microphone live or granted via XDG portal appear here")
        }

        RowButton {
            readonly property string activeApps: root.videoStreams.map(s => s.app).join(", ")

            icon: root.videoStreams.length > 0 ? "videocam" : "videocam_off"
            text: Tr.tr("Camera & screen capture")
            subtext: root.videoStreams.length > 0
                ? Tr.tr("%1 (%2)").arg(Tr.trN("%n active stream", "%n active streams", root.videoStreams.length)).arg(activeApps)
                : (root.camPermissions.length > 0
                    ? Tr.trN("Idle · %n stored app permission", "Idle · %n stored app permissions", root.camPermissions.length)
                    : Tr.tr("Idle · Click to inspect active streams and app permissions"))
            trailingIcon: root.camExpanded ? "expand_less" : "expand_more"
            onClicked: root.camExpanded = !root.camExpanded
        }

        Repeater {
            model: root.camExpanded ? root.videoStreams : []

            ConnectedRect {
                id: videoRow

                required property var modelData

                Layout.fillWidth: true
                implicitHeight: Math.ceil(videoLayout.implicitHeight) + Tokens.padding.medium * 2

                RowLayout {
                    id: videoLayout

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.largeIncreased
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: videoRow.modelData.kind === "screen" ? "screen_share" : "videocam"
                        color: Colours.palette.m3primary
                        fontStyle: Tokens.font.icon.medium
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: videoRow.modelData.app || Tr.tr("Video stream")
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: `${videoRow.modelData.kind === "screen" ? Tr.tr("Screen capture") : Tr.tr("Camera")} · ${videoRow.modelData.name || videoRow.modelData.mediaClass}`
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }

                    TextButton {
                        text: Tr.tr("Disconnect")
                        type: TextButton.Tonal
                        disabled: portalProc.running
                        onClicked: root.disconnectVideoStream(videoRow.modelData)
                    }
                }
            }
        }

        Repeater {
            model: root.camExpanded ? root.camPermissions : []

            PermissionEntryRow {}
        }

        InfoRow {
            visible: root.camExpanded && root.videoStreams.length === 0 && root.camPermissions.length === 0
            icon: "videocam_off"
            label: Tr.tr("No active camera or screen capture")
            subtext: Tr.tr("Active PipeWire video streams and stored portal permissions appear here")
        }

        InfoRow {
            visible: (root.portalAvailable || root.flatpakInstalled) && root.permissions.length === 0
            icon: "admin_panel_settings"
            label: Tr.tr("App portal permissions")
            value: Tr.tr("None stored")
            subtext: Tr.tr("Granted camera, microphone, screenshot or background permissions appear here when apps store them")
        }

        Repeater {
            model: root.otherPermissions

            PermissionEntryRow {}
        }

        RowButton {
            visible: root.permissions.length > 0
            icon: "reset_wrench"
            text: Tr.tr("Reset all stored permissions…")
            subtext: Tr.tr("Revokes all stored XDG portal and Flatpak app permissions")
            disabled: portalProc.running
            onClicked: confirmDialog.ask({
                header: Tr.tr("Reset all stored permissions?"),
                body: Tr.tr("All %1 stored app permission entries will be cleared. Apps will ask again when needed.").arg(root.permissions.length),
                confirmLabel: Tr.tr("Reset all"),
                onConfirm: () => {
                    portalProc.actionKind = "reset";
                    portalProc.command = [`${Paths.libdir}/caelestia-system`, "portal-permission-reset"];
                    portalProc.running = true;
                }
            })
        }

        SectionHeader {
            text: Tr.tr("History")
        }

        ToggleRow {
            text: Tr.tr("Remember recently used files")
            subtext: Tr.tr("Apps list them under Recent")
            checked: AppLook.get("org.gnome.desktop.privacy", "remember-recent-files", true)
            onToggled: AppLook.set("org.gnome.desktop.privacy", "remember-recent-files", checked)
        }

        RowButton {
            icon: "history"
            text: Tr.tr("Clear recent files")
            onClicked: confirmDialog.ask({
                header: Tr.tr("Clear recent files?"),
                body: Tr.tr("Removes your GTK/app recently used files list. The files themselves are not deleted."),
                confirmLabel: Tr.trCtx("Clear", "button"),
                onConfirm: () => {
                    Quickshell.execDetached(["sh", "-c", `printf '<?xml version="1.0" encoding="UTF-8"?>\\n<xbel version="1.0"/>\\n' > "\${XDG_DATA_HOME:-$HOME/.local/share}/recently-used.xbel"`]);
                    Toaster.toast(Tr.tr("Recent files cleared"), "", "history");
                }
            })
        }

        RowButton {
            icon: "notifications_off"
            text: Tr.tr("Clear notification history")
            subtext: Tr.trN("%n notification", "%n notifications", Notifs.list.length)
            disabled: Notifs.list.length === 0
            onClicked: confirmDialog.ask({
                header: Tr.tr("Clear notification history?"),
                body: Tr.tr("Dismisses all %1 stored notifications.").arg(Notifs.list.length),
                confirmLabel: Tr.trCtx("Clear", "button"),
                onConfirm: () => {
                    for (const n of Notifs.list.slice())
                        n.close();
                    Toaster.toast(Tr.tr("Notification history cleared"), "", "notifications_off");
                }
            })
        }

        RowButton {
            visible: root.hasCliphist
            icon: "content_paste_off"
            text: Tr.tr("Clear clipboard history")
            onClicked: confirmDialog.ask({
                header: Tr.tr("Clear clipboard history?"),
                body: Tr.tr("Removes all entries saved in your clipboard history."),
                confirmLabel: Tr.trCtx("Clear", "button"),
                onConfirm: () => {
                    Quickshell.execDetached(["cliphist", "wipe"]);
                    Toaster.toast(Tr.tr("Clipboard history cleared"), "", "content_paste_off");
                }
            })
        }

        RowButton {
            icon: "image"
            text: Tr.tr("Clear thumbnail cache")
            subtext: Tr.tr("Cached previews of images, videos and documents in ~/.cache/thumbnails")
            onClicked: confirmDialog.ask({
                header: Tr.tr("Clear thumbnail cache?"),
                body: Tr.tr("Delete all cached image and video preview thumbnails? Apps will recreate them when needed."),
                confirmLabel: Tr.trCtx("Clear", "button"),
                onConfirm: () => {
                    Quickshell.execDetached(["sh", "-c", "rm -rf \"${XDG_CACHE_HOME:-$HOME/.cache}/thumbnails\"/*"]);
                    Toaster.toast(Tr.tr("Thumbnail cache cleared"), "", "image");
                }
            })
        }

        ConfirmDialog {
            id: confirmDialog

            hostFlickable: root.flickable
        }
    }

    component PermissionEntryRow: ConnectedRect {
        id: permRow

        required property var modelData
        readonly property string objectId: modelData.id || modelData.object || ""
        readonly property bool allowed: root.isPermAllowed(modelData)

        Layout.fillWidth: true
        implicitHeight: Math.ceil(permLayout.implicitHeight) + Tokens.padding.medium * 2

        RowLayout {
            id: permLayout

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Tokens.padding.largeIncreased
            anchors.rightMargin: Tokens.padding.largeIncreased
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "admin_panel_settings"
                color: permRow.allowed ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.medium
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: `${permRow.modelData.app || Tr.tr("Desktop / Host")} · ${permRow.modelData.table}/${permRow.objectId || "?"}`
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: permRow.modelData.permissions || Tr.tr("Ask")
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                    elide: Text.ElideRight
                }
            }

            TextButton {
                text: permRow.allowed ? Tr.tr("Block") : Tr.tr("Allow")
                type: TextButton.Tonal
                disabled: portalProc.running || !permRow.objectId
                onClicked: root.setPortalPermission(permRow.modelData, !permRow.allowed)
            }

            TextButton {
                text: Tr.tr("Revoke")
                type: TextButton.Text
                disabled: portalProc.running || !permRow.objectId
                onClicked: root.revokePortalPermission(permRow.modelData)
            }
        }
    }
}
