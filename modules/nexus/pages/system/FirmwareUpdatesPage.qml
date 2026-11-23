pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

// Motherboard, SSD and device firmware updates via fwupd / fwupdmgr.
PageBase {
    id: root

    property var data: null
    property bool loading: true
    property bool updatedOnce: false

    readonly property bool installed: root.data?.installed === true
    readonly property var devices: root.data?.devices ?? []
    readonly property var updates: root.data?.updates ?? []
    readonly property bool needsReboot: root.data?.needsReboot === true || updatedOnce
    readonly property string errorMsg: root.data?.error ?? ""
    readonly property string updateAllWhat: Tr.tr("Install firmware updates")
    // This page's own jobs, by their exact names (not a word in the translated
    // text, which isn't there in other languages)
    readonly property var updateWhats: [updateAllWhat, ...updates.map(u => rowWhat(u.name))]
    readonly property bool busy: Admin.jobs.some(j => updateWhats.includes(j.what))

    function rowWhat(name: string): string {
        return Tr.tr("Update firmware for %1").arg(name);
    }

    // "Restart to finish" only when fwupdmgr says an installed update needs it
    // (exit 2 "nothing to do" and updates done at once count as success too)
    function noteUpdate(ok: bool, out: string): void {
        if (ok && /(requires?|needs?) a (reboot|restart)|(reboot|restart) (is )?(required|needed)/i.test(out))
            updatedOnce = true;
    }

    function load(refresh: bool): void {
        if (proc.running)
            return;
        loading = true;
        proc.command = refresh ? [`${Paths.libdir}/caelestia-system`, "fwupd", "--refresh"] : [`${Paths.libdir}/caelestia-system`, "fwupd"];
        proc.running = true;
    }

    title: Tr.tr("Firmware updates")
    isSubPage: true

    Component.onCompleted: load(false)

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Process {
            id: proc

            stdout: StdioCollector {
                onStreamFinished: {
                    root.loading = false;
                    try {
                        root.data = JSON.parse(text);
                    } catch (e) {
                        root.data = {
                            installed: true,
                            devices: [],
                            updates: [],
                            needsReboot: false,
                            error: Tr.tr("Failed to parse firmware status")
                        };
                    }
                }
            }
            onExited: code => {
                if (code !== 0 && !root.data)
                    root.loading = false;
            }
        }

        RequirementRow {
            readonly property bool installing: !!Packages.busy["repo:fwupd"]

            visible: !root.loading && root.data !== null && !root.installed
            icon: "memory"
            text: Tr.tr("Firmware updates need fwupd")
            subtext: installing ? Tr.tr("Installing fwupd…") : Tr.tr("Checks and installs UEFI BIOS, SSD and peripheral firmware updates safely")
            actionText: installing ? "" : Tr.tr("Install")
            onAction: Packages.install({
                source: "repo",
                name: "fwupd"
            }, () => root.load(false))
        }

        InfoRow {
            visible: root.installed && root.needsReboot
            icon: "restart_alt"
            iconColour: Colours.palette.m3primary
            label: Tr.tr("Restart to finish firmware update")
            subtext: Tr.tr("Staged firmware updates are applied on next reboot")
        }

        RowButton {
            visible: root.installed && root.needsReboot
            icon: "power_settings_new"
            text: Tr.tr("Restart now…")
            subtext: Tr.tr("Asks to confirm before rebooting")
            onClicked: confirmDialog.ask({
                header: Tr.tr("Restart computer?"),
                body: Tr.tr("Your computer will restart to apply the staged firmware update. Keep power connected and save any open work."),
                confirmLabel: Tr.tr("Restart"),
                onConfirm: () => Quickshell.execDetached(["systemctl", "reboot"])
            })
        }

        InfoRow {
            visible: root.data === null || root.installed
            icon: root.loading ? "sync" : root.errorMsg ? "cloud_off" : root.updates.length > 0 ? "system_update" : "verified"
            iconColour: !root.loading && root.errorMsg ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
            label: root.loading ? Tr.tr("Checking firmware devices…") : root.errorMsg ? Tr.tr("Couldn't check firmware updates") : root.updates.length === 1 ? Tr.tr("1 firmware update available") : root.updates.length > 1 ? Tr.tr("%1 firmware updates available").arg(root.updates.length) : Tr.tr("All firmware is up to date")
            subtext: root.errorMsg ? root.errorMsg : root.devices.length > 0 ? Tr.trN("%n updatable device detected", "%n updatable devices detected", root.devices.length) : ""
        }

        RowButton {
            visible: root.installed
            icon: "refresh"
            text: Tr.tr("Check for updates")
            subtext: root.loading ? Tr.tr("Refreshing LVFS firmware metadata…") : Tr.tr("Refresh LVFS metadata and check connected hardware")
            disabled: root.loading || root.busy
            onClicked: root.load(true)
        }

        RowButton {
            visible: root.installed && root.updates.length > 0
            icon: "download"
            text: Tr.tr("Install all firmware updates")
            subtext: Tr.tr("Keep AC power connected and do not shut down during the update")
            disabled: root.loading || root.busy
            onClicked: confirmDialog.ask({
                header: Tr.tr("Install all firmware updates?"),
                body: Tr.tr("Installs %1 pending firmware update(s). Keep power connected and wait for completion before turning off your computer.").arg(root.updates.length),
                confirmLabel: Tr.trCtx("Install", "button"),
                onConfirm: () => Admin.run("fwupd-update", [], root.updateAllWhat, (ok, out) => {
                    root.noteUpdate(ok, out);
                    root.load(false);
                })
            })
        }

        SectionHeader {
            visible: root.updates.length > 0
            text: Tr.tr("Available updates (%1)").arg(root.updates.length)
        }

        Repeater {
            model: root.updates

            ConnectedRect {
                id: upd

                required property var modelData
                readonly property string what: root.rowWhat(modelData.name)
                readonly property bool rowBusy: Admin.jobs.some(j => j.what === what)

                Layout.fillWidth: true
                implicitHeight: updCol.implicitHeight + Tokens.padding.medium * 2

                ColumnLayout {
                    id: updCol

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.largeIncreased
                    spacing: Tokens.spacing.small

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.medium

                        MaterialIcon {
                            text: "memory"
                            color: Colours.palette.m3primary
                            fontStyle: Tokens.font.icon.medium
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: upd.modelData.name
                                font: Tokens.font.body.small
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: `${upd.modelData.currentVersion || "?"} → ${upd.modelData.newVersion}` + (upd.modelData.vendor ? ` · ${upd.modelData.vendor}` : "") + (upd.modelData.summary ? ` · ${upd.modelData.summary}` : "")
                                color: Colours.palette.m3outline
                                font: Tokens.font.label.small
                                wrapMode: Text.WordWrap
                            }
                        }

                        TextButton {
                            text: upd.rowBusy ? Tr.tr("Updating…") : Tr.tr("Update")
                            type: TextButton.Filled
                            disabled: root.busy || root.loading
                            onClicked: confirmDialog.ask({
                                header: Tr.tr("Update %1?").arg(upd.modelData.name),
                                body: Tr.tr("Update firmware from %1 to %2? Keep power connected until it finishes.").arg(upd.modelData.currentVersion || "?").arg(upd.modelData.newVersion),
                                confirmLabel: Tr.tr("Update"),
                                onConfirm: () => Admin.run("fwupd-update", [upd.modelData.id], upd.what, (ok, out) => {
                                    root.noteUpdate(ok, out);
                                    root.load(false);
                                })
                            })
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: !!upd.modelData.description
                        text: upd.modelData.description
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        SectionHeader {
            visible: root.devices.length > 0
            text: Tr.tr("Supported devices")
        }

        Repeater {
            model: root.devices

            InfoRow {
                required property var modelData

                icon: modelData.isInternal ? "memory" : "usb"
                label: modelData.name
                subtext: [modelData.vendor, modelData.summary].filter(Boolean).join(" · ")
                value: modelData.version || Tr.tr("Unknown")
            }
        }

        ConfirmDialog {
            id: confirmDialog

            hostFlickable: root.flickable
        }
    }
}
