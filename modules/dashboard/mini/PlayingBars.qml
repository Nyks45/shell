pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.services

// Something's playing: a few slim bars moving with the sound (the audio visualiser, like the
// lock screen's), resting low when it's paused
Row {
    id: root

    property bool playing
    property int count: 5
    property color colour: Colours.palette.m3primary

    readonly property var levels: {
        const v = Audio.cava.values;
        const out = [];
        for (let j = 0; j < count; j++) {
            const a = Math.floor(j * v.length / count);
            const b = Math.max(a + 1, Math.floor((j + 1) * v.length / count));
            let sum = 0, n = 0;
            for (let i = a; i < b && i < v.length; i++) {
                sum += v[i];
                n++;
            }
            out.push(n > 0 ? Math.max(0.15, Math.min(1, sum / n)) : 0.15);
        }
        return out;
    }

    spacing: 2
    implicitHeight: 14

    ServiceRef {
        service: root.visible && root.playing ? Audio.cava : null
    }

    Repeater {
        model: root.count

        Item {
            required property int index

            width: 3
            height: root.height

            StyledRect {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: Math.max(3, parent.height * (root.playing ? (root.levels[parent.index] ?? 0.15) : 0.15))
                radius: width / 2
                color: root.colour

                Behavior on height {
                    NumberAnimation {
                        duration: 85
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
