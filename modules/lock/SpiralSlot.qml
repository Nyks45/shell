import QtQuick

Item {
    id: root

    property real originX: 0
    property real originY: 0
    property real targetX: 0
    property real targetY: 0
    property real reveal: 0
    property real depthScale: 1
    property real depthOpacity: 1

    readonly property real turn: (1 - reveal) * NebulaTheme.lock.spiralTurn
    readonly property real vx: (targetX - originX) * reveal
    readonly property real vy: (targetY - originY) * reveal

    x: originX + vx * Math.cos(turn) - vy * Math.sin(turn) - width / 2
    y: originY + vx * Math.sin(turn) + vy * Math.cos(turn) - height / 2
    scale: Math.max(0, NebulaTheme.lock.wingStartScale + (1 - NebulaTheme.lock.wingStartScale) * reveal) * depthScale
    opacity: Math.max(0, Math.min(1, reveal * 1.6)) * depthOpacity
    visible: opacity > 0
}
