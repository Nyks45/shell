pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services

// The password prompt (a polkit request), styled like the settings' dialogs:
// what it is for, the password, Cancel / Allow. Shown inside a focused
// settings window, or over the screen (PolkitOverlay).
Item {
    id: root

    readonly property var flow: Polkit.flow
    // Submitted, waiting for polkit's answer
    property bool checking
    property bool wrongPassword

    function submit(): void {
        if (!flow?.isResponseRequired || checking)
            return;
        checking = true;
        wrongPassword = false;
        Polkit.submit(field.text);
        field.text = "";
    }

    function focusField(): void {
        field.forceActiveFocus();
    }

    implicitWidth: Math.min(Tokens.sizes.nexus.maxDialogWidth * 1.15, 460)
    implicitHeight: layout.implicitHeight + Tokens.padding.extraLarge + Tokens.padding.largeIncreased

    Keys.onEscapePressed: Polkit.cancel()

    Connections {
        function onIsResponseRequiredChanged(): void {
            if (root.flow?.isResponseRequired) {
                root.checking = false;
                root.focusField();
            }
        }

        function onAuthenticationFailed(): void {
            root.checking = false;
            root.wrongPassword = true;
            root.focusField();
        }

        target: root.flow
        ignoreUnknownSignals: true
    }

    Elevation {
        anchors.fill: parent
        radius: bg.radius
        level: 4
    }

    StyledRect {
        id: bg

        anchors.fill: parent
        radius: Tokens.rounding.extraLargeIncreased
        color: Colours.palette.m3surfaceContainerHighest
    }

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tokens.padding.extraLarge
        spacing: Tokens.spacing.medium

        MaterialIcon {
            Layout.alignment: Qt.AlignHCenter
            text: "admin_panel_settings"
            color: Colours.palette.m3secondary
            fontStyle: Tokens.font.icon.large
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Polkit.ours || Polkit.context ? Tr.tr("Allow this change?") : Tr.tr("Password needed")
            font: Tokens.font.title.builders.large.weight(Font.Normal).build()
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Polkit.context || (root.flow?.message ?? "")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.medium
            wrapMode: Text.WordWrap
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            visible: text !== ""
            text: Polkit.ours || Polkit.context ? Tr.tr("It changes the system, so it needs your password.") : ""
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        StyledTextField {
            id: field

            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            focus: true
            echoMode: (root.flow?.responseVisible ?? false) ? TextInput.Normal : TextInput.Password
            placeholderText: {
                const p = (root.flow?.inputPrompt ?? "").replace(/:\s*$/, "").trim();
                return !p || /^password$/i.test(p) ? Tr.tr("Password") : p;
            }
            leadingIcon: "key"
            enabled: !root.checking
            isError: root.wrongPassword || (root.flow?.supplementaryIsError ?? false)
            errorText: root.flow?.supplementaryIsError && root.flow.supplementaryMessage ? root.flow.supplementaryMessage : Tr.tr("That password didn't work. Try again.")
            supportingText: !root.flow?.supplementaryIsError ? (root.flow?.supplementaryMessage ?? "") : ""
            onAccepted: root.submit()
            Keys.onEscapePressed: Polkit.cancel()
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            Layout.topMargin: Tokens.spacing.small
            spacing: Tokens.spacing.extraSmall

            LoadingIndicator {
                visible: root.checking
                implicitWidth: Tokens.font.icon.medium.pointSize * 2
                implicitHeight: implicitWidth
            }

            TextButton {
                type: TextButton.Text
                isRound: true
                horizontalPadding: Tokens.padding.largeIncreased
                verticalPadding: Tokens.padding.medium
                text: Tr.trCtx("Cancel", "button")
                onClicked: Polkit.cancel()
            }

            TextButton {
                type: TextButton.Filled
                isRound: true
                horizontalPadding: Tokens.padding.largeIncreased
                verticalPadding: Tokens.padding.medium
                disabled: root.checking || !(root.flow?.isResponseRequired ?? false)
                text: Polkit.ours || Polkit.context ? Tr.trCtx("Allow", "button") : Tr.trCtx("Authenticate", "button")
                onClicked: root.submit()
            }
        }
    }
}
