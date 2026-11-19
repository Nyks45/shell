pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services

// Interactive Bluetooth pairing card (PIN, passkey confirmation, passkey
// display, or service authorization), styled to match PolkitCard.
Item {
    id: root

    readonly property var req: BluetoothAgent.request
    readonly property string kind: req?.kind ?? ""
    readonly property bool isInput: kind === "pin" || kind === "passkey"
    readonly property bool isDisplay: kind === "displayPasskey" || kind === "displayPin"
    readonly property bool isConfirm: kind === "confirm"
    readonly property bool isAuth: kind === "authorize" || kind === "authorizeService"

    readonly property string spacedCode: {
        const s = String(req?.passkey ?? req?.pin ?? "");
        return s.length === 6 && /^\d{6}$/.test(s) ? `${s.slice(0, 3)} ${s.slice(3)}` : s;
    }

    function submitInput(): void {
        if (!isInput)
            return;
        const val = field.text.trim();
        if (!val)
            return;
        if (kind === "passkey" && !/^\d{1,6}$/.test(val))
            return;
        BluetoothAgent.submit(val);
    }

    implicitWidth: Math.min(Tokens.sizes.nexus.maxDialogWidth * 1.15, 460)
    implicitHeight: layout.implicitHeight + Tokens.padding.extraLarge + Tokens.padding.largeIncreased

    Keys.onEscapePressed: BluetoothAgent.dismiss()

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
            text: root.isDisplay ? "keyboard" : "bluetooth_searching"
            color: Colours.palette.m3secondary
            fontStyle: Tokens.font.icon.large
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: {
                const name = root.req?.device || Tr.tr("Bluetooth device");
                if (root.isDisplay)
                    return Tr.tr("Type this code on %1").arg(name);
                if (root.isInput)
                    return Tr.tr("Enter code for %1").arg(name);
                if (root.isAuth)
                    return Tr.tr("Allow %1?").arg(name);
                return Tr.tr("Pair with %1?").arg(name);
            }
            font: Tokens.font.title.builders.large.weight(Font.Normal).build()
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: {
                if (root.isConfirm)
                    return Tr.tr("Check that this number matches the one shown on %1.").arg(root.req?.device || Tr.tr("the device"));
                if (root.isDisplay)
                    return Tr.tr("Type the digits below on your Bluetooth device and press Enter.");
                if (root.isInput)
                    return root.kind === "passkey" ? Tr.tr("Enter the 6-digit passkey shown in the device manual or screen.") : Tr.tr("Enter the pairing PIN code (for example 0000 or 1234).");
                if (root.kind === "authorizeService" && root.req?.service)
                    return Tr.tr("Requests access to: %1").arg(root.req.service);
                return Tr.tr("Accept incoming pairing request from %1?").arg(root.req?.address || root.req?.device || "");
            }
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.medium
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            visible: !!(root.req?.address)
            text: root.req?.address ?? ""
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }

        StyledRect {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            visible: root.isConfirm || root.isDisplay
            implicitHeight: codeRow.implicitHeight + Tokens.padding.large * 2
            radius: Tokens.rounding.large
            color: Colours.palette.m3surfaceContainer

            Row {
                id: codeRow

                anchors.centerIn: parent
                spacing: 0

                StyledText {
                    visible: root.kind === "displayPasskey" && (root.req?.entered ?? 0) > 0
                    text: root.spacedCode.slice(0, Math.min(root.spacedCode.length, (root.req?.entered ?? 0) + ((root.req?.entered ?? 0) > 3 ? 1 : 0)))
                    font: Tokens.font.mono.large
                    color: Colours.palette.m3primary
                }

                StyledText {
                    text: root.kind === "displayPasskey" && (root.req?.entered ?? 0) > 0
                        ? root.spacedCode.slice(Math.min(root.spacedCode.length, (root.req?.entered ?? 0) + ((root.req?.entered ?? 0) > 3 ? 1 : 0)))
                        : root.spacedCode
                    font: Tokens.font.mono.large
                    color: Colours.palette.m3onSurface
                }
            }
        }

        StyledTextField {
            id: field

            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            visible: root.isInput
            placeholderText: root.kind === "passkey" ? Tr.tr("6-digit passkey") : Tr.tr("PIN code")
            leadingIcon: "pin"
            maximumLength: root.kind === "passkey" ? 6 : 16
            inputMethodHints: root.kind === "passkey" ? Qt.ImhDigitsOnly : Qt.ImhNoPredictiveText
            onAccepted: root.submitInput()
            Keys.onEscapePressed: BluetoothAgent.dismiss()
            onVisibleChanged: if (visible)
                forceActiveFocus()
            Component.onCompleted: if (visible)
                forceActiveFocus()
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            Layout.topMargin: Tokens.spacing.small
            spacing: Tokens.spacing.extraSmall

            TextButton {
                visible: !root.isDisplay
                type: TextButton.Text
                isRound: true
                horizontalPadding: Tokens.padding.largeIncreased
                verticalPadding: Tokens.padding.medium
                text: root.isAuth ? Tr.tr("Reject") : Tr.trCtx("Cancel", "button")
                onClicked: BluetoothAgent.reject()
            }

            TextButton {
                type: root.isDisplay ? TextButton.Tonal : TextButton.Filled
                isRound: true
                horizontalPadding: Tokens.padding.largeIncreased
                verticalPadding: Tokens.padding.medium
                disabled: root.isInput && (!field.text.trim() || (root.kind === "passkey" && !/^\d{1,6}$/.test(field.text.trim())))
                text: {
                    if (root.isDisplay)
                        return Tr.trCtx("Close", "button");
                    if (root.isAuth)
                        return Tr.trCtx("Allow", "button");
                    return Tr.tr("Pair");
                }
                onClicked: {
                    if (root.isDisplay)
                        BluetoothAgent.dismiss();
                    else if (root.isInput)
                        root.submitInput();
                    else
                        BluetoothAgent.confirm();
                }
            }
        }
    }
}
