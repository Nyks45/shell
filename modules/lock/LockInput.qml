pragma ComponentBehavior: Bound

import QtQuick
import M3Shapes

Item {
    id: root

    required property Pam pam
    property bool unlocking: false

    property real t: 0

    readonly property int typed: pam.buffer.length
    readonly property bool typing: typed > 0
    readonly property bool checking: pam.passwd.active
    readonly property bool failed: !typing && !checking && (pam.state === Pam.Failed || pam.state === Pam.Error || pam.state === Pam.MaxTries || pam.lockMessage !== "")
    readonly property string failMessage: {
        if (pam.lockMessage)
            return pam.lockMessage;
        if (pam.state === Pam.MaxTries)
            return "Too many attempts";
        if (pam.state === Pam.Error)
            return "Authentication error";
        if (pam.state === Pam.Failed)
            return "Wrong password";
        return "";
    }
    readonly property string promptText: {
        if (failed && failMessage !== "")
            return failMessage;
        if (pam.howdy.active)
            return "Looking for face...";
        if (pam.fprint.active)
            return "Touch sensor or type password";
        return "Enter password";
    }
    readonly property var dotShapes: [
        MaterialShape.Cookie6Sided,
        MaterialShape.Clover4Leaf,
        MaterialShape.Flower,
        MaterialShape.Cookie9Sided,
        MaterialShape.Pentagon,
        MaterialShape.Sunny
    ]
    readonly property var dotColors: [
        NebulaTheme.colors.primary,
        NebulaTheme.colors.tertiary,
        NebulaTheme.colors.secondary
    ]

    function submit(): void {
        if (pam.passwd.active || root.unlocking)
            return;
        if (pam.buffer.length > 0) {
            pam.passwd.start();
        } else if (pam.howdy.canAttempt && !pam.howdy.active) {
            pam.howdy.start();
        }
    }

    function syncDots(): void {
        // As many shapes as fit the field (15px + 4px gap each, plus the caret), never more than dotMax
        const fit = Math.floor((dotArea.width - 7 + 4) / 19);
        const cap = Math.max(1, Math.min(NebulaTheme.lock.dotMax, dotArea.width > 0 ? fit : NebulaTheme.lock.dotMax));
        if (root.typed <= 0) {
            dotModel.clear();
            return;
        }
        while (dotModel.count > Math.min(root.typed, cap))
            dotModel.remove(dotModel.count - 1);
        const startIdx = Math.max(dotModel.count > 0 ? dotModel.get(dotModel.count - 1).glyphIdx + 1 : 0, root.typed - cap);
        for (let idx = startIdx; idx < root.typed; idx++) {
            if (dotModel.count >= cap)
                dotModel.remove(0);
            dotModel.append({
                glyphIdx: idx
            });
        }
    }

    onTypedChanged: syncDots()
    Component.onCompleted: syncDots()

    ListModel {
        id: dotModel
    }

    GlassRect {
        anchors.fill: parent
        radius: height / 2
        fill: NebulaTheme.colors.surfaceContainerHigh
        tint: NebulaTheme.lock.surfaceTint
        light: 0
    }

    FrameAnimation {
        running: root.typing && root.visible
        onTriggered: root.t += frameTime
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: "transparent"
        border.width: 1.5
        border.color: root.failed
            ? NebulaTheme.colors.errorColor
            : (root.typing || root.checking ? Qt.alpha(NebulaTheme.colors.primary, 0.7) : Qt.alpha(NebulaTheme.colors.textOnSurface, 0.06))

        Behavior on border.color {
            ColorAnimation {
                duration: NebulaTheme.anim.fast
            }
        }
    }

    Item {
        id: lockBox

        x: 6
        anchors.verticalCenter: parent.verticalCenter
        width: parent.height - 12
        height: width

        MaterialShape {
            id: lockShape

            anchors.fill: parent
            shape: root.failed ? MaterialShape.Pentagon
                : root.unlocking ? MaterialShape.Sunny
                : root.checking ? MaterialShape.Clover4Leaf
                : root.typing ? MaterialShape.Cookie12Sided
                : MaterialShape.Cookie9Sided
            color: root.failed ? Qt.alpha(NebulaTheme.colors.errorColor, 0.28) : Qt.alpha(NebulaTheme.colors.primary, 0.28)
            animationDuration: NebulaTheme.anim.slow

            RotationAnimation on rotation {
                from: 0
                to: 360
                duration: 2400
                loops: Animation.Infinite
                running: root.checking || root.unlocking
            }
        }

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 1
            text: root.failed ? "lock_reset" : root.unlocking ? "lock_open" : "lock"
            font.family: NebulaTheme.font.icons
            font.pixelSize: 21
            color: root.failed ? NebulaTheme.colors.errorColor : NebulaTheme.colors.primary
        }
    }

    Item {
        id: dotArea

        anchors.left: lockBox.right
        anchors.leftMargin: 10
        anchors.right: button.left
        anchors.rightMargin: 10
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        clip: true
        onWidthChanged: root.syncDots()

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 1
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            visible: !root.typing && !root.checking
            text: root.promptText
            font.family: NebulaTheme.font.family
            font.pixelSize: NebulaTheme.font.large
            font.weight: Font.Medium
            color: root.failed ? NebulaTheme.colors.errorColor : Qt.alpha(NebulaTheme.colors.textOnSurface, 0.55)
        }

        Row {
            anchors.centerIn: parent
            spacing: 4
            visible: root.typing || root.checking

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: root.checking
                NumberAnimation {
                    to: 0.4
                    duration: 380
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: 1
                    duration: 380
                    easing.type: Easing.InOutSine
                }
            }

            Repeater {
                model: dotModel

                Item {
                    id: piece

                    required property int index
                    required property int glyphIdx

                    property real targetW: 15
                    property real enterRot: -60

                    width: 0
                    height: 20
                    scale: 0
                    opacity: 0

                    Component.onCompleted: enterAnim.start()

                    ParallelAnimation {
                        id: enterAnim

                        NumberAnimation {
                            target: piece
                            property: "width"
                            from: 0
                            to: piece.targetW
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: piece
                            property: "scale"
                            from: 0
                            to: 1
                            duration: 220
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.35
                        }
                        NumberAnimation {
                            target: piece
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: piece
                            property: "enterRot"
                            from: -60
                            to: 0
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }

                    MaterialShape {
                        id: shapeItem

                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: Math.sin(root.t * 3.0 + piece.index * 0.7) * 1.5
                        width: 15
                        height: 15
                        implicitSize: 15
                        rotation: piece.enterRot + Math.sin(root.t * 1.8 + piece.index * 0.5) * 12
                        shape: root.dotShapes[piece.glyphIdx % root.dotShapes.length]
                        color: root.dotColors[piece.glyphIdx % root.dotColors.length]
                    }
                }
            }

            Rectangle {
                width: 3
                height: 20
                radius: 1.5
                color: NebulaTheme.colors.primary
                visible: !root.checking

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: (root.typing && !root.checking) && root.visible
                    NumberAnimation {
                        to: 0
                        duration: 500
                    }
                    NumberAnimation {
                        to: 1
                        duration: 500
                    }
                }
            }
        }
    }

    Item {
        id: button

        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        width: parent.height - 12
        height: width
        scale: sendArea.pressed ? 0.88 : sendArea.containsMouse ? 1.06 : 1

        Behavior on scale {
            NumberAnimation {
                duration: NebulaTheme.anim.fast
                easing.type: Easing.OutCubic
            }
        }

        MaterialShape {
            anchors.fill: parent
            visible: !root.checking
            shape: root.typing ? MaterialShape.Cookie9Sided : MaterialShape.Circle
            color: root.typing ? NebulaTheme.colors.primary : Qt.alpha(NebulaTheme.colors.textOnSurface, 0.08)
            animationDuration: NebulaTheme.anim.slow

            Behavior on color {
                ColorAnimation {
                    duration: NebulaTheme.anim.fast
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: !root.checking
            text: "arrow_forward"
            font.family: NebulaTheme.font.icons
            font.pixelSize: 22
            color: root.typing ? NebulaTheme.colors.textOnPrimary : Qt.alpha(NebulaTheme.colors.textOnSurface, 0.4)
        }

        MouseArea {
            id: sendArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.submit()
        }

        LoadingIndicator {
            anchors.centerIn: parent
            width: parent.width
            height: width
            contained: false
            running: root.checking
            visible: running
        }
    }
}
