import QtQuick
import Caelestia.Config

// The "Wave" motion (Wallpaper & style > Nebula > Animations > Panels and popouts): a panel rises
// out of its screen edge at the point it was opened from and spreads outward along the edge in both
// directions, like a wave front, keeping its own corners (no blob or droplet stage). Opened with
// the pointer (a click, a hover) it starts there; from a bar popout, at its button; by a shortcut,
// in the middle of its edge.
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

    readonly property bool active: GlobalConfig.appearance.style.shellAnim === "wave"
    readonly property real t: Math.max(0, Math.min(1.2, 1 - offsetScale))
    readonly property real d: 0 // (kept for the capture clamp: it starts from a point)

    // Where along the edge it grows from (relative to its final middle)
    property real originOffset: 0
    // A fixed point to grow from (in `space`), e.g. the bar button a popout belongs to; NaN: the
    // pointer if it was just used, else the middle
    property real origin: NaN

    function smooth(x: real): real {
        return x * x * (3 - 2 * x);
    }
    // Spreading along the edge leads; rising out of it follows a little behind, so the front is a
    // low wave that swells into the panel
    readonly property real spread: smooth(Math.max(0, Math.min(1, t)))
    readonly property real rise: smooth(Math.max(0, Math.min(1, (t - 0.06) / 0.94)))

    readonly property real along: active ? fullAlong * spread : fullAlong
    readonly property real depth: active ? fullDepth * rise : fullDepth
    readonly property real offset: active ? originOffset * (1 - spread) : 0
    // The content shows once the wave is big enough for it (and goes first when closing). Never
    // exactly 0: Qt stops drawing at 0, and the rounded masks inside then stayed black.
    readonly property real contentOpacity: active ? Math.max(0.004, Math.min(1, (spread - 0.35) / 0.4)) : 1
    // The panel's own corners all the way (only smaller while the panel is thinner than them)
    readonly property real radius: Math.min(Tokens.rounding.extraLarge, along / 2, depth)

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
