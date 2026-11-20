pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

// Interactive HSV/hex/preset colour picker modal built on DialogRowButton.
DialogRowButton {
    id: root

    property Item hostFlickable: null
    property string headerText: Tr.tr("Choose a colour")
    property real hue: 0
    property real sat: 1
    property real val: 1
    property var callback: null

    readonly property color currentColor: Qt.hsva(hue, sat, val, 1)
    readonly property string currentHex: {
        const toByte = x => Math.round(Math.max(0, Math.min(1, x)) * 255).toString(16).padStart(2, "0");
        return toByte(currentColor.r) + toByte(currentColor.g) + toByte(currentColor.b);
    }

    function setFromHex(hexStr: string): void {
        const m = String(hexStr || "").trim().replace(/^#/, "").match(/^([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i);
        if (!m)
            return;
        const r = parseInt(m[1], 16) / 255;
        const g = parseInt(m[2], 16) / 255;
        const b = parseInt(m[3], 16) / 255;
        const max = Math.max(r, g, b);
        const min = Math.min(r, g, b);
        const d = max - min;
        let h = hue;
        if (d > 0) {
            if (max === r)
                h = ((g - b) / d) % 6;
            else if (max === g)
                h = (b - r) / d + 2;
            else
                h = (r - g) / d + 4;
            h /= 6;
            if (h < 0)
                h += 1;
        }
        hue = Math.max(0, Math.min(0.9999, h));
        sat = max === 0 ? 0 : d / max;
        val = max;
    }

    function openPicker(hexStr: string, onPicked: var, title: string): void {
        headerText = title || Tr.tr("Choose a colour");
        callback = onPicked ?? null;
        hue = 0;
        setFromHex(hexStr || "ffffff");
        open = true;
    }

    visible: false
    rootParent: hostFlickable
    openWidth: Math.min((hostFlickable?.width ?? 600) * 0.85, 420)
    openHeight: Math.min((hostFlickable?.height ?? 600) * 0.9, 500)
    icon: "palette"
    label: ""
    header: headerText
    acceptLabel: Tr.trCtx("Apply", "button")
    showAccept: true
    showCancel: true
    onAccepted: {
        const cb = callback;
        callback = null;
        if (typeof cb === "function")
            cb(root.currentHex);
    }
    onCancelled: callback = null
    onOpenChanged: if (!open)
        callback = null

    content: Component {
        ColumnLayout {
            id: pickerCol

            spacing: Tokens.spacing.medium

            // 2D Saturation / Value square
            Item {
                id: svBox

                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.large
                implicitHeight: 162

                Rectangle {
                    anchors.fill: parent
                    radius: Tokens.rounding.medium
                    color: Qt.hsva(root.hue, 1, 1, 1)
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Tokens.rounding.medium

                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop {
                            position: 0
                            color: "#ffffffff"
                        }
                        GradientStop {
                            position: 1
                            color: "#00ffffff"
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Tokens.rounding.medium

                    gradient: Gradient {
                        orientation: Gradient.Vertical

                        GradientStop {
                            position: 0
                            color: "#00000000"
                        }
                        GradientStop {
                            position: 1
                            color: "#ff000000"
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Tokens.rounding.medium
                    color: "transparent"
                    border.width: 1
                    border.color: Colours.palette.m3outlineVariant
                }

                Rectangle {
                    z: 2
                    width: 18
                    height: 18
                    radius: 9
                    x: root.sat * svBox.width - width / 2
                    y: (1 - root.val) * svBox.height - height / 2
                    color: root.currentColor
                    border.width: 2
                    border.color: "#ffffff"

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: "#80000000"
                    }
                }

                MouseArea {
                    function pick(m: var): void {
                        forceActiveFocus();
                        root.sat = Math.max(0, Math.min(1, m.x / Math.max(1, width)));
                        root.val = Math.max(0, Math.min(1, 1 - m.y / Math.max(1, height)));
                    }

                    anchors.fill: parent
                    cursorShape: Qt.CrossCursor
                    onPressed: m => pick(m)
                    onPositionChanged: m => {
                        if (pressed)
                            pick(m);
                    }
                }
            }

            // Hue slider bar
            Item {
                id: hueBar

                Layout.fillWidth: true
                implicitHeight: 22

                Rectangle {
                    anchors.fill: parent
                    radius: 11

                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop { position: 0.0; color: "#ff0000" }
                        GradientStop { position: 0.1667; color: "#ffff00" }
                        GradientStop { position: 0.3333; color: "#00ff00" }
                        GradientStop { position: 0.5; color: "#00ffff" }
                        GradientStop { position: 0.6667; color: "#0000ff" }
                        GradientStop { position: 0.8333; color: "#ff00ff" }
                        GradientStop { position: 1.0; color: "#ff0000" }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 11
                    color: "transparent"
                    border.width: 1
                    border.color: Colours.palette.m3outlineVariant
                }

                Rectangle {
                    z: 2
                    width: 22
                    height: 22
                    radius: 11
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.hue * Math.max(0, hueBar.width - width)
                    color: Qt.hsva(root.hue, 1, 1, 1)
                    border.width: 2
                    border.color: "#ffffff"

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: "#80000000"
                    }
                }

                MouseArea {
                    function pick(m: var): void {
                        forceActiveFocus();
                        root.hue = Math.max(0, Math.min(0.9999, (m.x - 11) / Math.max(1, width - 22)));
                    }

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onPressed: m => pick(m)
                    onPositionChanged: m => {
                        if (pressed)
                            pick(m);
                    }
                }
            }

            // Live preview + Hex input + RGB readout
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                Rectangle {
                    implicitWidth: 42
                    implicitHeight: 42
                    radius: Tokens.rounding.medium
                    color: root.currentColor
                    border.width: 1
                    border.color: Colours.palette.m3outlineVariant
                }

                StyledTextField {
                    id: hexField

                    Layout.preferredWidth: 118
                    verticalPadding: Tokens.padding.small
                    floatingPlaceholder: false
                    font: Tokens.font.mono.small
                    placeholderText: "#rrggbb"
                    Component.onCompleted: text = `#${root.currentHex}`
                    onTextEdited: {
                        const t = text.trim();
                        if (/^#?[0-9a-fA-F]{6}$/.test(t))
                            root.setFromHex(t);
                    }

                    Connections {
                        function onCurrentHexChanged(): void {
                            if (!hexField.activeFocus)
                                hexField.text = `#${root.currentHex}`;
                        }

                        target: root
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: `R ${Math.round(root.currentColor.r * 255)} · G ${Math.round(root.currentColor.g * 255)} · B ${Math.round(root.currentColor.b * 255)}`
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                    elide: Text.ElideRight
                }
            }

            // Preset swatches
            Flow {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                Repeater {
                    model: [Colours.palette.m3primary.toString().slice(1, 7), "ffffff", "ff3b30", "ff9500", "ffcc00", "34c759", "00c7be", "007aff", "af52de", "ff2d55", "000000"]

                    Rectangle {
                        id: preset

                        required property string modelData

                        implicitWidth: 24
                        implicitHeight: 24
                        radius: 12
                        color: `#${modelData}`
                        border.width: root.currentHex === modelData ? 2.5 : 1
                        border.color: root.currentHex === modelData ? Colours.palette.m3primary : Colours.palette.m3outlineVariant

                        StateLayer {
                            anchors.fill: parent
                            radius: preset.radius
                            onClicked: {
                                preset.forceActiveFocus();
                                root.setFromHex(preset.modelData);
                            }
                        }
                    }
                }
            }
        }
    }
}
