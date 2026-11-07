import QtQuick
import qs.components

Flickable {
    id: root

    property bool doneFakeFlick
    // Where a mouse-wheel scroll is gliding to
    property real wheelTarget

    maximumFlickVelocity: 3000

    rebound: Transition {
        onRunningChanged: {
            if (!running && !root.doneFakeFlick) {
                root.doneFakeFlick = true;
                root.flick(1, 1);
                root.flick(-1, -1);
                Qt.callLater(() => root?.cancelFlick()); // the page may be gone by then
            }
        }

        Anim {
            properties: "x,y"
        }
    }

    Timer {
        running: root.doneFakeFlick
        interval: 10
        onTriggered: root.doneFakeFlick = false
    }

    // The mouse wheel glides to the next spot instead of flicking. A flick
    // keeps the view "moving" for a while, and Flickable takes a click made
    // then to stop it: a click right after scrolling did nothing (settings
    // pages: 3 of 3 lost, 0 of 2 after 0.7 s). This animation isn't a flick,
    // so clicks reach the controls at once. Touchpads (pixel deltas) scroll
    // directly. Only for views that scroll vertically.
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        enabled: root.interactive && root.contentHeight > root.height
        onWheel: event => {
            const minY = root.originY - root.topMargin;
            const maxY = Math.max(minY, root.originY + root.contentHeight + root.bottomMargin - root.height);
            const clamp = y => Math.max(minY, Math.min(maxY, y));
            root.cancelFlick();
            if (event.pixelDelta.y !== 0) {
                wheelAnim.stop();
                root.contentY = clamp(root.contentY - event.pixelDelta.y);
            } else {
                // From where a running glide is heading, so fast notches add up
                const from = wheelAnim.running ? root.wheelTarget : root.contentY;
                root.wheelTarget = clamp(from - event.angleDelta.y / 120 * 240);
                wheelAnim.to = root.wheelTarget;
                wheelAnim.restart();
            }
            event.accepted = true;
        }
    }

    NumberAnimation {
        id: wheelAnim

        target: root
        property: "contentY"
        duration: 120
        easing.type: Easing.OutCubic
    }
}
