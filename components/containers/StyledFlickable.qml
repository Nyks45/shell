import QtQuick
import qs.components
import qs.services

Flickable {
    id: root

    property bool doneFakeFlick
    // Middle-click autoscroll (like Windows): where it started, and on
    readonly property alias autoscrolling: autoscroll.active

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

    function clampY(y: real): real {
        const minY = originY - topMargin;
        const maxY = Math.max(minY, originY + contentHeight + bottomMargin - height);
        return Math.max(minY, Math.min(maxY, y));
    }

    // Mouse wheel / touchpad scrolling that stays clickable. Flickable's own
    // wheel scrolling flicks, and Flickable takes a click made while it
    // flicks just to stop it: a click right after scrolling did nothing
    // (sandbox: 3 of 3 lost). Here the wheel glides with an animation (not a
    // flick: clicks get through) over Flickable's own distance and curve: a
    // notch starts at maximumFlickVelocity / 4 and decelerates at
    // flickDeceleration (v^2 / 2a, constant deceleration = OutQuad), so it
    // scrolls as far as before. Hi-res wheels (steps of 1/8 notch) get their
    // share per step; touchpads (pixel deltas) move 1:1 as with Flickable.
    property real wheelTarget

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        enabled: root.interactive && root.contentHeight > root.height
        onWheel: event => {
            root.cancelFlick();
            if (event.pixelDelta.y !== 0) {
                wheelAnim.stop();
                root.contentY = root.clampY(root.contentY - event.pixelDelta.y);
            } else if (event.angleDelta.y !== 0) {
                const v = root.maximumFlickVelocity / 4;
                const a = Math.max(1, root.flickDeceleration);
                const notch = v * v / (2 * a);
                // From where a running glide is heading, so quick notches add up
                const from = wheelAnim.running ? root.wheelTarget : root.contentY;
                root.wheelTarget = root.clampY(from - event.angleDelta.y / 120 * notch);
                wheelAnim.to = root.wheelTarget;
                wheelAnim.duration = Math.round(v / a * 1000);
                wheelAnim.restart();
            }
            event.accepted = true;
        }
    }

    NumberAnimation {
        id: wheelAnim

        target: root
        property: "contentY"
        easing.type: Easing.OutQuad
    }

    // Middle-click autoscroll, like Windows: middle-click (or hold the middle
    // button) and move the pointer up or down: the further from where it
    // started, the faster it scrolls; any click (or releasing a held middle
    // button after moving) stops it. Only the middle button is taken: left
    // and right clicks go to the controls as before.
    MouseArea {
        id: autoscroll

        property bool active
        property real originX
        property real originY
        property real pointerY
        property bool dragged

        // Over the visible area (a child of the Flickable itself, not of its content)
        parent: root
        x: 0
        y: 0
        width: root.width
        height: root.height
        z: 1000
        enabled: root.interactive && root.contentHeight > root.height
        acceptedButtons: active ? Qt.AllButtons : Qt.MiddleButton
        hoverEnabled: active
        cursorShape: active ? Qt.SizeVerCursor : undefined
        onPressed: mouse => {
            if (active) {
                // Any click stops it (and does nothing else)
                active = false;
                return;
            }
            wheelAnim.stop();
            root.cancelFlick();
            originX = mouse.x;
            originY = mouse.y;
            pointerY = mouse.y;
            dragged = false;
            active = true;
        }
        onPositionChanged: mouse => {
            pointerY = mouse.y;
            if (Math.abs(mouse.y - originY) > 12)
                dragged = true;
        }
        // Held and moved: letting go stops it (a plain middle click keeps it on)
        onReleased: mouse => {
            if (active && mouse.button === Qt.MiddleButton && dragged)
                active = false;
        }

        Timer {
            running: autoscroll.active
            repeat: true
            interval: 16
            onTriggered: {
                // A dead zone around where it started, then faster with distance
                const d = autoscroll.pointerY - autoscroll.originY;
                const off = Math.abs(d) < 10 ? 0 : (Math.abs(d) - 10) * Math.sign(d);
                root.contentY = root.clampY(root.contentY + off * 0.15);
            }
        }

        // Where it started: a small marker with arrows
        StyledRect {
            visible: autoscroll.active
            x: autoscroll.originX - width / 2
            y: autoscroll.originY - height / 2
            implicitWidth: 28
            implicitHeight: 28
            radius: 14
            color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.9)
            border.width: 1
            border.color: Colours.palette.m3outline

            MaterialIcon {
                anchors.centerIn: parent
                text: "unfold_more"
                color: Colours.palette.m3onSurface
            }
        }
    }
}
