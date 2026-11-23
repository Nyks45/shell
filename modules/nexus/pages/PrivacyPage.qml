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
    property var permissions: []
    property var videoStreams: []
    property bool checked

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

            command: ["python3", "-I", "-c", "import json, subprocess\ntry:\n nodes = json.loads(subprocess.check_output(['pw-dump'], text=True))\nexcept Exception:\n nodes = []\napps = []\nfor n in nodes:\n if not isinstance(n, dict) or n.get('type') != 'PipeWire:Interface:Node': continue\n info = n.get('info') or {}\n if info.get('state') != 'running': continue\n p = info.get('props') or {}\n mc = str(p.get('media.class') or '')\n if 'Video' in mc and ('Stream' in mc or 'Source' in mc):\n  apps.append(str(p.get('application.name') or p.get('node.description') or p.get('node.name') or 'Video'))\nprint(json.dumps(sorted(set(apps))))"]
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
            id: flatpakRevokeProc

            onExited: code => {
                if (code === 0)
                    Toaster.toast(Tr.tr("Permission revoked"), "", "shield");
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
                        Admin.run("firewall", ["on"], what, () => root.refresh());
                    else
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
                Admin.run("firewall", [checked ? "on" : "off"], checked ? Tr.tr("Turn the firewall on") : Tr.tr("Turn the firewall off"), () => root.refresh());
            }
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

        InfoRow {
            icon: Audio.recordingStreams.length > 0 ? "mic" : "mic_none"
            label: Tr.tr("Microphone in use")
            value: Audio.recordingStreams.length > 0 ? Tr.trN("%n app", "%n apps", Audio.recordingStreams.length) : Tr.tr("Idle")
            subtext: Audio.recordingStreams.length > 0 ? Audio.recordingStreams.map(s => Audio.getStreamName(s)).join(", ") : Tr.tr("No apps are currently recording audio")
        }

        InfoRow {
            icon: root.videoStreams.length > 0 ? "videocam" : "videocam_off"
            label: Tr.tr("Camera & screen capture")
            value: root.videoStreams.length > 0 ? Tr.trN("%n app", "%n apps", root.videoStreams.length) : Tr.tr("Idle")
            subtext: root.videoStreams.length > 0 ? root.videoStreams.join(", ") : Tr.tr("No active PipeWire camera or screen-capture streams")
        }

        InfoRow {
            visible: root.flatpakInstalled && root.permissions.length === 0
            icon: "admin_panel_settings"
            label: Tr.tr("Flatpak portal permissions")
            value: Tr.tr("None stored")
            subtext: Tr.tr("Granted camera, microphone, screenshot or background permissions appear here when Flatpak apps store them")
        }

        Repeater {
            model: root.flatpakInstalled ? root.permissions : []

            ConnectedRect {
                id: permRow

                required property var modelData

                Layout.fillWidth: true
                implicitHeight: permLayout.implicitHeight + Tokens.padding.medium * 2

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
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.medium
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: `${permRow.modelData.app || Tr.tr("Global")} · ${permRow.modelData.table}/${permRow.modelData.id || permRow.modelData.object || "?"}`
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: permRow.modelData.permissions
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }

                    TextButton {
                        // flatpak's JSON names the column "object" (the helper may pass it as id)
                        readonly property string objectId: permRow.modelData.id || permRow.modelData.object || ""

                        text: Tr.tr("Revoke")
                        type: TextButton.Text
                        // Without the object, permission-remove would get "" (wrong entry)
                        disabled: flatpakRevokeProc.running || !objectId
                        onClicked: {
                            const args = ["permission-remove", permRow.modelData.table, objectId];
                            if (permRow.modelData.app)
                                args.push(permRow.modelData.app);
                            flatpakRevokeProc.command = ["flatpak", ...args];
                            flatpakRevokeProc.running = true;
                        }
                    }
                }
            }
        }

        RowButton {
            visible: root.flatpakInstalled && root.permissions.length > 0
            icon: "reset_wrench"
            text: Tr.tr("Reset all Flatpak permissions…")
            subtext: Tr.tr("Revokes all stored Flatpak portal permissions across every app")
            disabled: flatpakRevokeProc.running
            onClicked: confirmDialog.ask({
                header: Tr.tr("Reset all Flatpak permissions?"),
                body: Tr.tr("All %1 stored Flatpak portal permission entries will be cleared. Apps will ask again when needed.").arg(root.permissions.length),
                confirmLabel: Tr.tr("Reset all"),
                onConfirm: () => {
                    flatpakRevokeProc.command = ["flatpak", "permission-reset", "--all"];
                    flatpakRevokeProc.running = true;
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
}
