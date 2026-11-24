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

// Editable list of apps (pinned, hidden, ignore rules) backed by AppPickerDialog.
ColumnLayout {
    id: root

    required property Item hostFlickable
    property list<string> values
    property string addLabel: Tr.tr("Add an app")
    property string emptyText: Tr.tr("None")
    property string pickerHeader: Tr.tr("Choose an app")
    property bool includeRunning: false
    property bool allowCustom: true
    property bool useWmClass: false
    property var validate: null

    signal edited(values: list<string>)

    Layout.fillWidth: true
    spacing: Tokens.spacing.extraSmall / 2

    Repeater {
        model: root.values

        ConnectedRect {
            id: entryRect

            required property string modelData
            required property int index
            readonly property DesktopEntry desktopEntry: DesktopEntries.byId(modelData) ?? DesktopEntries.heuristicLookup(modelData)

            Layout.fillWidth: true
            implicitHeight: Math.ceil(entryRow.implicitHeight) + Tokens.padding.small * 2

            RowLayout {
                id: entryRow

                anchors.fill: parent
                anchors.margins: Tokens.padding.small
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.medium
                spacing: Tokens.spacing.medium

                Item {
                    implicitWidth: 24
                    implicitHeight: 24

                    ThemedIcon {
                        anchors.fill: parent
                        asynchronous: true
                        monochrome: true
                        visible: !!(entryRect.desktopEntry?.icon)
                        source: entryRect.desktopEntry?.icon ? Quickshell.iconPath(entryRect.desktopEntry.icon, "application-x-executable") : ""
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: !(entryRect.desktopEntry?.icon)
                        text: entryRect.desktopEntry ? "apps" : "code"
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.medium
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: entryRect.desktopEntry ? entryRect.desktopEntry.name : entryRect.modelData
                        font: entryRect.desktopEntry ? Tokens.font.body.small : Tokens.font.mono.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: !entryRect.desktopEntry || entryRect.modelData !== entryRect.desktopEntry.id
                        text: entryRect.desktopEntry ? entryRect.modelData : Tr.tr("Pattern")
                        font: Tokens.font.label.small
                        color: Colours.palette.m3outline
                        elide: Text.ElideRight
                    }
                }

                IconButton {
                    icon: "close"
                    type: IconButton.Text
                    onClicked: {
                        const next = [...root.values];
                        next.splice(entryRect.index, 1);
                        root.edited(next);
                    }
                }
            }
        }
    }

    RowButton {
        icon: "add"
        text: root.addLabel
        subtext: root.values.length === 0 ? root.emptyText : ""
        onClicked: picker.openPicker({
            header: root.pickerHeader,
            includeRunning: root.includeRunning,
            allowCustom: root.allowCustom,
            customValidate: root.validate,
            excludeIds: [...root.values],
            onPicked: item => {
                const val = root.useWmClass ? (item.wmClass || item.id) : item.id;
                if (val && !root.values.includes(val))
                    root.edited([...root.values, val]);
            }
        })
    }

    AppPickerDialog {
        id: picker

        hostFlickable: root.hostFlickable
    }
}
