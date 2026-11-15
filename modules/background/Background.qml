pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services

Variants {
    model: Screens.screens.filter(s => GlobalConfig.forScreen(s.name).background.enabled)

    StyledWindow {
        id: win

        required property ShellScreen modelData

        screen: modelData
        name: "background"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        // Clicking the desktop gives it the keyboard (Delete, Enter on icons)
        WlrLayershell.keyboardFocus: contentItem.Config.background.desktopIcons ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        WlrLayershell.layer: contentItem.Config.background.wallpaperEnabled ? WlrLayer.Background : WlrLayer.Bottom
        color: contentItem.Config.background.wallpaperEnabled ? "black" : "transparent"
        surfaceFormat.opaque: false

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        ShellState.ComponentRef {
            screen: win.screen
            slot: "background"
            component: win
        }

        Item {
            id: behindClock

            anchors.fill: parent

            // The live wallpaper's last frame while its renderer loads (after
            // the shell starts it: LiveStartFrame), faded out once it draws
            Image {
                anchors.fill: parent
                visible: opacity > 0 && status === Image.Ready
                opacity: LiveStartFrame.showing ? 1 : 0
                source: LiveStartFrame.frame && (LiveStartFrame.showing || opacity > 0) ? `file://${LiveStartFrame.frame}` : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: false
                cache: false
                sourceSize.width: win.screen?.width ?? 2560

                Behavior on opacity {
                    enabled: !LiveStartFrame.showing && !LiveStartFrame.wasRunning

                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutQuad
                    }
                }
            }

            Loader {
                id: wallpaper

                asynchronous: true

                anchors.fill: parent
                active: Config.background.wallpaperEnabled

                source: active ? Qt.resolvedUrl("Wallpaper.qml") : ""
            }

            Loader {
                anchors.fill: parent
                asynchronous: true
                active: Config.background.visualiser.enabled
                onActiveChanged: {
                    if (active && !source.toString())
                        setSource(Qt.resolvedUrl("Visualiser.qml"), {
                            screen: Qt.binding(() => win.modelData),
                            wallpaper: wallpaper
                        });
                }
                Component.onCompleted: {
                    if (active)
                        setSource(Qt.resolvedUrl("Visualiser.qml"), {
                            screen: Qt.binding(() => win.modelData),
                            wallpaper: wallpaper
                        });
                }
            }
        }

        // What's in the desktop folder, near the screen's corner like Windows'
        // (clear of the bar only when it's always shown)
        Loader {
            anchors.fill: parent
            anchors.margins: Tokens.padding.small + Config.border.thickness
            anchors.leftMargin: (Config.bar.persistent ? Tokens.sizes.bar.innerWidth + Tokens.padding.large : Tokens.padding.small) + Config.border.thickness

            asynchronous: true
            active: Config.background.desktopIcons

            source: active ? Qt.resolvedUrl("DesktopIcons.qml") : ""
        }
    }
}
