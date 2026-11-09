pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

// Kernels (the CachyOS Kernel Manager's job): the installed ones (the running
// one marked), more to install (with their headers and NVIDIA modules,
// signed for Secure Boot and added to the boot menu), removing one (never
// the running one or the last one).
PageBase {
    id: root

    // caelestia-system kernels: { installed, available }
    property var data: null
    property bool showAll

    readonly property var notInstalled: (data?.available ?? []).filter(a => !a.installed)
    // CachyOS's own first (tuned for this system), then Arch's
    readonly property var offered: [...notInstalled.filter(a => a.name.startsWith("linux-cachyos")), ...notInstalled.filter(a => !a.name.startsWith("linux-cachyos"))]

    function load(): void {
        proc.running = true;
    }

    title: Tr.tr("Kernels")

    Component.onCompleted: load()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Installed")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            visible: !root.data
            text: Tr.tr("Reading…")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
        }

        // One row per kernel (siblings: the group's corners are right),
        // Remove inside the row
        Repeater {
            model: root.data?.installed ?? []

            ConnectedRect {
                id: k

                required property var modelData

                readonly property string removeWhat: Tr.tr("Remove the kernel %1").arg(modelData.name)
                readonly property bool removing: Admin.jobs.some(j => j.what === removeWhat)

                Layout.fillWidth: true
                implicitHeight: kRow.implicitHeight + Tokens.padding.medium * 2

                RowLayout {
                    id: kRow

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.largeIncreased
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: k.modelData.running ? "play_circle" : "memory"
                        color: k.modelData.running ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.medium
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: k.modelData.name
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: [k.modelData.version, k.modelData.running ? Tr.tr("running now") : "", k.modelData.headers ? Tr.tr("headers") : "", k.modelData.nvidia ? Tr.tr("NVIDIA modules") : ""].filter(s => s).join(" · ")
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }

                    TextButton {
                        visible: !k.modelData.running && (root.data?.installed.length ?? 0) > 1
                        enabled: !k.removing
                        text: k.removing ? Tr.tr("Removing…") : Tr.tr("Remove")
                        type: TextButton.Tonal
                        onClicked: Admin.run("kernel-remove", [k.modelData.name], k.removeWhat, () => root.load())
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.topMargin: Tokens.spacing.small
            visible: (root.data?.installed.length ?? 0) > 1
            text: Tr.tr("In the boot menu, the other kernels are inside the CachyOS entry (its submenu: F2 or Insert on it).")
            wrapMode: Text.WordWrap
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }

        SectionHeader {
            visible: root.offered.length > 0
            text: Tr.tr("More kernels")
        }

        Repeater {
            model: root.showAll ? root.offered : root.offered.slice(0, 8)

            RowButton {
                id: av

                required property var modelData

                readonly property string what: Tr.tr("Install the kernel %1").arg(modelData.name)
                readonly property bool working: Admin.jobs.some(j => j.what === what)

                Layout.fillWidth: true
                disabled: working
                icon: working ? "downloading" : "add"
                text: modelData.name
                subtext: working ? Tr.tr("Installing (with headers and modules), signing, adding to the boot menu…") : `${modelData.version} · ${modelData.desc}`
                onClicked: Admin.run("kernel-install", [modelData.name], what, () => root.load())
            }
        }

        RowButton {
            Layout.fillWidth: true
            visible: !root.showAll && root.offered.length > 8
            icon: "expand_more"
            text: Tr.tr("Show all %1").arg(root.offered.length)
            onClicked: root.showAll = true
        }

        Process {
            id: proc

            command: [`${Paths.libdir}/caelestia-system`, "kernels"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        root.data = JSON.parse(text);
                    } catch (e) {}
                }
            }
        }
    }
}
