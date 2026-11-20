import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// A section's title. With rows under it, it's the top of their card (an icon and the title,
// like DankMaterialShell's settings); with no rows under it (text or other things follow), a
// plain label above them. `icon` picks the card's icon; by default one that fits the title.
ConnectedRect {
    id: root

    property alias text: label.text
    property string icon: guessIcon(text)
    // For the search's highlight (it tells rows apart by their section)
    readonly property bool isSectionHeader: true
    // A card's top: rows follow (frozen when hidden so tab switches never flash from transparent)
    readonly property bool rawCard: !Rows.isLast(root)
    property bool card: false

    function syncCard(): void {
        if (root.visible)
            root.card = root.rawCard;
    }

    onRawCardChanged: if (visible)
        Qt.callLater(syncCard)
    onVisibleChanged: if (visible)
        Qt.callLater(syncCard)
    Component.onCompleted: card = rawCard

    // The first thing on its page: no gap above
    readonly property bool atTop: {
        void Rows.revision;
        const h = Rows.host(root);
        const kids = h?.parent?.children ?? [];
        for (const k of kids) {
            if (k === h)
                return true;
            if (k.visible && (k.implicitHeight > 0 || k.height > 0))
                return false;
        }
        return true;
    }

    function guessIcon(t: string): string {
        const s = (t ?? "").toLowerCase();
        const table = [[/blur|glass|transparen|opacity/, "blur_on"], [/wallpaper|background/, "wallpaper"], [/colou?r|theme|scheme|palette/, "palette"], [/font|text|typograph/, "text_fields"], [/notif|popup/, "notifications"], [/sound|audio|volume|output|input device|microphone/, "volume_up"], [/sleep|suspend/, "bedtime"], [/power button/, "power_settings_new"], [/power/, "bolt"], [/battery/, "battery_full"], [/wi-?fi|network|ethernet|vpn|internet/, "wifi"], [/bluetooth/, "bluetooth"], [/night/, "nightlight"], [/display|monitor|screen|resolution/, "monitor"], [/keyboard|shortcut|keys|binding/, "keyboard"], [/mouse|touchpad|pointer|cursor/, "mouse"], [/window|title bar|snap/, "select_window"], [/workspace/, "view_carousel"], [/launcher|search/, "apps"], [/dashboard|panel|bar|taskbar/, "dashboard"], [/time|clock|date|calendar/, "schedule"], [/language|region|locale/, "language"], [/privacy|security|lock|password/, "lock"], [/update|package|kernel/, "system_update"], [/storage|disk|drive|snapshot|backup/, "hard_drive"], [/game|gaming|proton|steam/, "sports_esports"], [/account|user|profile|people/, "person"], [/anim|motion/, "animation"], [/media|music|player|lyric/, "music_note"], [/record/, "videocam"], [/screenshot|capture/, "screenshot"], [/widget/, "widgets"], [/app/, "apps"], [/startup|autostart/, "rocket_launch"], [/print/, "print"], [/access/, "accessibility_new"], [/advanced|developer|debug/, "build"], [/about|info/, "info"]];
        for (const [re, icon] of table)
            if (re.test(s))
                return icon;
        return "tune";
    }

    first: true
    groupStart: true
    color: "transparent"

    Layout.fillWidth: true
    Layout.topMargin: atTop ? 0 : Tokens.spacing.largeIncreased - ((Rows.host(root)?.parent as ColumnLayout)?.spacing ?? 0)
    Layout.bottomMargin: card ? 0 : Tokens.spacing.extraSmall
    implicitHeight: row.implicitHeight + (card ? Tokens.padding.large + Tokens.padding.small : 0)

    StyledRect {
        anchors.fill: parent
        visible: root.card
        color: Colours.tPalette.m3surfaceContainer
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
    }

    RowLayout {
        id: row

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.card ? Tokens.padding.extraSmall / 2 : 0
        anchors.leftMargin: root.card ? Tokens.padding.largeIncreased : Tokens.padding.small
        anchors.rightMargin: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.small

        MaterialIcon {
            visible: root.card && root.icon !== ""
            text: root.icon
            color: Colours.palette.m3primary
            fontStyle: Tokens.font.icon.small
        }

        StyledText {
            id: label

            Layout.fillWidth: true
            color: root.card ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
            font: root.card ? Tokens.font.title.small : Tokens.font.label.medium
            elide: Text.ElideRight
        }
    }
}
