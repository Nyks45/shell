pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    function rand(seed: real): real {
        const x = Math.sin(seed * 12.9898 + 78.233) * 43758.5453;
        return x - Math.floor(x);
    }

    Repeater {
        model: LockTheme.galaxy.stars

        Rectangle {
            required property int index

            readonly property bool big: root.rand(index + 1) > 0.9

            width: big ? 2.8 : 1.6
            height: width
            radius: width / 2
            x: root.rand(index + 2) * root.width - width / 2
            y: root.rand(index + 3) * root.height - height / 2
            color: LockTheme.lock.star
            opacity: big ? LockTheme.galaxy.starBright : LockTheme.galaxy.starFaint
        }
    }

    Repeater {
        model: LockTheme.lock.twinklers

        Rectangle {
            required property int index

            x: root.rand(index * 7 + 101) * root.width
            y: root.rand(index * 7 + 102) * root.height
            width: 2
            height: 2
            radius: 1
            color: LockTheme.lock.star
            opacity: 0

            SequentialAnimation on opacity {
                running: root.visible
                loops: Animation.Infinite

                PauseAnimation {
                    duration: Math.round(400 + root.rand(index + 300) * 3200)
                }
                NumberAnimation {
                    to: 0.9
                    duration: 900
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: 0
                    duration: 1300
                    easing.type: Easing.InOutSine
                }
            }
        }
    }
}
