pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components.controls

// The sub-settings of a page (TabParts), one at a time. At first only a row
// for each (what it has); once one is chosen, its settings below and chips
// above to switch to another.
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
        visible: root.chosen
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

    Repeater {
        model: root.chosen ? [] : root.parts

        NavRow {
            required property Item modelData

            icon: modelData.icon
            text: modelData.title
            subtext: modelData.summary
            onClicked: root.show(modelData)
        }
    }
}
