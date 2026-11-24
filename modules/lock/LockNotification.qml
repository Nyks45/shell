import QtQuick
import M3Shapes

Item {
    id: root

    property string name: ""
    property int count: 1
    property string summary: ""
    property string photo: ""
    property string appIcon: ""
    property string glyph: ""
    property real morph: 0
    property real unit: 1

    readonly property real fade: Math.max(0, Math.min(1, (morph - 0.35) / 0.3))
    readonly property real idleFade: 1 - Math.max(0, Math.min(1, morph * 3))
    readonly property real bubble: LockTheme.lock.bubbleSize * unit
    readonly property int tone: {
        let h = 0;
        for (let i = 0; i < name.length; i++)
            h = (h * 31 + name.charCodeAt(i)) % 997;
        return h % 3;
    }
    readonly property color toneFill: [LockTheme.colors.secondary, LockTheme.colors.tertiary, LockTheme.colors.primary][tone]
    readonly property color toneText: [LockTheme.colors.textOnSecondary, LockTheme.colors.textOnTertiary, LockTheme.colors.textOnPrimary][tone]
    readonly property string initial: name.length > 0 ? name.charAt(0).toUpperCase() : "?"

    component NotifBadge: Item {
        id: badgeRoot

        readonly property bool hasPhoto: root.photo !== ""
        readonly property bool hasAppIcon: !hasPhoto && root.appIcon !== "" && appImg.status === Image.Ready
        readonly property bool imageReady: (hasPhoto && photoArt.hasImage) || hasAppIcon

        MaterialShape {
            anchors.fill: parent
            visible: !badgeRoot.hasPhoto
            shape: MaterialShape.Cookie6Sided
            color: badgeRoot.hasAppIcon ? LockTheme.colors.surfaceContainerHighest : root.toneFill
        }

        ShapedArt {
            id: photoArt

            anchors.fill: parent
            visible: badgeRoot.hasPhoto
            shape: MaterialShape.Cookie6Sided
            color: root.toneFill
            source: root.photo
            sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
        }

        Image {
            id: appImg

            anchors.centerIn: parent
            visible: !badgeRoot.hasPhoto && root.appIcon !== "" && status === Image.Ready
            width: parent.width * 0.58
            height: width
            source: !badgeRoot.hasPhoto ? root.appIcon : ""
            sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
            fillMode: Image.PreserveAspectFit
            smooth: true
            asynchronous: true
            cache: false
        }

        Text {
            anchors.centerIn: parent
            visible: !badgeRoot.imageReady
            text: root.glyph || root.initial
            font.family: root.glyph ? LockTheme.font.icons : LockTheme.font.family
            font.pixelSize: parent.height * (root.glyph ? 0.52 : 0.5)
            font.weight: Font.DemiBold
            font.variableAxes: root.glyph ? ({ FILL: 1, GRAD: 0, opsz: 24 }) : ({})
            color: root.toneText
        }
    }

    Item {
        anchors.fill: parent
        opacity: root.idleFade
        visible: opacity > 0

        Rectangle {
            id: disc

            x: (parent.width - width) / 2
            width: root.bubble
            height: width
            radius: width / 2
            color: Qt.alpha(LockTheme.colors.secondaryContainer, LockTheme.lock.surfaceTint)

            NotifBadge {
                anchors.centerIn: parent
                width: parent.width * 0.6
                height: width
            }
        }

        Rectangle {
            visible: root.count > 1
            x: disc.x + disc.width - width * 0.8
            y: -height * 0.15
            width: Math.max(height, badge.implicitWidth + 12)
            height: 24
            radius: 12
            color: LockTheme.colors.primary

            Text {
                id: badge

                anchors.centerIn: parent
                text: root.count
                font.family: LockTheme.font.family
                font.pixelSize: 12
                font.weight: Font.Medium
                color: LockTheme.colors.textOnPrimary
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.bubble + 8
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.name
            font.family: LockTheme.font.family
            font.pixelSize: LockTheme.font.small
            color: Qt.alpha(LockTheme.colors.textOnSurface, 0.75)
        }
    }

    Item {
        anchors.fill: parent
        opacity: root.fade
        visible: opacity > 0

        GlassRect {
            anchors.fill: parent
            radius: height / 2
            fill: LockTheme.colors.secondaryContainer
            tint: LockTheme.lock.surfaceTint
            light: 0
        }

        NotifBadge {
            id: art

            x: parent.height * 0.16
            anchors.verticalCenter: parent.verticalCenter
            width: parent.height * 0.68
            height: width
        }

        Column {
            anchors.left: art.right
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: root.name + (root.count > 1 ? `  ·  ${root.count}` : "")
                font.family: LockTheme.font.family
                font.pixelSize: LockTheme.font.large
                font.weight: Font.Medium
                color: LockTheme.colors.textOnSecondaryContainer
            }

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: root.summary
                font.family: LockTheme.font.family
                font.pixelSize: LockTheme.font.normal
                color: Qt.alpha(LockTheme.colors.textOnSecondaryContainer, 0.7)
            }
        }
    }
}
