pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.services

// Reusable confirmation modal built on DialogRowButton so destructive actions
// across Settings pages ask clearly with consistent layout and text wrapping.
DialogRowButton {
    id: root

    property Item hostFlickable: null
    property string headerText
    property string bodyText
    property string warningText
    property string confirmLabel: Tr.tr("Confirm")
    property var callback: null

    function ask(opts: var): void {
        headerText = opts.header ?? Tr.tr("Are you sure?");
        bodyText = opts.body ?? "";
        warningText = opts.warning ?? "";
        confirmLabel = opts.confirmLabel ?? Tr.tr("Confirm");
        icon = opts.icon ?? "warning";
        callback = opts.onConfirm ?? null;
        open = true;
    }

    visible: false
    rootParent: hostFlickable
    openWidth: Math.min((hostFlickable?.width ?? 600) * 0.85, 460)
    openHeight: Math.min((hostFlickable?.height ?? 600) * 0.9, (bodyText.length + warningText.length) > 160 ? 340 : 250)
    icon: "warning"
    label: ""
    header: headerText
    acceptLabel: confirmLabel
    content: Component {
        ColumnLayout {
            spacing: Tokens.spacing.medium

            StyledFlickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: Tokens.spacing.medium
                clip: true
                contentHeight: bodyCol.implicitHeight
                contentWidth: width

                ColumnLayout {
                    id: bodyCol

                    width: parent.width
                    spacing: Tokens.spacing.small

                    StyledText {
                        Layout.fillWidth: true
                        visible: root.bodyText.length > 0
                        text: root.bodyText
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        wrapMode: Text.Wrap
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: root.warningText.length > 0
                        text: root.warningText
                        color: Colours.palette.m3error
                        font: Tokens.font.body.small
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }
    onAccepted: {
        const cb = callback;
        callback = null;
        if (typeof cb === "function")
            cb();
    }
    onCancelled: callback = null
}
