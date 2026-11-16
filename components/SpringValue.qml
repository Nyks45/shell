import QtQuick
import Caelestia.Config

// A number that follows `target` like a spring (mass 1): fast, and it keeps its speed when the
// target changes mid-way (a panel closed while still opening turns around smoothly). Stepped
// every frame at the screen's rate in fixed small steps. Default: DankMaterialShell's
// "expressive" stiffness (560) with damping 44, just under critical, so it settles without a
// visible bounce (about 0.25 s to rest, most of the way in 0.12 s).
QtObject {
    id: root

    property real target
    property real value
    property real velocity
    property real stiffness: 560
    property real damping: 44
    // Settles when this close and this slow
    property real epsilon: 0.0005
    readonly property bool moving: frames.running

    // Jump without animating
    function snap(v: real): void {
        frames.running = false;
        velocity = 0;
        value = v;
        target = v;
    }

    onTargetChanged: {
        // Animations off (the shell's speed scale at 0): jump
        if (GlobalConfig.appearance.anim.durations.scale <= 0.01)
            snap(target);
        else
            frames.running = true;
    }

    readonly property FrameAnimation frames: FrameAnimation {
        onTriggered: {
            // The shell's animation speed setting stretches time
            const scale = Math.max(0.05, GlobalConfig.appearance.anim.durations.scale);
            let dt = Math.min(0.05, frameTime) / scale;
            const step = 1 / 480;
            while (dt > 0) {
                const h = Math.min(step, dt);
                root.velocity += (root.stiffness * (root.target - root.value) - root.damping * root.velocity) * h;
                root.value += root.velocity * h;
                dt -= h;
            }
            if (Math.abs(root.target - root.value) < root.epsilon && Math.abs(root.velocity) < root.epsilon * 10) {
                root.value = root.target;
                root.velocity = 0;
                running = false;
            }
        }
    }
}
