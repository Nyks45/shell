import QtQuick
import Caelestia.Config

// The "Drop" motion (Wallpaper & style > Nebula > Animations > Panels and popouts): a panel grows
// out of the point it was opened from as a liquid droplet. It starts as a small round blob on its
// screen edge (the blob border pulls it into a teardrop), then swells and slides into the full
// panel while its corners settle. Opened with the pointer (a click, a hover), it grows from there
// along its edge; opened by a shortcut, from the middle of its edge.
//
// The panel applies `along` / `depth` as its size, `offset` as its shift along the edge, and keeps
// its content still with `contentShift`; its background reads `radius`.
QtObject {
    id: root

    required property Item panel
    required property ScreenState screenState
    // "top", "bottom", "left" or "right": the screen edge the panel hangs from
    required property string edge
    // Full size along the edge and across it, and where its middle sits along the edge (in the
    // panel's parent's coordinates)
    required property real fullAlong
    required property real fullDepth
    required property real finalCenter
    // 1 hidden .. 0 shown (the panel's offsetScale)
    required property real offsetScale
    required property bool open
    // The coordinates `finalCenter` is in (default: the panel's parent)
    property Item space: panel?.parent ?? null

    readonly property bool active: GlobalConfig.appearance.style.shellAnim === "drop"
    readonly property real t: Math.max(0, Math.min(1.2, 1 - offsetScale))
    // The droplet's size when it appears
    readonly property real d: Math.min(56, fullAlong, fullDepth * 2)

    // Where along the edge it grows from (relative to its final middle)
    property real originOffset: 0
    // A fixed point to grow from (in `space`), e.g. the bar button a popout belongs to; NaN: the
    // pointer if it was just used, else the middle
    property real origin: NaN

    // Two stages: first a round droplet swells out of the edge (the blob border pulls it into a
    // teardrop), then it widens and slides into the panel
    readonly property real swell: Math.max(0, Math.min(1, t / 0.3))
    readonly property real spread: smooth(Math.max(0, Math.min(1, (t - 0.18) / 0.82)))
    function smooth(x: real): real {
        return x * x * (3 - 2 * x);
    }

    // (from nothing: closing, it shrinks all the way back into the edge and leaves nothing)
    readonly property real birth: Math.max(0, Math.min(1, t / 0.08))
    readonly property real along: active ? (d + (fullAlong - d) * spread) * birth : fullAlong
    readonly property real depth: active ? (d * 0.45 + (d * 1.1 - d * 0.45) * swell) * birth + (fullDepth - d * 1.1) * Math.max(0, Math.min(1.1, (t - 0.12) / 0.88)) : fullDepth
    readonly property real offset: active ? originOffset * (1 - spread) : 0
    // The panel's content shows once the drop is big enough for it (and goes first when closing).
    // Never exactly 0: Qt stops drawing at 0, and the rounded masks inside then stayed black.
    readonly property real contentOpacity: active ? Math.max(0.004, Math.min(1, (spread - 0.3) / 0.35)) : 1
    // Round as a drop, settling into the panel's own corners
    readonly property real radius: active ? Math.max(Tokens.rounding.extraLarge, (1 - spread) * Math.min(along, depth * 2) / 2 + spread * Tokens.rounding.extraLarge) : Tokens.rounding.extraLarge

    function capture(): void {
        if (!active || !space)
            return;
        const s = screenState;
        const recent = s && s.pointerX >= 0 && Date.now() - s.pointerTime < 900;
        let o = 0;
        if (!isNaN(origin)) {
            o = origin - finalCenter;
        } else if (recent) {
            const p = space.mapFromItem(null, s.pointerX, s.pointerY);
            o = (edge === "right" || edge === "left" ? p.y : p.x) - finalCenter;
        }
        const half = Math.max(0, (fullAlong - d) / 2);
        originOffset = Math.max(-half, Math.min(half, o));
    }

    onOpenChanged: if (open)
        capture()
}
