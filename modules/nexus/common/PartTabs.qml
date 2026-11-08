pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components.controls

// The sub-settings of a page (TabParts): switchers on top; a part's settings
// show once it is chosen (none at first).
ColumnLayout {
    id: root

    required property list<Item> parts
    readonly property bool chosen: parts.some(p => p.open)

    function show(part: Item): void {
        for (const p of parts)
            p.open = p === part;
    }

    Layout.fillWidth: true
    spacing: Tokens.spacing.extraSmall / 2

    Flow {
        Layout.fillWidth: true
        Layout.bottomMargin: Tokens.spacing.medium
        spacing: Tokens.spacing.small

        Repeater {
            model: root.parts

            TextButton {
                required property Item modelData

                text: modelData.title
                isToggle: true
                followChecked: true
                checked: modelData.open
                type: TextButton.Tonal
                onClicked: root.show(modelData)
            }
        }
    }
}
