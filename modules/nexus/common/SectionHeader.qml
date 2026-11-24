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
    property alias subtext: subLabel.text
    property alias subtextColour: subLabel.color
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

    onRawCardChanged: syncCard()
    onVisibleChanged: syncCard()
    Component.onCompleted: card = rawCard

    // The first thing on its page (across nested Section/Repeater columns): no gap above
    readonly property bool atTop: Rows.isAtTop(root)

    function guessIcon(t: string): string {
        const s = (t ?? "").toLowerCase();
        const table = [
            [/blur|glass|transparen|opacity/, "blur_on"],
            [/wallpaper|background/, "wallpaper"],
            [/brightness/, "brightness_6"],
            [/colou?r|theme|scheme|palette/, "palette"],
            [/font|text|typograph/, "text_fields"],
            [/do not disturb|dnd/, "do_not_disturb_on"],
            [/shell message/, "notifications_active"],
            [/notif|popup/, "notifications"],
            [/recording|^input\b|microphone|mic\b/, "mic"],
            [/device profile|codec/, "speaker"],
            [/sound|audio|volume|output|input device/, "volume_up"],
            [/keep awake|inhibit|awake/, "visibility"],
            [/vision|seeing/, "visibility"],
            [/hearing/, "hearing"],
            [/interaction/, "touch_app"],
            [/performance/, "speed"],
            [/sleep|suspend/, "bedtime"],
            [/power button/, "power_settings_new"],
            [/power/, "bolt"],
            [/battery/, "battery_full"],
            [/routing mode|app routing|split tunnel/, "alt_route"],
            [/vpn/, "vpn_key"],
            [/dns/, "dns"],
            [/connection|ipv4|ipv6|ethernet/, "lan"],
            [/wi-?fi|network|internet/, "wifi"],
            [/filter|custom rule/, "filter_list"],
            [/bluetooth/, "bluetooth"],
            [/night/, "nightlight"],
            [/display|monitor|screen|resolution/, "monitor"],
            [/keyboard|shortcut|keys|binding/, "keyboard"],
            [/mouse|touchpad|pointer|cursor/, "mouse"],
            [/window|title bar|snap|switcher|overview/, "select_window"],
            [/workspace/, "view_carousel"],
            [/launcher|search/, "apps"],
            [/dashboard|panel|bar|taskbar|quick setting/, "dashboard"],
            [/^shell$/, "layers"],
            [/time|clock|date|calendar|automatic check|^now$/, "schedule"],
            [/language|region|locale/, "language"],
            [/sign-?in/, "login"],
            [/privacy|security|lock|password|kept at their version/, "lock"],
            [/configuration changes/, "difference"],
            [/arch linux news|\bnews\b/, "newspaper"],
            [/firmware/, "system_update_alt"],
            [/update|package|kernel/, "system_update"],
            [/your own builds/, "build_circle"],
            [/^aur\b|plugin/, "extension"],
            [/^flatpak\b|widget/, "widgets"],
            [/home folder/, "home"],
            [/open files with/, "folder_open"],
            [/snapshots?/, "photo_camera"],
            [/clean ?up|maintenance/, "cleaning_services"],
            [/storage|disk|drive|backup/, "hard_drive"],
            [/add a game/, "add_circle"],
            [/shader/, "cached"],
            [/game|gaming|proton|steam/, "sports_esports"],
            [/account|user|profile|people/, "person"],
            [/history/, "history"],
            [/focus/, "center_focus_strong"],
            [/weather/, "cloud"],
            [/units/, "straighten"],
            [/dependencies/, "account_tree"],
            [/temperature/, "thermostat"],
            [/lighting|\brgb\b/, "lightbulb"],
            [/health/, "health_and_safety"],
            [/hardware|nvidia/, "memory"],
            [/logs?|crash/, "description"],
            [/statistics?/, "bar_chart"],
            [/icons?/, "interests"],
            [/anim|motion/, "animation"],
            [/media|music|player|lyric/, "music_note"],
            [/record/, "videocam"],
            [/screenshot|capture/, "screenshot"],
            [/startup|autostart/, "rocket_launch"],
            [/print/, "print"],
            [/access/, "accessibility_new"],
            [/advanced|developer|debug/, "build"],
            [/^more$/, "more_horiz"],
            [/this computer|\bsystem\b/, "computer"],
            [/^library$|\bapp/, "apps"],
            [/about|info|software|details/, "info"]
        ];
        for (const [re, icon] of table)
            if (re.test(s))
                return icon;
        return "tune";
    }

    first: true
    groupStart: true
    fillColour: root.card ? Colours.tPalette.m3surfaceContainer : "transparent"

    Layout.fillWidth: true
    Layout.topMargin: atTop ? 0 : Math.max(0, Tokens.spacing.largeIncreased - root.gap)
    Layout.bottomMargin: card ? 0 : Tokens.spacing.extraSmall
    implicitHeight: Math.ceil(col.implicitHeight) + (card ? Tokens.padding.large + Tokens.padding.small : 0)

    ColumnLayout {
        id: col

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.card && !subLabel.visible ? Tokens.padding.extraSmall / 2 : 0
        anchors.leftMargin: root.card ? Tokens.padding.largeIncreased : Tokens.padding.small
        anchors.rightMargin: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.extraSmall / 2

        RowLayout {
            id: row

            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            MaterialIcon {
                id: headerIcon

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

        StyledText {
            id: subLabel

            Layout.fillWidth: true
            Layout.leftMargin: (root.card && root.icon !== "") ? (headerIcon.implicitWidth + row.spacing) : 0
            visible: text.length > 0
            wrapMode: Text.WordWrap
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }
    }
}
