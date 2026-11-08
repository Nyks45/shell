pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// A drive's layout as a bar: one segment per partition (its colour by
// filesystem, the used part darker) and per stretch of free space (outlined).
// Very small ones get a minimum width so every one stays visible/clickable.
Item {
    id: root

    required property var drive
    // The highlighted segment's id (partition block path, or "free:OFFSET")
    property string selected
    property bool interactive

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
    readonly property real minSeg: 10

    function colourFor(seg: var): color {
        if (seg.kind === "free")
            return "transparent";
        const p = seg.part;
        const t = p.crypto ? "crypto" : p.fs.type;
        if (t === "crypto")
            return Colours.palette.m3tertiaryContainer;
        if (p.typeName === "EFI system" || t === "vfat")
            return Colours.palette.m3secondaryContainer;
        if (t === "ntfs" || t === "exfat")
            return Colours.palette.m3secondary;
        if (t === "btrfs" || t === "ext4" || t === "xfs" || t === "f2fs")
            return Colours.palette.m3primary;
        if (t === "swap")
            return Colours.palette.m3tertiary;
        return Colours.palette.m3surfaceContainerHighest;
    }

    implicitHeight: Tokens.padding.large * 2.4

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
                // Each segment's share of the width, with a floor for tiny ones
                readonly property real avail: row.width - row.spacing * (root.segments.length - 1)
                readonly property int smallCount: root.segments.filter(x => x.size / seg.total * seg.avail < root.minSeg).length
                readonly property real bigTotal: root.segments.filter(x => x.size / seg.total * seg.avail >= root.minSeg).reduce((s, x) => s + x.size, 0) || 1
                readonly property bool isSmall: modelData.size / total * avail < root.minSeg
                readonly property bool isSelected: root.selected === modelData.id
                readonly property real usedRatio: {
                    const fs = modelData.part?.crypto?.inner ?? modelData.part?.fs;
                    return fs?.size > 0 && fs.used >= 0 ? Math.min(1, fs.used / fs.size) : 0;
                }

                width: isSmall ? root.minSeg : Math.max(root.minSeg, (avail - smallCount * root.minSeg) * modelData.size / bigTotal)
                height: row.height

                StyledRect {
                    anchors.fill: parent
                    radius: Tokens.rounding.small
                    color: seg.modelData.kind === "free" ? "transparent" : Qt.alpha(root.colourFor(seg.modelData), 0.45)
                    border.width: seg.modelData.kind === "free" || seg.isSelected ? 2 : 0
                    border.color: seg.isSelected ? Colours.palette.m3onSurface : Colours.palette.m3outlineVariant

                    // The used part
                    StyledRect {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * seg.usedRatio
                        radius: parent.radius
                        visible: seg.usedRatio > 0
                        color: root.colourFor(seg.modelData)
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: seg.modelData.kind === "part" && !!seg.modelData.part.crypto && parent.width > 24
                        text: seg.modelData.part?.crypto?.unlocked ? "lock_open" : "lock"
                        color: Colours.palette.m3onTertiaryContainer
                        fontStyle: Tokens.font.icon.small
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.interactive
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.clicked(seg.modelData)
                }
            }
        }
    }
}
