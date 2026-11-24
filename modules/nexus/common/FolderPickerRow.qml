pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.filedialog
import qs.services
import qs.utils

// Shared row for picking a folder (or single file) with a Browse button and optional Reset.
ConnectedRect {
    id: root

    property string label
    property string subtext
    property string value
    property string placeholderText: Tr.tr("Default")
    property string defaultValue
    property bool canReset: false
    property bool folderMode: true
    property bool allowManual: false
    property var validate: null
    property string dialogTitle: folderMode ? Tr.tr("Select a folder") : Tr.tr("Select a file")
    property string icon: folderMode ? "folder_open" : "draft"

    signal picked(path: string)
    signal resetClicked

    Layout.fillWidth: true
    implicitHeight: Math.ceil(rowLayout.implicitHeight) + Tokens.padding.medium * 2

    RowLayout {
        id: rowLayout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Tokens.padding.largeIncreased
        anchors.rightMargin: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.medium

        MaterialIcon {
            visible: root.icon !== ""
            text: root.icon
            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.medium
            fill: 1
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                text: root.label
                font: Tokens.font.body.small
                wrapMode: Text.WordWrap
            }

            StyledText {
                Layout.fillWidth: true
                visible: !root.allowManual && (root.value.length > 0 || root.placeholderText.length > 0)
                text: root.value ? Paths.shortenHome(root.value) : root.placeholderText
                font: Tokens.font.mono.small
                color: root.value ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3outline
                wrapMode: Text.Wrap
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.subtext.length > 0
                text: root.subtext
                font: Tokens.font.label.small
                color: Colours.palette.m3outline
                wrapMode: Text.WordWrap
            }
        }

        Loader {
            active: root.allowManual
            visible: active
            Layout.preferredWidth: active ? Tokens.sizes.nexus.textFieldWidth : 0
            Layout.maximumWidth: root.width * 0.4
            Layout.alignment: Qt.AlignVCenter

            sourceComponent: StyledTextField {
                id: manualField

                verticalPadding: Tokens.padding.small
                floatingPlaceholder: false
                text: root.value
                validate: root.validate

                function commit(): void {
                    const t = text.trim();
                    if (!t)
                        return;
                    const ok = !root.validate || (typeof root.validate === "function" ? root.validate(t) : root.validate.test(t));
                    if (ok)
                        root.picked(t);
                }

                Component.onCompleted: cursorPosition = 0
                onActiveFocusChanged: if (!activeFocus)
                    cursorPosition = 0
                onEditingFinished: commit()

                Connections {
                    function onValueChanged(): void {
                        if (!manualField.activeFocus)
                            manualField.text = root.value;
                    }

                    target: root
                }
            }
        }

        IconButton {
            icon: "restart_alt"
            type: IconButton.Text
            visible: root.canReset && root.value.length > 0 && (!root.defaultValue || Paths.shortenHome(root.value) !== Paths.shortenHome(root.defaultValue))
            onClicked: root.resetClicked()
        }

        TextButton {
            text: Tr.tr("Browse")
            type: TextButton.Tonal
            onClicked: {
                const target = root.value || root.defaultValue;
                const openTarget = (!root.folderMode && target.includes("/")) ? (target.slice(0, target.lastIndexOf("/")) || "/") : target;
                dlg.openAt(openTarget);
            }
        }
    }

    FileDialog {
        id: dlg

        folderMode: root.folderMode
        title: root.dialogTitle
        onAccepted: path => root.picked(path)
    }
}
