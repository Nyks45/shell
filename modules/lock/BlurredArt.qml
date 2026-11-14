import QtQuick
import QtQuick.Effects

Item {
    id: root

    property string source
    property bool showingA: true

    Item {
        id: images

        anchors.fill: parent
        visible: false
        layer.enabled: true

        Image {
            id: a

            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: Qt.size(NebulaTheme.media.artSourceSize, NebulaTheme.media.artSourceSize)
            opacity: (root.showingA ? status === Image.Ready : b.status !== Image.Ready) ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: NebulaTheme.media.artFade * NebulaTheme.anim.scale
                }
            }
        }

        Image {
            id: b

            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: Qt.size(NebulaTheme.media.artSourceSize, NebulaTheme.media.artSourceSize)
            opacity: (!root.showingA ? status === Image.Ready : a.status !== Image.Ready) ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: NebulaTheme.media.artFade * NebulaTheme.anim.scale
                }
            }
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: images
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1
        blurMax: NebulaTheme.media.artBlur
        opacity: NebulaTheme.media.artOpacity
    }

    onSourceChanged: {
        if (showingA) {
            b.source = source;
            showingA = false;
        } else {
            a.source = source;
            showingA = true;
        }
    }
}
