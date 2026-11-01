pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// A list of strings (e.g. app id patterns): each with a remove button, and a
// field to add one. Emits the whole new list.
ColumnLayout {
    id: root

    property list<string> values
    property string placeholderText: Tr.tr("Add…")
    property var validate: null
    property string emptyText

    signal edited(values: list<string>)

    Layout.fillWidth: true
    spacing: Tokens.spacing.extraSmall / 2

    StyledText {
        Layout.fillWidth: true
        Layout.leftMargin: Tokens.padding.small
        visible: root.values.length === 0 && root.emptyText
        text: root.emptyText
        color: Colours.palette.m3outline
        font: Tokens.font.label.small
    }

    Repeater {
        model: root.values

        ConnectedRect {
            id: entry

            required property string modelData
            required property int index

            Layout.fillWidth: true
            first: index === 0
            implicitHeight: entryRow.implicitHeight + Tokens.padding.small * 2

            RowLayout {
                id: entryRow

                anchors.fill: parent
                anchors.margins: Tokens.padding.small
                anchors.leftMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                StyledText {
                    Layout.fillWidth: true
                    text: entry.modelData
                    font: Tokens.font.mono.small
                    elide: Text.ElideRight
                }

                IconButton {
                    icon: "close"
                    type: IconButton.Text
                    onClicked: {
                        const next = [...root.values];
                        next.splice(entry.index, 1);
                        root.edited(next);
                    }
                }
            }
        }
    }

    // Adding one: a full-width field (the commands and patterns are long)
    ConnectedRect {
        Layout.fillWidth: true
        first: root.values.length === 0
        last: true
        implicitHeight: addRow.implicitHeight + Tokens.padding.small * 2

        RowLayout {
            id: addRow

            anchors.fill: parent
            anchors.margins: Tokens.padding.small
            anchors.leftMargin: Tokens.padding.largeIncreased
            spacing: Tokens.spacing.medium

            MaterialIcon {
                text: "add"
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.small
            }

            StyledTextField {
                id: field

                function commit(): void {
                    const t = text.trim();
                    if (!t || root.values.includes(t) || (root.validate && !root.validate(t)))
                        return;
                    root.edited([...root.values, t]);
                    text = "";
                }

                Layout.fillWidth: true
                placeholderText: root.placeholderText
                font: Tokens.font.mono.small
                validate: root.validate
                onAccepted: commit()
            }

            TextButton {
                text: Tr.trCtx("Add", "add an entry to a list")
                type: TextButton.Tonal
                disabled: !field.text.trim() || (root.validate && !root.validate(field.text.trim()))
                onClicked: field.commit()
            }
        }
    }
}
