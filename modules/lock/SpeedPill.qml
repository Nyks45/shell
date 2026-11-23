import QtQuick

Rectangle {
    id: pill

    property string arrow: ""
    property color accent: LockTheme.colors.tertiary
    property string text: ""

    height: 26
    radius: 13
    color: Qt.alpha(LockTheme.colors.surfaceContainerHighest, 0.6)

    Rectangle {
        x: 3
        anchors.verticalCenter: parent.verticalCenter
        width: 20
        height: 20
        radius: 10
        color: Qt.alpha(pill.accent, 0.2)

        Text {
            anchors.centerIn: parent
            text: pill.arrow
            font.family: LockTheme.font.icons
            font.pixelSize: 12
            color: pill.accent
        }
    }

    Text {
        x: 30
        width: parent.width - 36
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        text: pill.text
        font.family: LockTheme.font.family
        font.pixelSize: 12
        font.weight: Font.DemiBold
        color: LockTheme.colors.textOnSurface
    }
}
