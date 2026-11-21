import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// A colour picker card: saturation/value square, hue and opacity bars, hex field.
// Set `value` before opening; `changed(colour)` fires live while picking.
StyledRect {
    id: root

    property color value: "red"
    property bool open
    property real hue
    property real sat
    property real val
    property real alphaValue: 1
    readonly property color current: Qt.hsva(hue, sat, val, alphaValue)

    signal picked(colour: color)

    function load(c: color): void {
        const col = Qt.color(c);
        // keep the hue of greys (hsvHue is -1 for them)
        hue = col.hsvHue >= 0 ? col.hsvHue : hue;
        sat = col.hsvSaturation;
        val = col.hsvValue;
        alphaValue = col.a;
        hexField.text = hexOf(col);
    }

    function emit(): void {
        hexField.text = root.hexOf(root.current);
        root.picked(root.current);
    }

    function hexOf(c: color): string {
        const h = v => Math.round(v * 255).toString(16).padStart(2, "0");
        return (c.a < 0.999 ? h(c.a) : "") + h(c.r) + h(c.g) + h(c.b);
    }

    onOpenChanged: if (open)
        load(value)

    visible: opacity > 0
    opacity: open ? 1 : 0
    z: 950
    implicitWidth: 260
    implicitHeight: col.implicitHeight + Tokens.padding.medium * 2
    radius: Tokens.rounding.medium
    color: Colours.palette.m3surfaceContainerHigh

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: w => w.accepted = true
    }

    ColumnLayout {
        id: col

        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        spacing: Tokens.spacing.small

        // Saturation (x) / value (y)
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 150

            Rectangle {
                id: sv

                objectName: "picker-sv"
                anchors.fill: parent
                radius: Tokens.rounding.small
                color: Qt.hsva(root.hue, 1, 1, 1)
                clip: true

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0
                            color: "white"
                        }
                        GradientStop {
                            position: 1
                            color: Qt.rgba(1, 1, 1, 0)
                        }
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: Qt.rgba(0, 0, 0, 0)
                        }
                        GradientStop {
                            position: 1
                            color: "black"
                        }
                    }
                }

                Rectangle {
                    x: root.sat * sv.width - width / 2
                    y: (1 - root.val) * sv.height - height / 2
                    width: 14
                    height: 14
                    radius: 7
                    color: "transparent"
                    border.width: 2
                    border.color: root.val > 0.5 && root.sat < 0.5 ? "black" : "white"
                }

                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                    function set(m: var): void {
                        root.sat = Math.max(0, Math.min(1, m.x / width));
                        root.val = Math.max(0, Math.min(1, 1 - m.y / height));
                        root.emit();
                    }
                    onPressed: m => set(m)
                    onPositionChanged: m => set(m)
                }
            }
        }

        // Hue
        Rectangle {
            id: hueBar

            objectName: "picker-hue"
            Layout.fillWidth: true
            Layout.preferredHeight: 14
            radius: 7
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: "#ff0000"
                }
                GradientStop {
                    position: 1 / 6
                    color: "#ffff00"
                }
                GradientStop {
                    position: 2 / 6
                    color: "#00ff00"
                }
                GradientStop {
                    position: 3 / 6
                    color: "#00ffff"
                }
                GradientStop {
                    position: 4 / 6
                    color: "#0000ff"
                }
                GradientStop {
                    position: 5 / 6
                    color: "#ff00ff"
                }
                GradientStop {
                    position: 1
                    color: "#ff0000"
                }
            }

            Rectangle {
                x: root.hue * hueBar.width - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                radius: 8
                color: Qt.hsva(root.hue, 1, 1, 1)
                border.width: 2
                border.color: "white"
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                preventStealing: true
                function set(m: var): void {
                    root.hue = Math.max(0, Math.min(0.9999, (m.x - 6) / hueBar.width));
                    root.emit();
                }
                onPressed: m => set(m)
                onPositionChanged: m => set(m)
            }
        }

        // Opacity, over a checkerboard
        Item {
            id: alphaBar

            Layout.fillWidth: true
            Layout.preferredHeight: 14

            Checker {
                anchors.fill: parent
                cell: 7
                radius: 7
            }

            Rectangle {
                anchors.fill: parent
                radius: 7
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: Qt.hsva(root.hue, root.sat, root.val, 0)
                    }
                    GradientStop {
                        position: 1
                        color: Qt.hsva(root.hue, root.sat, root.val, 1)
                    }
                }
            }

            Rectangle {
                x: root.alphaValue * alphaBar.width - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                radius: 8
                color: root.current
                border.width: 2
                border.color: "white"
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                preventStealing: true
                function set(m: var): void {
                    root.alphaValue = Math.max(0, Math.min(1, (m.x - 6) / alphaBar.width));
                    root.emit();
                }
                onPressed: m => set(m)
                onPositionChanged: m => set(m)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Item {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36

                Checker {
                    anchors.fill: parent
                    cell: 6
                    radius: Tokens.rounding.small
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Tokens.rounding.small
                    color: root.current
                    border.width: 1
                    border.color: Colours.palette.m3outline
                }
            }

            StyledText {
                text: "#"
                color: Colours.palette.m3onSurfaceVariant
            }

            StyledTextField {
                id: hexField

                objectName: "picker-hex"
                Layout.fillWidth: true
                verticalPadding: Tokens.padding.small
                horizontalPadding: Tokens.padding.small
                floatingPlaceholder: false
                placeholderText: "rrggbb"
                validate: /^([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/
                onAccepted: {
                    if (!valid)
                        return;
                    root.load(Qt.color(`#${text}`));
                    root.picked(root.current);
                }
            }
        }
    }
}
