pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Wayland
import Caelestia.Config
import Caelestia.Multimedia
import Caelestia.State
import qs.components
import qs.services

WlSessionLockSurface {
    id: root

    required property WlSessionLock lock
    required property Pam pam

    readonly property alias unlocking: unlockAnim.running

    contentItem.Config.screen: screen.name
    contentItem.Tokens.screen: screen.name

    color: "transparent"

    Connections {
        function onUnlock(): void {
            unlockAnim.start();
        }

        target: root.lock
    }

    SequentialAnimation {
        id: unlockAnim

        ParallelAnimation {
            Anim {
                target: lockContent
                property: "opacity"
                to: 0
                type: Anim.FastEffects
            }
            Anim {
                target: lockContent
                property: "scale"
                to: 0.97
                type: Anim.FastSpatial
            }
        }
        PropertyAction {
            target: root.lock
            property: "locked"
            value: false
        }
    }

    ParallelAnimation {
        id: initAnim

        running: true

        Anim {
            target: lockContent
            property: "opacity"
            to: 1
            type: Anim.FastEffects
        }
        Anim {
            target: lockContent
            property: "scale"
            to: 1
            type: Anim.DefaultSpatial
        }
    }

    Item {
        id: background

        anchors.fill: parent
        opacity: 1

        layer.enabled: true
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1
            blurMax: 64
            blurMultiplier: 1
        }

        Loader {
            anchors.fill: parent
            sourceComponent: Config.lock.useWallpaper ? wallpaperBackground : screencopyBackground
        }
    }

    Component {
        id: screencopyBackground

        ScreencopyView {
            captureSource: root.screen
        }
    }

    Component {
        id: wallpaperBackground

        Item {
            Image {
                anchors.fill: parent
                source: {
                    const p = LiveStartFrame.frame || Wallpapers.current;
                    return p ? `file://${p}` : "";
                }
                fillMode: Image.PreserveAspectCrop
                asynchronous: false
                cache: false
            }

            Visual {
                anchors.fill: parent
                source: LiveStartFrame.frame || Wallpapers.current
                playing: PersistentState.wallpaperPlaying
                animate: false
            }
        }
    }

    Item {
        id: lockContent

        anchors.centerIn: parent
        implicitWidth: (root.screen?.height ?? 0) * Tokens.sizes.lock.heightMult * Tokens.sizes.lock.ratio
        implicitHeight: (root.screen?.height ?? 0) * Tokens.sizes.lock.heightMult

        visible: Config.lock.enabled
        rotation: 0
        scale: 0.96
        opacity: 0

        StyledRect {
            id: lockBg

            anchors.fill: parent
            color: Colours.palette.m3surface
            radius: Tokens.rounding.extraLarge * 1.5
            opacity: Colours.transparency.enabled ? Colours.transparency.base : 1

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                blurMax: 15
                shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.7)
            }
        }

        MaterialIcon {
            id: lockIcon

            visible: false
        }

        Content {
            id: content

            anchors.centerIn: parent
            width: (root.screen?.height ?? 0) * Tokens.sizes.lock.heightMult * Tokens.sizes.lock.ratio - Tokens.padding.extraLargeIncreased
            height: (root.screen?.height ?? 0) * Tokens.sizes.lock.heightMult - Tokens.padding.extraLargeIncreased

            lock: root
            opacity: 1
            scale: 1
        }
    }
}
