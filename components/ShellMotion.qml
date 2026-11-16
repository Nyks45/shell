import QtQuick
import Caelestia.Config

// How the shell's panels open and close (Wallpaper & style > Nebula > Animations > Panels):
// animates `target.offsetScale` (1 hidden .. 0 shown) to `to`.
//   caelestia  Caelestia's own motion (default)
//   wave       the panel rises out of its edge where it was opened from and spreads along it
//              like a wave (components/WaveMotion.qml)
// (Explicit animations, not a Behavior: a Behavior can't switch animations once set.)
// Other styles are kept on the motion-styles branch.
QtObject {
    id: root

    required property Item target
    required property real to
    // Wave's opening curve (popouts: a sound wave, fast out from the button, slowing at the edges)
    property var waveOpenCurve: [0.42, 0, 0.18, 1, 1, 1]

    readonly property bool drop: GlobalConfig.appearance.style.shellAnim === "wave"

    // Wave: a timed curve that starts gently and lands softly
    readonly property NumberAnimation dropAnim: NumberAnimation {
        target: root.target
        property: "offsetScale"
        duration: (root.to === 0 ? 620 : 460) * GlobalConfig.appearance.anim.durations.scale
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.to === 0 ? root.waveOpenCurve : [0.4, 0, 0.6, 1, 1, 1]
    }

    readonly property Anim curveAnim: Anim {
        target: root.target
        property: "offsetScale"
    }

    function run(): void {
        // (set here, not only by binding: when `to` changes, this handler can run before the
        // animations' bindings update, and they'd head for the old state)
        dropAnim.to = to;
        curveAnim.to = to;
        if (drop) {
            curveAnim.stop();
            dropAnim.restart();
        } else {
            dropAnim.stop();
            curveAnim.restart();
        }
    }

    onToChanged: run()
    Component.onCompleted: if (target && target.offsetScale !== to)
        run()
}
