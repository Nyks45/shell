pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components.controls
import qs.modules.nexus

// The sub-settings of a page (TabParts): switchers on top, one part's
// settings below (the first at first).
ColumnLayout {
    id: root

    required property list<Item> parts
    readonly property bool chosen: parts.some(p => p.open)

    function show(part: Item): void {
        for (const p of parts)
            p.open = p === part;
    }

    function findPart(k: string): Item {
        return parts.find(p => p.key === k || p.altKeys.includes(k)) ?? null;
    }

    // The Settings this page is in (its page's nState)
    function ownState(): var {
        for (let p = root.parent; p; p = p.parent)
            if (p.nState !== undefined)
                return p.nState;
        return null;
    }

    // A pending tab is for the Settings that asked for it (or any, if none said)
    function pendingForMe(): bool {
        return !PageRegistry.pendingTabFor || PageRegistry.pendingTabFor === ownState();
    }

    Layout.fillWidth: true
    spacing: Tokens.spacing.extraSmall / 2

    Component.onCompleted: {
        // Opened at a former page id: that tab
        const pending = PageRegistry.pendingTab && Date.now() - PageRegistry.pendingTabAt < 3000 && pendingForMe();
        const wanted = pending ? findPart(PageRegistry.pendingTab) : null;
        if (wanted) {
            show(wanted);
        } else if (!chosen && parts.length > 0) {
            show(parts[0]);
        }
    }

    // A link to one of these tabs while the page is already open
    Connections {
        function onPendingTabAtChanged(): void {
            if (!root.pendingForMe())
                return;
            const wanted = root.findPart(PageRegistry.pendingTab);
            if (wanted)
                root.show(wanted);
        }

        target: PageRegistry
    }

    Flow {
        Layout.fillWidth: true
        Layout.bottomMargin: Tokens.spacing.medium
        spacing: Tokens.spacing.small

        Repeater {
            model: root.parts

            TextButton {
                required property Item modelData

                text: modelData?.title ?? ""
                isToggle: true
                followChecked: true
                checked: !!modelData?.open
                type: TextButton.Tonal
                onClicked: root.show(modelData)
            }
        }
    }
}
