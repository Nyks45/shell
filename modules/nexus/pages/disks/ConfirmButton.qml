pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// A row that opens a confirmation for something that erases data: it says
// what is lost and only allows going ahead once `confirmText` (the
// partition's or drive's name) is typed.
DialogRowButton {
    id: root

    required property string message
    required property string confirmText
    property string typed

    openHeight: Math.min(rootParent.height * 0.95, 400)
    acceptAllowed: typed === confirmText

    onOpenChanged: typed = ""

    content: Component {
        ColumnLayout {
            spacing: Tokens.spacing.medium

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.medium
                text: root.message
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                wrapMode: Text.WordWrap
            }

            StyledText {
                Layout.fillWidth: true
                text: Tr.tr("Type <b>%1</b> to go ahead:").arg(root.confirmText)
                textFormat: Text.StyledText
                font: Tokens.font.body.small
                wrapMode: Text.WordWrap
            }

            StyledTextField {
                Layout.fillWidth: true
                placeholderText: root.confirmText
                Component.onCompleted: forceActiveFocus()
                onTextChanged: root.typed = text
                onAccepted: if (root.acceptAllowed) {
                    root.accepted();
                    root.open = false;
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}
