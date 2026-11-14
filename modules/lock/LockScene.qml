pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import Caelestia.Services
import qs.services
import qs.utils
import "Curves.js" as Curves

FocusScope {
    id: root

    required property Pam pam
    required property var screen
    property bool bootLock: false

    signal unlocked()

    property bool bootLoading: bootLock
    property bool bootMinElapsed: false
    property bool pendingWake: false
    property bool active: false
    property bool closing: false
    property bool unlockEmitted: false
    property real openT: 0
    property real closeT: 0
    property real modeT: 0
    property real shakeX: 0
    property real seconds: 0

    readonly property real o: openT * NebulaTheme.lock.openDuration
    readonly property real c: closeT * NebulaTheme.lock.closeDuration
    readonly property real m: modeT * NebulaTheme.lock.modeDuration
    readonly property real unit: Math.max(0.65, Math.min(1.5, Math.min(width / 1920, height / 1080)))
    readonly property real cx: width / 2
    readonly property real cy: height * NebulaTheme.lock.centerHeight
    readonly property real phase: seconds * Math.PI * 2 / NebulaTheme.lock.orbitPeriod - Math.PI / 2
    readonly property real radiusX: width * NebulaTheme.lock.orbitX
    readonly property real radiusY: height * NebulaTheme.lock.orbitY
    readonly property real innerPhase: -seconds * Math.PI * 2 / NebulaTheme.lock.innerPeriod + Math.PI / 2
    readonly property real innerX: width * NebulaTheme.lock.innerOrbitX
    readonly property real innerY: height * NebulaTheme.lock.innerOrbitY

    readonly property var missedList: {
        if (Config.lock.hideNotifs)
            return [];
        const groups = new Map();
        for (const n of Notifs.notClosed) {
            const name = n.appName || "Notification";
            if (!groups.has(name)) {
                const iconUrl = n.image
                    ? Qt.resolvedUrl(n.image).toString()
                    : (n.appIcon ? Quickshell.iconPath(n.appIcon, "") : Icons.getAppIcon(name, ""));
                groups.set(name, {
                    name: name,
                    count: 1,
                    summary: n.summary || "",
                    icon: iconUrl || ""
                });
            } else {
                const g = groups.get(name);
                g.count += 1;
                if (n.summary && !g.summary)
                    g.summary = n.summary;
            }
        }
        return Array.from(groups.values()).slice(0, NebulaTheme.lock.maxNotifications);
    }

    readonly property var activePlayer: Players.active
    readonly property bool mediaPlaying: activePlayer?.isPlaying ?? false
    readonly property int musicSlots: activePlayer ? 1 : 0
    readonly property int total: 1 + musicSlots + notes.count
    readonly property bool weatherOn: Weather.cc !== null
    readonly property bool batteryOn: true
    readonly property int innerTotal: (weatherOn ? 1 : 0) + 1 + (batteryOn ? 1 : 0)
    readonly property int moonIndex: weatherOn ? 1 : 0

    readonly property real activeClock: NebulaTheme.lock.activeClockSize * unit
    readonly property real musicX: cx - activeClock / 2 - NebulaTheme.lock.sideGap * unit - NebulaTheme.lock.activeMusicWidth * unit / 2
    readonly property real notificationX: cx + activeClock / 2 + NebulaTheme.lock.sideGap * unit + NebulaTheme.lock.activeNotificationWidth * unit / 2
    readonly property real rowY: cy - activeClock / 2 - NebulaTheme.lock.rowOffset * unit
    readonly property real inputY: cy + activeClock / 2 + (NebulaTheme.lock.inputGap + NebulaTheme.lock.inputHeight / 2) * unit
    readonly property real statsY: inputY + (NebulaTheme.lock.inputHeight / 2 + NebulaTheme.lock.statsGap + NebulaTheme.lock.statsHeight / 2) * unit

    readonly property real bass: {
        const v = Audio.cava.values;
        if (!v || v.length === 0)
            return 0;
        const limit = Math.min(8, v.length);
        let sum = 0;
        for (let i = 0; i < limit; i++)
            sum += v[i] ?? 0;
        return Math.min(1, sum / limit * 1.8);
    }
    property real pulse: mediaPlaying && !active ? bass : 0

    readonly property var bandLevels: {
        if (!mediaPlaying || active)
            return [];
        const v = Audio.cava.values;
        if (!v || v.length < 10)
            return [];
        const per = v.length / 10;
        const out = [];
        for (let b = 0; b < 10; b++) {
            let sum = 0;
            let n = 0;
            for (let i = Math.floor(b * per); i < Math.floor((b + 1) * per) && i < v.length; i++) {
                sum += v[i];
                n++;
            }
            const level = n > 0 ? sum / n : 0;
            out.push(Math.min(1, level * 1.3));
        }
        return out;
    }

    Behavior on pulse {
        NumberAnimation {
            duration: 70
        }
    }

    readonly property real holeBase: (1 + 0.25 * (Curves.outCubic(Curves.phase(m, 0, 260)) - Curves.outCubic(Curves.phase(m, 260, 260))))
        * (1 - Curves.inQuad(Curves.phase(m, 180, 320)))

    readonly property real holeScale: {
        if (closing) {
            const grow = modeT > 0 ? Curves.outBack(Curves.phase(c, 180, 350), NebulaTheme.lock.centerOvershoot) : 0;
            return Math.max(holeBase, grow) * (1 - Curves.inBack(Curves.phase(c, 1000, 420), NebulaTheme.lock.foldOvershoot));
        }
        const pop = Curves.outBack(Curves.phase(o, 0, 350), NebulaTheme.lock.centerOvershoot);
        const bump = Curves.outCubic(Curves.phase(o, 820, 260)) - Curves.outCubic(Curves.phase(o, 1080, 320));
        return pop * (1 + 0.25 * bump) * holeBase;
    }

    readonly property real holeBoost: {
        if (closing)
            return 0.25 + 1.55 * Curves.inQuad(Curves.phase(c, 0, 500));
        if (bootLoading)
            return 0.45 + 0.4 * Curves.inQuad(Curves.phase(o, 0, 750));
        if (o < 900)
            return Curves.inQuad(Curves.phase(o, 0, 900));
        return 1 - 0.75 * Curves.outQuint(Curves.phase(o, 960, 700));
    }

    readonly property real iconOpacity: closing
        ? (modeT > 0 ? Curves.phase(c, 180, 150) : 1) * (1 - Curves.phase(c, 1000, 250))
        : Curves.phase(o, 0, 200)

    readonly property real contentOpacity: closing
        ? 1 - Curves.inQuad(Curves.phase(c, 0, 100))
        : Curves.outCubic(Curves.phase(o, 1150, 140))

    readonly property real nebula: closing
        ? 1 - Curves.inQuad(Curves.phase(c, 180, 900))
        : Curves.outQuint(Curves.phase(o, 1000, 2400))

    readonly property real inputT: Curves.outBack(Curves.phase(m, 560, 300), NebulaTheme.lock.wingOvershoot)

    ServiceRef {
        service: root.visible && root.mediaPlaying && !root.active ? Audio.cava : null
    }

    function wing(openDelay: real, closeDelay: real): real {
        if (closing)
            return 1 - Curves.inQuad(Curves.phase(c, closeDelay, 300));
        return Curves.outBack(Curves.phase(o, 1080 + openDelay, 250), NebulaTheme.lock.wingOvershoot);
    }

    function settle(delay: real): real {
        return Curves.outBack(Curves.phase(m, 260 + delay, 380), NebulaTheme.lock.wingOvershoot);
    }

    function openMs(): int {
        return Math.round(NebulaTheme.lock.openDuration * NebulaTheme.anim.scale);
    }

    function closeMs(): int {
        return Math.round(NebulaTheme.lock.closeDuration * NebulaTheme.anim.scale);
    }

    function finishBootLoading(): void {
        if (!bootLoading)
            return;
        bootLoading = false;
        bootIntroAnim.stop();
        bootMinTimer.stop();
        bootFallbackTimer.stop();
        openAnim.from = openT;
        openAnim.to = 1;
        openAnim.duration = Math.max(400, Math.round(openMs() * Math.max(0.1, 1 - openT)));
        openAnim.restart();
    }

    function wake(): void {
        idleTimer.restart();
        if (closing)
            return;
        if (bootLoading) {
            pendingWake = true;
            finishBootLoading();
            return;
        }
        if (!active && openT > 0.4)
            active = true;
    }

    function startUnlock(): void {
        if (closing)
            return;
        closing = true;
        bootLoading = false;
        pendingWake = false;
        unlockEmitted = false;
        bootIntroAnim.stop();
        openAnim.stop();
        bootMinTimer.stop();
        bootFallbackTimer.stop();
        root.openT = 1;
        pam.clearTransientState();
        pam.buffer = "";
        closeAnim.restart();
    }

    function emitUnlocked(): void {
        if (unlockEmitted)
            return;
        unlockEmitted = true;
        unlocked();
    }

    function handleKey(event: KeyEvent): void {
        if (event.isAutoRepeat && event.key !== Qt.Key_Backspace)
            return;
        if (closing)
            return;

        const isPrintable = /^[^\x00-\x20\x7F-\x9F]+$/.test(event.text);

        if (bootLoading || !active) {
            wake();
            if (isPrintable && !bootLoading) {
                pam.handleKey(event);
            } else if (isPrintable && bootLoading) {
                pam.handleKey(event);
            } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Escape) {
                event.accepted = true;
            }
            return;
        }

        idleTimer.restart();
        if (event.key === Qt.Key_Escape) {
            if (pam.buffer.length > 0)
                pam.buffer = "";
            else
                active = false;
            event.accepted = true;
            return;
        }
        pam.handleKey(event);
    }

    function syncNotes(): void {
        const want = missedList;
        for (let i = notes.count - 1; i >= 0; i--) {
            const name = notes.get(i).name;
            if (!want.some(a => a.name === name))
                notes.remove(i);
        }
        want.forEach((a, i) => {
            let at = -1;
            for (let j = 0; j < notes.count; j++) {
                if (notes.get(j).name === a.name)
                    at = j;
            }
            if (at < 0) {
                notes.insert(Math.min(i, notes.count), a);
            } else {
                notes.set(at, a);
                if (at !== i)
                    notes.move(at, i, 1);
            }
        });
    }

    focus: true

    Keys.onPressed: event => handleKey(event)

    onMissedListChanged: syncNotes()

    onOpenTChanged: {
        if (pendingWake && !bootLoading && openT > 0.4) {
            pendingWake = false;
            wake();
        }
    }

    onCloseTChanged: {
        if (closing && !unlockEmitted && closeT >= 0.95 && holeScale <= 0.02)
            emitUnlocked();
    }

    onActiveChanged: {
        modeAnim.stop();
        modeAnim.to = active ? 1 : 0;
        modeAnim.duration = Math.max(1, Math.round(NebulaTheme.lock.modeDuration * NebulaTheme.anim.scale * Math.abs(modeAnim.to - modeT)));
        modeAnim.start();
        if (active && GlobalConfig.lock.triggerHowdyOnWake && pam.howdy.canAttempt && !pam.howdy.active)
            pam.howdy.start();
    }

    Component.onCompleted: {
        if (!Weather.cc)
            Weather.reload();
        syncNotes();
        forceActiveFocus();
        if (bootLock) {
            bootLoading = true;
            bootIntroAnim.start();
            bootMinTimer.start();
            bootFallbackTimer.start();
        } else {
            openAnim.start();
        }
    }

    ListModel {
        id: notes
    }

    FrameAnimation {
        running: root.visible
        onTriggered: root.seconds += frameTime
    }

    Timer {
        id: bootMinTimer

        interval: NebulaTheme.lock.bootLoadingMinMs
        onTriggered: {
            root.bootMinElapsed = true;
            if (LiveStartFrame.ready || !LiveStartFrame.showing)
                root.finishBootLoading();
        }
    }

    Timer {
        id: bootFallbackTimer

        interval: 2200
        onTriggered: root.finishBootLoading()
    }

    Connections {
        target: LiveStartFrame
        function onReadyChanged(): void {
            if (LiveStartFrame.ready && root.bootLoading && root.bootMinElapsed)
                root.finishBootLoading();
        }
    }

    Timer {
        id: idleTimer

        interval: NebulaTheme.lock.idleTimeout
        running: root.active && root.pam.buffer.length === 0 && !root.pam.passwd.active && !root.closing
        onTriggered: {
            if (root.pam.buffer.length === 0 && !root.pam.passwd.active && !root.closing)
                root.active = false;
        }
    }

    NumberAnimation {
        id: bootIntroAnim

        target: root
        property: "openT"
        from: 0
        to: 0.22
        duration: 480
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: openAnim

        target: root
        property: "openT"
        from: 0
        to: 1
        duration: root.openMs()
        easing.type: Easing.Linear
    }

    NumberAnimation {
        id: modeAnim

        target: root
        property: "modeT"
        easing.type: Easing.Linear
    }

    NumberAnimation {
        id: closeAnim

        target: root
        property: "closeT"
        from: 0
        to: 1
        duration: root.closeMs()
        easing.type: Easing.Linear
        onFinished: root.emitUnlocked()
    }

    SequentialAnimation {
        id: shakeAnim

        NumberAnimation { target: root; property: "shakeX"; to: -10; duration: 55 }
        NumberAnimation { target: root; property: "shakeX"; to: 9; duration: 70 }
        NumberAnimation { target: root; property: "shakeX"; to: -6; duration: 70 }
        NumberAnimation { target: root; property: "shakeX"; to: 3; duration: 70 }
        NumberAnimation { target: root; property: "shakeX"; to: 0; duration: 60 }
    }

    Connections {
        target: root.pam

        function onFlashMsg(): void {
            shakeAnim.restart();
            centralClock.triggerErrorFlash();
            if (!root.active && !root.closing)
                root.wake();
        }
    }

    LockBackdrop {
        anchors.fill: parent
        screen: root.screen
        openT: root.openT
        closeT: root.closeT
        modeT: root.modeT
        closing: root.closing
        bootLock: root.bootLock
    }

    LockStars {
        anchors.fill: parent
        opacity: root.closing
            ? 1 - Curves.inQuad(Curves.phase(root.c, 250, 750))
            : Math.min(1, root.openT * 2.5)
    }

    NebulaClouds {
        anchors.fill: parent
        spread: root.nebula
    }

    BlackHole {
        x: root.cx - width / 2
        y: root.cy - height / 2
        width: NebulaTheme.lock.holeSize * root.unit
        height: width
        scale: Math.max(0, root.holeScale) * (1 + NebulaTheme.lock.holePulse * root.pulse)
        boost: root.holeBoost
        pulse: root.pulse
        bootLoading: root.bootLoading
        levels: root.bandLevels
        iconOpacity: root.iconOpacity
        visible: root.holeScale > 0.002
    }

    OrbitSlot {
        centerX: root.cx
        centerY: root.cy
        radiusX: root.radiusX
        radiusY: root.radiusY
        phase: root.phase
        seconds: root.seconds
        slotIndex: 0
        total: root.total
        reveal: root.wing(0, 0)
        settle: root.settle(0)
        idleWidth: NebulaTheme.lock.clockSize * root.unit
        idleHeight: idleWidth
        layoutWidth: root.activeClock
        layoutHeight: layoutWidth
        layoutX: root.cx + root.shakeX * 0.6
        layoutY: root.cy

        LockClock {
            id: centralClock

            anchors.fill: parent
        }
    }

    OrbitSlot {
        centerX: root.cx
        centerY: root.cy
        radiusX: root.radiusX
        radiusY: root.radiusY
        phase: root.phase
        seconds: root.seconds
        slotIndex: 1
        total: root.total
        reveal: root.activePlayer ? root.wing(60, 40) : 0
        settle: root.settle(60)
        idleWidth: NebulaTheme.lock.musicWidth * root.unit
        idleHeight: NebulaTheme.lock.musicHeight * root.unit
        layoutWidth: NebulaTheme.lock.activeMusicWidth * root.unit
        layoutHeight: NebulaTheme.lock.activeMusicHeight * root.unit
        layoutX: root.musicX
        layoutY: root.cy

        LockMusic {
            anchors.fill: parent
            morph: root.settle(60)
        }
    }

    Repeater {
        model: notes

        OrbitSlot {
            id: note

            required property int index
            required property string name
            required property int count
            required property string summary
            required property string icon

            centerX: root.cx
            centerY: root.cy
            radiusX: root.radiusX
            radiusY: root.radiusY
            phase: root.phase
            seconds: root.seconds
            slotIndex: 1 + root.musicSlots + index
            total: root.total
            reveal: root.wing(120 + index * 60, 80 + index * 40)
            settle: root.settle(120 + index * 60)
            idleWidth: NebulaTheme.lock.notificationWidth * root.unit
            idleHeight: NebulaTheme.lock.notificationHeight * root.unit
            layoutWidth: NebulaTheme.lock.activeNotificationWidth * root.unit
            layoutHeight: NebulaTheme.lock.activeNotificationHeight * root.unit
            layoutX: root.notificationX
            layoutY: root.cy + (index - (notes.count - 1) / 2) * (NebulaTheme.lock.activeNotificationHeight + NebulaTheme.lock.notificationGap) * root.unit

            Component.onCompleted: {
                if (root.openT > 0.7 && !root.closing)
                    arriveNow();
            }

            LockNotification {
                anchors.fill: parent
                name: note.name
                count: note.count
                summary: note.summary
                icon: note.icon
                unit: root.unit
                morph: root.settle(120 + note.index * 60)
            }
        }
    }

    OrbitSlot {
        centerX: root.cx
        centerY: root.cy
        radiusX: root.innerX
        radiusY: root.innerY
        phase: root.innerPhase
        seconds: root.seconds
        slotIndex: 0
        total: root.innerTotal
        reveal: root.weatherOn ? root.wing(180, 120) : 0
        settle: root.settle(200)
        idleWidth: NebulaTheme.lock.planetSize * root.unit
        idleHeight: idleWidth
        layoutWidth: 92 * root.unit
        layoutHeight: layoutWidth
        layoutX: root.cx + (0 - (root.innerTotal - 1) / 2) * NebulaTheme.lock.rowSpacing * root.unit
        layoutY: root.rowY

        LockWeather {
            anchors.fill: parent
        }
    }

    OrbitSlot {
        centerX: root.cx
        centerY: root.cy
        radiusX: root.innerX
        radiusY: root.innerY
        phase: root.innerPhase
        seconds: root.seconds
        slotIndex: root.moonIndex
        total: root.innerTotal
        reveal: root.wing(240, 160)
        settle: root.settle(240)
        idleWidth: NebulaTheme.lock.moonSize * root.unit
        idleHeight: idleWidth + 24
        layoutWidth: 80 * root.unit
        layoutHeight: layoutWidth + 24
        layoutX: root.cx + (root.moonIndex - (root.innerTotal - 1) / 2) * NebulaTheme.lock.rowSpacing * root.unit
        layoutY: root.rowY + 12

        LockMoon {
            anchors.fill: parent
        }
    }

    OrbitSlot {
        centerX: root.cx
        centerY: root.cy
        radiusX: root.innerX
        radiusY: root.innerY
        phase: root.innerPhase
        seconds: root.seconds
        slotIndex: root.moonIndex + 1
        total: root.innerTotal
        reveal: root.batteryOn ? root.wing(300, 200) : 0
        settle: root.settle(280)
        idleWidth: NebulaTheme.lock.batterySize * root.unit
        idleHeight: idleWidth
        layoutWidth: 80 * root.unit
        layoutHeight: layoutWidth
        layoutX: root.cx + (root.moonIndex + 1 - (root.innerTotal - 1) / 2) * NebulaTheme.lock.rowSpacing * root.unit
        layoutY: root.rowY

        LockBattery {
            anchors.fill: parent
        }
    }

    SpiralSlot {
        originX: root.cx
        originY: root.cy
        targetX: root.cx + root.shakeX
        targetY: root.inputY
        reveal: Math.min(root.inputT, root.closing ? 1 - Curves.inQuad(Curves.phase(root.c, 0, 300)) : 1)
        width: NebulaTheme.lock.inputWidth * root.unit
        height: NebulaTheme.lock.inputHeight * root.unit

        LockInput {
            anchors.fill: parent
            pam: root.pam
            unlocking: root.closing
        }
    }

    Item {
        readonly property real shownT: Math.min(
            Curves.outCubic(Curves.phase(root.m, 660, 420)),
            root.closing ? 1 - Curves.inQuad(Curves.phase(root.c, 60, 300)) : 1
        )

        x: root.cx - width / 2
        y: root.statsY - height / 2 + (1 - shownT) * 28 * root.unit
        width: NebulaTheme.lock.statsWidth * root.unit
        height: NebulaTheme.lock.statsHeight * root.unit
        opacity: shownT
        visible: opacity > 0

        LockStats {
            anchors.fill: parent
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onPressed: {
            root.forceActiveFocus();
            root.wake();
        }
    }
}
