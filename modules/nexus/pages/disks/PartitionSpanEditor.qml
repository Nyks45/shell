pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

// Interactive draggable partition bar + synced Free before / Size / Free after
// numeric inputs with live before/after ghost comparison and unit toggle.
ColumnLayout {
    id: root

    readonly property real mib: 1048576

    property int totalSpanMiB: 1
    property int minSizeMiB: 1
    property int origBeforeMiB: 0
    property int origSizeMiB: 1
    property int usedMiB: 0
    property int beforeMiB: 0
    property int sizeMiB: 1
    readonly property int afterMiB: Math.max(0, totalSpanMiB - beforeMiB - sizeMiB)
    property bool fixedSize: false
    property bool isCreate: false
    property bool enabled: true
    property bool useLargeUnit: true
    property color partColor: Colours.palette.m3primary
    property color onPartColor: Colours.palette.m3onPrimary
    property string partLabel: ""
    property real spanStartBytes: 0

    readonly property int effMinSize: Math.max(1, Math.min(totalSpanMiB, fixedSize ? sizeMiB : minSizeMiB))
    readonly property string barText: {
        const sz = Disks.human(sizeMiB * mib);
        return partLabel ? `${partLabel} · ${sz}` : sz;
    }

    signal edited(int beforeMiB, int sizeMiB)

    function applyGeom(b: int, s: int): void {
        const minS = effMinSize;
        const clampedS = fixedSize ? Math.max(1, Math.min(totalSpanMiB, origSizeMiB)) : Math.max(minS, Math.min(totalSpanMiB, s));
        const clampedB = Math.max(0, Math.min(totalSpanMiB - clampedS, b));
        beforeMiB = clampedB;
        sizeMiB = clampedS;
        edited(clampedB, clampedS);
    }

    function commitBefore(vStr: string): void {
        const v = parseFloat(vStr.trim().replace(",", "."));
        if (!isFinite(v) || v < 0)
            return;
        const mibVal = Math.round(v * Disks.unitDivisor(useLargeUnit) / mib);
        const minS = effMinSize;
        const newB = Math.max(0, Math.min(totalSpanMiB - minS, mibVal));
        if (fixedSize) {
            applyGeom(Math.min(newB, totalSpanMiB - sizeMiB), sizeMiB);
        } else {
            const newS = newB + sizeMiB > totalSpanMiB ? totalSpanMiB - newB : sizeMiB;
            applyGeom(newB, newS);
        }
    }

    function commitSize(vStr: string): void {
        if (fixedSize)
            return;
        const v = parseFloat(vStr.trim().replace(",", "."));
        if (!isFinite(v) || v <= 0)
            return;
        const mibVal = Math.round(v * Disks.unitDivisor(useLargeUnit) / mib);
        const newS = Math.max(effMinSize, Math.min(totalSpanMiB, mibVal));
        const newB = beforeMiB + newS > totalSpanMiB ? totalSpanMiB - newS : beforeMiB;
        applyGeom(newB, newS);
    }

    function commitAfter(vStr: string): void {
        const v = parseFloat(vStr.trim().replace(",", "."));
        if (!isFinite(v) || v < 0)
            return;
        const mibVal = Math.round(v * Disks.unitDivisor(useLargeUnit) / mib);
        const minS = effMinSize;
        const clampedAfter = Math.max(0, Math.min(totalSpanMiB - minS, mibVal));
        if (fixedSize) {
            applyGeom(Math.max(0, totalSpanMiB - sizeMiB - clampedAfter), sizeMiB);
        } else {
            const availForPart = totalSpanMiB - beforeMiB - clampedAfter;
            if (availForPart >= minS) {
                applyGeom(beforeMiB, availForPart);
            } else {
                const newB = Math.max(0, totalSpanMiB - minS - clampedAfter);
                applyGeom(newB, Math.max(minS, totalSpanMiB - clampedAfter - newB));
            }
        }
    }

    function syncFields(forceAll: bool): void {
        if (forceAll || !beforeField.activeFocus)
            beforeField.text = Disks.formatUnitBytes(beforeMiB * mib, useLargeUnit);
        if (forceAll || !sizeField.activeFocus)
            sizeField.text = Disks.formatUnitBytes(sizeMiB * mib, useLargeUnit);
        if (forceAll || !afterField.activeFocus)
            afterField.text = Disks.formatUnitBytes(afterMiB * mib, useLargeUnit);
    }

    spacing: Tokens.spacing.small

    onBeforeMiBChanged: syncFields(false)
    onSizeMiBChanged: syncFields(false)
    onAfterMiBChanged: syncFields(false)
    onTotalSpanMiBChanged: syncFields(false)
    onUseLargeUnitChanged: syncFields(true)
    Component.onCompleted: syncFields(true)

    // ---- Visual draggable bar --------------------------------------------
    StyledRect {
        Layout.fillWidth: true
        implicitHeight: 58
        radius: Tokens.rounding.medium
        color: Colours.layer(Colours.palette.m3surfaceContainer, 1)

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: Colours.palette.m3outlineVariant
        }

        Item {
            id: track

            readonly property real total: Math.max(1, root.totalSpanMiB)
            readonly property real minThumbW: Math.min(width, 40)
            readonly property real rawX: width * (root.beforeMiB / total)
            readonly property real rawW: width * (root.sizeMiB / total)
            readonly property real thumbW: Math.max(minThumbW, rawW)
            readonly property real thumbX: Math.max(0, Math.min(rawX, width - thumbW))
            readonly property real usedRatio: root.usedMiB > 0 && root.sizeMiB > 0 ? Math.min(1, root.usedMiB / root.sizeMiB) : 0

            anchors.fill: parent
            anchors.margins: 5

            // Subtle original span ghost when repositioned/resized
            Rectangle {
                readonly property real gW: Math.max(12, track.width * (root.origSizeMiB / track.total))
                readonly property real gX: Math.max(0, Math.min(track.width * (root.origBeforeMiB / track.total), track.width - gW))

                visible: !root.isCreate && root.origSizeMiB > 0 && (root.beforeMiB !== root.origBeforeMiB || root.sizeMiB !== root.origSizeMiB)
                x: gX
                width: gW
                y: 2
                height: parent.height - 4
                radius: Tokens.rounding.small
                color: "transparent"
                border.width: 1.5
                border.color: Colours.palette.m3outline
                opacity: 0.55
            }

            // Active partition thumb
            StyledRect {
                id: thumb

                x: track.thumbX
                y: 0
                width: track.thumbW
                height: parent.height
                radius: Tokens.rounding.small
                clip: true
                color: Qt.alpha(root.partColor, root.enabled ? 0.34 : 0.22)

                // Unfilled layer text
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 15
                    width: Math.max(0, thumb.width - 30)
                    visible: width >= 44
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    font: Tokens.font.label.small
                    color: Colours.palette.m3onSurface
                    text: root.barText
                }

                // Used-space fill inside thumb (clips matching contrast label at fill boundary)
                StyledRect {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * track.usedRatio
                    radius: parent.radius
                    clip: true
                    visible: track.usedRatio > 0
                    color: root.partColor

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 15
                        width: Math.max(0, thumb.width - 30)
                        visible: width >= 44
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        font: Tokens.font.label.small
                        color: root.onPartColor
                        text: root.barText
                    }
                }

                // Outer active border
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: 2
                    border.color: root.enabled ? root.partColor : Colours.palette.m3outlineVariant
                }

                // Center drag-to-move handle (when free space exists on either side)
                MouseArea {
                    id: moveArea

                    property real pressTrackX: 0
                    property int pressBefore: 0

                    anchors.fill: parent
                    anchors.leftMargin: leftHandle.visible ? 12 : 0
                    anchors.rightMargin: rightHandle.visible ? 12 : 0
                    enabled: root.enabled && root.totalSpanMiB > root.sizeMiB
                    cursorShape: enabled ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.ArrowCursor
                    onPressed: mouse => {
                        pressTrackX = mapToItem(track, mouse.x, 0).x;
                        pressBefore = root.beforeMiB;
                    }
                    onPositionChanged: mouse => {
                        if (!pressed || track.width <= 0)
                            return;
                        const curX = mapToItem(track, mouse.x, 0).x;
                        const deltaMiB = Math.round(((curX - pressTrackX) / track.width) * track.total);
                        root.applyGeom(pressBefore + deltaMiB, root.sizeMiB);
                    }
                }

                // Left resize handle
                Item {
                    id: leftHandle

                    visible: root.enabled && !root.fixedSize
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 14

                    Rectangle {
                        anchors.centerIn: parent
                        width: 3
                        height: 20
                        radius: 1.5
                        color: Colours.palette.m3onSurface
                        opacity: leftArea.containsMouse || leftArea.pressed ? 0.95 : 0.6
                    }

                    MouseArea {
                        id: leftArea

                        property real pressTrackX: 0
                        property int pressBefore: 0
                        property int fixedEnd: 0

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.SizeHorCursor
                        onPressed: mouse => {
                            pressTrackX = mapToItem(track, mouse.x, 0).x;
                            pressBefore = root.beforeMiB;
                            fixedEnd = root.beforeMiB + root.sizeMiB;
                        }
                        onPositionChanged: mouse => {
                            if (!pressed || track.width <= 0)
                                return;
                            const curX = mapToItem(track, mouse.x, 0).x;
                            const deltaMiB = Math.round(((curX - pressTrackX) / track.width) * track.total);
                            const newB = Math.max(0, Math.min(fixedEnd - root.effMinSize, pressBefore + deltaMiB));
                            root.applyGeom(newB, fixedEnd - newB);
                        }
                    }
                }

                // Right resize handle
                Item {
                    id: rightHandle

                    visible: root.enabled && !root.fixedSize
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 14

                    Rectangle {
                        anchors.centerIn: parent
                        width: 3
                        height: 20
                        radius: 1.5
                        color: Colours.palette.m3onSurface
                        opacity: rightArea.containsMouse || rightArea.pressed ? 0.95 : 0.6
                    }

                    MouseArea {
                        id: rightArea

                        property real pressTrackX: 0
                        property int pressSize: 0

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.SizeHorCursor
                        onPressed: mouse => {
                            pressTrackX = mapToItem(track, mouse.x, 0).x;
                            pressSize = root.sizeMiB;
                        }
                        onPositionChanged: mouse => {
                            if (!pressed || track.width <= 0)
                                return;
                            const curX = mapToItem(track, mouse.x, 0).x;
                            const deltaMiB = Math.round(((curX - pressTrackX) / track.width) * track.total);
                            const newS = Math.max(root.effMinSize, Math.min(root.totalSpanMiB - root.beforeMiB, pressSize + deltaMiB));
                            root.applyGeom(root.beforeMiB, newS);
                        }
                    }
                }
            }
        }
    }

    // ---- Three synced numeric fields + unit toggle -----------------------
    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                text: Tr.tr("Free before")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }

            StyledTextField {
                id: beforeField

                Layout.fillWidth: true
                enabled: root.enabled && (root.totalSpanMiB > root.sizeMiB || !root.fixedSize)
                verticalPadding: Tokens.padding.small
                horizontalPadding: Tokens.padding.medium
                floatingPlaceholder: false
                validator: RegularExpressionValidator {
                    regularExpression: /^\d*([.,]\d{0,2})?$/
                }
                onTextEdited: root.commitBefore(text)
                onEditingFinished: {
                    root.commitBefore(text);
                    root.syncFields(true);
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                text: root.isCreate ? Tr.tr("Partition size") : Tr.tr("New size")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }

            StyledTextField {
                id: sizeField

                Layout.fillWidth: true
                enabled: root.enabled && !root.fixedSize
                verticalPadding: Tokens.padding.small
                horizontalPadding: Tokens.padding.medium
                floatingPlaceholder: false
                validator: RegularExpressionValidator {
                    regularExpression: /^\d*([.,]\d{0,2})?$/
                }
                onTextEdited: root.commitSize(text)
                onEditingFinished: {
                    root.commitSize(text);
                    root.syncFields(true);
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                text: Tr.tr("Free after")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }

            StyledTextField {
                id: afterField

                Layout.fillWidth: true
                enabled: root.enabled && (root.totalSpanMiB > root.sizeMiB || !root.fixedSize)
                verticalPadding: Tokens.padding.small
                horizontalPadding: Tokens.padding.medium
                floatingPlaceholder: false
                validator: RegularExpressionValidator {
                    regularExpression: /^\d*([.,]\d{0,2})?$/
                }
                onTextEdited: root.commitAfter(text)
                onEditingFinished: {
                    root.commitAfter(text);
                    root.syncFields(true);
                }
            }
        }

        TextButton {
            Layout.alignment: Qt.AlignBottom
            enabled: root.enabled
            text: Disks.unitLabel(root.useLargeUnit)
            type: TextButton.Tonal
            onClicked: root.useLargeUnit = !root.useLargeUnit
        }
    }

    // Plain-language delta summary
    StyledText {
        Layout.fillWidth: true
        font: Tokens.font.body.small
        color: Colours.palette.m3onSurfaceVariant
        wrapMode: Text.WordWrap
        text: {
            const newSizeText = Disks.human(root.sizeMiB * root.mib);
            if (root.isCreate)
                return root.beforeMiB > 0 ? Tr.tr("Starts after %1 of free space · size %2 (%3 free after)").arg(Disks.human(root.beforeMiB * root.mib)).arg(newSizeText).arg(Disks.human(root.afterMiB * root.mib)) : Tr.tr("New size: %1 (up to %2 available; %3 free after)").arg(newSizeText).arg(Disks.human(root.totalSpanMiB * root.mib)).arg(Disks.human(root.afterMiB * root.mib));
            const parts = [];
            if (root.beforeMiB !== root.origBeforeMiB) {
                const delta = (root.beforeMiB - root.origBeforeMiB) * root.mib;
                parts.push(delta > 0 ? Tr.tr("moves right by %1").arg(Disks.human(delta)) : Tr.tr("moves left by %1").arg(Disks.human(-delta)));
            }
            if (root.sizeMiB !== root.origSizeMiB)
                parts.push(Tr.tr("resizes from %1 to %2").arg(Disks.human(root.origSizeMiB * root.mib)).arg(newSizeText));
            if (parts.length === 0)
                return Tr.tr("Now %1 · drag the bar or edges, or enter exact sizes above").arg(newSizeText);
            const joined = parts.join(Tr.tr(" and "));
            return joined.charAt(0).toUpperCase() + joined.slice(1);
        }
    }
}
