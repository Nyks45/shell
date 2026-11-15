pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import Quickshell.Io
import qs.components
import qs.components.filedialog
import qs.services

StyledRect {
    id: root

    required property var dialog

    implicitWidth: Sizes.sidebarWidth
    implicitHeight: inner.implicitHeight + Tokens.padding.medium * 2

    color: Colours.tPalette.m3surfaceContainer

    // Mounted drives outside home: /mnt/*, /media/*, /run/media/<user>/*
    property list<string> drives: []

    Process {
        running: true
        command: ["findmnt", "-rno", "TARGET"]
        stdout: StdioCollector {
            onStreamFinished: root.drives = text.trim().split("\n").map(l => l.replace(/\\x20/g, " ")).filter(t => /^\/(mnt|media|run\/media\/[^/]+)\/[^/]+$/.test(t)).sort()
        }
    }

    ColumnLayout {
        id: inner

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tokens.padding.medium
        spacing: Tokens.spacing.extraSmall

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Tokens.padding.extraSmall / 2
            Layout.bottomMargin: Tokens.spacing.medium
            text: Tr.trCtx("Files", "file dialog sidebar heading")
            color: Colours.palette.m3onSurface
            font: Tokens.font.body.builders.large.weight(Font.Bold).build()
        }

        Repeater {
            // Home's folders, the whole computer, then every mounted drive (other partitions,
            // USB sticks): "cwd" lists the path's parts from "Home" or from "/"
            model: [...["Home", "Downloads", "Desktop", "Documents", "Music", "Pictures", "Videos"].map(n => ({
                        name: n,
                        icon: "",
                        cwd: n === "Home" ? ["Home"] : ["Home", n]
                    })), {
                    name: Tr.trCtx("Computer", "file dialog: the whole file system"),
                    icon: "computer",
                    cwd: ["/"]
                }, ...root.drives.map(d => ({
                        name: d.split("/").pop(),
                        icon: d.startsWith("/run/media") || d.startsWith("/media") ? "usb" : "hard_drive",
                        cwd: ["/", ...d.split("/").filter(x => x)]
                    }))]

            StyledRect {
                id: place

                required property var modelData
                readonly property bool selected: JSON.stringify(modelData.cwd) === JSON.stringify(Array.from(root.dialog.cwd))

                Layout.fillWidth: true
                implicitHeight: placeInner.implicitHeight + Tokens.padding.medium * 2

                radius: Tokens.rounding.full
                color: Qt.alpha(Colours.palette.m3secondaryContainer, selected ? 1 : 0)

                StateLayer {
                    color: place.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                    onClicked: root.dialog.cwd = place.modelData.cwd
                }

                RowLayout {
                    id: placeInner

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    anchors.leftMargin: Tokens.padding.large
                    anchors.rightMargin: Tokens.padding.large

                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: {
                            if (place.modelData.icon)
                                return place.modelData.icon;
                            const p = place.modelData.name;
                            if (p === "Home")
                                return "home";
                            if (p === "Downloads")
                                return "file_download";
                            if (p === "Desktop")
                                return "desktop_windows";
                            if (p === "Documents")
                                return "description";
                            if (p === "Music")
                                return "music_note";
                            if (p === "Pictures")
                                return "image";
                            if (p === "Videos")
                                return "video_library";
                            return "folder";
                        }
                        color: place.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                        fontStyle: Tokens.font.icon.medium
                        fill: place.selected ? 1 : 0

                        Behavior on fill {
                            Anim {
                                type: Anim.DefaultEffects
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: place.modelData.name
                        color: place.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
