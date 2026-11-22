pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

// A drive's layout bar: colour-coded filesystem segments with inline labels
// (when wide enough), hover readout, and optional clickable legend.
ColumnLayout {
    id: root

    required property var drive
    // The highlighted segment's id (partition block path, or "free:OFFSET")
    property string selected
    property bool interactive
    property bool showLegend: false
    property real barHeight: Tokens.padding.large * 2.4
    property string hoveredId: ""

    signal clicked(segment: var)

    // Segments in disk order: { kind: "part"|"free", id, offset, size, part }
    readonly property var segments: {
        if (!drive)
            return [];
        if (drive.whole)
            return [{
                    kind: "part",
                    id: drive.whole.id,
                    offset: 0,
                    size: drive.size,
                    part: drive.whole
                }];
        const out = drive.partitions.filter(p => !p.isContained).map(p => ({
                    kind: "part",
                    id: p.id,
                    offset: p.offset,
                    size: p.size,
                    part: p
                }));
        for (const f of drive.free)
            out.push({
                kind: "free",
                id: `free:${f.offset}`,
                offset: f.offset,
                size: f.size,
                part: null
            });
        return out.sort((a, b) => a.offset - b.offset);
    }
    readonly property real minSeg: 14
    readonly property var hoveredSeg: hoveredId ? segments.find(s => s.id === hoveredId) ?? null : null

    function segText(seg: var): string {
        if (!seg)
            return "";
        return seg.kind === "free" ? Tr.tr("Free space") : Disks.partName(seg.part, root.drive);
    }

    function textColourFor(seg: var): color {
        if (seg.kind === "free")
            return Colours.palette.m3onSurfaceVariant;
        return Disks.onFsColor(seg.part);
    }

    spacing: Tokens.spacing.small

    Item {
        Layout.fillWidth: true
        implicitHeight: root.barHeight

        Row {
            id: row

            anchors.fill: parent
            spacing: 3

            Repeater {
                model: root.segments

                Item {
                    id: seg

                    required property var modelData
                    required property int index
                    readonly property real total: root.segments.reduce((s, x) => s + x.size, 0) || 1
                    readonly property real avail: Math.max(0, row.width - row.spacing * Math.max(0, root.segments.length - 1))
                    readonly property int smallCount: root.segments.filter(x => x.size / seg.total * seg.avail < root.minSeg).length
                    readonly property real bigTotal: root.segments.filter(x => x.size / seg.total * seg.avail >= root.minSeg).reduce((s, x) => s + x.size, 0) || 1
                    readonly property bool isSmall: modelData.size / total * avail < root.minSeg
                    readonly property bool isSelected: root.selected === modelData.id
                    readonly property bool isHovered: root.hoveredId === modelData.id
                    readonly property color segColor: seg.modelData.kind === "free" ? "transparent" : Disks.fsColor(seg.modelData.part)
                    readonly property real usedRatio: {
                        const fs = modelData.part?.crypto?.inner ?? modelData.part?.fs;
                        return fs?.size > 0 && fs.used >= 0 ? Math.min(1, fs.used / fs.size) : 0;
                    }
                    readonly property string inlineLabel: seg.width >= 150 ? `${root.segText(seg.modelData)} · ${Disks.human(seg.modelData.size)}` : root.segText(seg.modelData)
                    readonly property bool showInlineLabel: seg.width >= 68 && !(seg.modelData.kind === "part" && !!seg.modelData.part.crypto)

                    width: isSmall ? root.minSeg : Math.max(root.minSeg, (avail - smallCount * root.minSeg) * modelData.size / bigTotal)
                    height: row.height

                    StyledRect {
                        id: segRect

                        anchors.fill: parent
                        radius: Tokens.rounding.small
                        clip: true
                        color: seg.modelData.kind === "free" ? "transparent" : Qt.alpha(seg.segColor, seg.isHovered ? 0.35 : 0.25)

                        SegLabel {
                            width: Math.max(0, segRect.width - Tokens.padding.small * 2)
                            visible: seg.showInlineLabel
                            text: seg.inlineLabel
                            color: Colours.palette.m3onSurface
                        }

                        // The used part (clips a matching label in m3on* colour at the fill boundary)
                        StyledRect {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width * seg.usedRatio
                            radius: parent.radius
                            clip: true
                            visible: seg.usedRatio > 0
                            color: seg.segColor

                            SegLabel {
                                width: Math.max(0, segRect.width - Tokens.padding.small * 2)
                                visible: seg.showInlineLabel
                                text: seg.inlineLabel
                                color: root.textColourFor(seg.modelData)
                            }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            visible: seg.modelData.kind === "part" && !!seg.modelData.part.crypto && parent.width > 24
                            text: seg.modelData.part?.crypto?.unlocked ? "lock_open" : "lock"
                            color: Colours.palette.m3onTertiaryContainer
                            fontStyle: Tokens.font.icon.small
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "transparent"
                            border.width: seg.isHovered || seg.isSelected || seg.modelData.kind === "free" ? 2 : 0
                            border.color: seg.isSelected || seg.isHovered ? Colours.palette.m3onSurface : Colours.palette.m3outlineVariant
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.interactive
                        hoverEnabled: root.interactive
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onEntered: root.hoveredId = seg.modelData.id
                        onExited: if (root.hoveredId === seg.modelData.id)
                            root.hoveredId = ""
                        onClicked: root.clicked(seg.modelData)
                    }
                }
            }
        }
    }

    Flow {
        Layout.fillWidth: true
        visible: root.showLegend && root.segments.length > 0
        spacing: Tokens.spacing.medium

        Repeater {
            model: root.segments

            StyledRect {
                id: leg

                required property var modelData
                readonly property bool isFree: modelData.kind === "free"

                implicitWidth: legRow.implicitWidth + Tokens.padding.small * 2
                implicitHeight: legRow.implicitHeight + Tokens.padding.extraSmall
                radius: Tokens.rounding.small
                color: root.hoveredId === leg.modelData.id ? Colours.layer(Colours.palette.m3surfaceContainerHigh, 2) : "transparent"

                RowLayout {
                    id: legRow

                    anchors.centerIn: parent
                    spacing: Tokens.spacing.extraSmall

                    Rectangle {
                        width: 10
                        height: 10
                        radius: 5
                        color: leg.isFree ? "transparent" : Disks.fsColor(leg.modelData.part)
                        border.width: leg.isFree ? 1.5 : 0
                        border.color: Colours.palette.m3outline
                    }

                    StyledText {
                        text: `${root.segText(leg.modelData)} (${Disks.human(leg.modelData.size)})`
                        color: root.hoveredId === leg.modelData.id ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.interactive
                    hoverEnabled: root.interactive
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onEntered: root.hoveredId = leg.modelData.id
                    onExited: if (root.hoveredId === leg.modelData.id)
                        root.hoveredId = ""
                    onClicked: root.clicked(leg.modelData)
                }
            }
        }
    }

    // Permanent single-line readout below the legend so hovering never shifts layout.
    StyledText {
        Layout.fillWidth: true
        visible: root.interactive
        maximumLineCount: 1
        elide: Text.ElideRight
        font: Tokens.font.label.small
        color: root.hoveredSeg ? Colours.palette.m3primary : Colours.palette.m3outline
        text: {
            const s = root.hoveredSeg;
            if (!s)
                return Tr.tr("Click any partition to manage it, or click free space below to create one.");
            if (s.kind === "free")
                return Tr.tr("Free space · %1 · click to create a partition").arg(Disks.human(s.size));
            const p = s.part;
            const fs = p.crypto?.inner ?? p.fs;
            const freeText = fs?.size > 0 && fs?.used >= 0 ? Tr.tr("%1 free").arg(Disks.human(fs.size - fs.used)) : "";
            const pendText = p.pendingOp ? Tr.tr("pending") : "";
            return [Disks.partName(p, root.drive), Disks.fsName(p.fs?.type ?? ""), Disks.human(s.size), freeText, pendText].filter(Boolean).join(" · ");
        }
    }

    component SegLabel: StyledText {
        x: Tokens.padding.small
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        font: Tokens.font.label.small
    }
}
