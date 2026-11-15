import QtQuick
import Caelestia.Config

// How the shell's panels open and close (Wallpaper & style > Nebula > Animations > Panels and
// popouts): animates `target.offsetScale` (1 hidden .. 0 shown) to `to`.
//   caelestia  Caelestia's curves (default)
//   nebula     Nebula's decelerating curve (the panels expand instead of sliding)
//   island     a spring, expanding like Nebula's media island / Apple's Dynamic Island
//   spring     a physics spring: settles without bouncing, keeps its momentum when reversed
//   m3spring   Material 3 Expressive's spatial spring, tuned to settle without bouncing
//   glide      a long, soft ease-out
// (Explicit animations, not a Behavior: a Behavior can't switch animations once set.)
QtObject {
    id: root

    required property Item target
    required property real to

    readonly property string style: GlobalConfig.appearance.style.shellAnim
    readonly property bool springy: style === "spring" || style === "island" || style === "m3spring"
    // Animation speed (Accessibility) scales the springs too
    readonly property real speed: 1 / Math.max(0.05, GlobalConfig.appearance.anim.durations.scale)

    readonly property SpringAnimation springAnim: SpringAnimation {
        target: root.target
        property: "offsetScale"
        spring: (root.style === "m3spring" ? 5.2 : root.style === "island" ? 4.2 : 3.6) * root.speed * root.speed
        damping: root.style === "m3spring" ? 0.42 : 0.38
        mass: 1
        epsilon: 0.0005
    }

    readonly property Anim curveAnim: Anim {
        target: root.target
        property: "offsetScale"
        type: Anim.DefaultSpatial
        duration: root.style === "glide" ? Tokens.anim.durations.expressiveSlowSpatial * 1.25 : Tokens.anim.durations.expressiveDefaultSpatial
    }

    function run(): void {
        // (set here, not only by binding: when `to` changes, this handler can run before the
        // animations' bindings update, and they'd head for the old state)
        springAnim.to = to;
        curveAnim.to = to;
        if (springy) {
            curveAnim.stop();
            // a running spring just follows the new target (keeping its velocity)
            if (!springAnim.running)
                springAnim.start();
        } else {
            springAnim.stop();
            curveAnim.restart();
        }
    }

    onToChanged: run()
    Component.onCompleted: if (target && target.offsetScale !== to)
        run()
}
