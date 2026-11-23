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
            sourceSize: Qt.size(LockTheme.media.artSourceSize, LockTheme.media.artSourceSize)
            opacity: (root.showingA ? status === Image.Ready : b.status !== Image.Ready) ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: LockTheme.media.artFade * LockTheme.anim.scale
                }
            }
        }

        Image {
            id: b

            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: Qt.size(LockTheme.media.artSourceSize, LockTheme.media.artSourceSize)
            opacity: (!root.showingA ? status === Image.Ready : a.status !== Image.Ready) ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: LockTheme.media.artFade * LockTheme.anim.scale
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
        blurMax: LockTheme.media.artBlur
        opacity: LockTheme.media.artOpacity
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
