import QtQuick
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.launcher.services

Item {
    id: root

    required property DesktopEntry modelData
    required property ScreenState screenState

    implicitHeight: Tokens.sizes.launcher.itemHeight

    anchors.left: parent?.left
    anchors.right: parent?.right

    StateLayer {
        radius: Tokens.rounding.large
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.RightButton) {
                appMenu.items = [addToDesktopItem, TaskbarApps.pinned.includes(root.modelData.id) ? unpinItem : pinItem];
                appMenu.expanded = true;
                return;
            }
            Apps.launch(root.modelData);
            root.screenState.launcher = false;
        }
    }

    // Right-click menu
    Menu {
        id: appMenu

        attachTo: root
        attachSideX: Menu.Right
        attachSideY: Menu.Top
        thisSideX: Menu.Right
        thisSideY: Menu.Top
        marginX: -Tokens.padding.medium
        active: null
    }

    MenuItem {
        id: addToDesktopItem

        text: qsTr("Add to desktop")
        icon: "add_to_home_screen"
        onClicked: DesktopFiles.addApp(root.modelData)
    }

    MenuItem {
        id: pinItem

        text: qsTr("Pin to taskbar")
        icon: "keep"
        onClicked: TaskbarApps.pin(root.modelData.id)
    }

    MenuItem {
        id: unpinItem

        text: qsTr("Unpin from taskbar")
        icon: "keep_off"
        onClicked: TaskbarApps.unpin(root.modelData.id)
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: Tokens.padding.medium
        anchors.rightMargin: Tokens.padding.medium
        anchors.margins: Tokens.padding.small

        IconImage {
            id: icon

            asynchronous: true
            source: Quickshell.iconPath(root.modelData?.icon, "image-missing")
            implicitSize: parent.height * 0.8

            anchors.verticalCenter: parent.verticalCenter
        }

        Item {
            anchors.left: icon.right
            anchors.leftMargin: Tokens.spacing.medium
            anchors.verticalCenter: icon.verticalCenter

            implicitWidth: parent.width - icon.width - favouriteIcon.width
            implicitHeight: name.implicitHeight + comment.implicitHeight

            StyledText {
                id: name

                text: root.modelData?.name ?? ""
                font: Tokens.font.body.medium
            }

            StyledText {
                id: comment

                text: (root.modelData?.comment || root.modelData?.genericName || root.modelData?.name) ?? ""
                font: Tokens.font.body.small
                color: Colours.palette.m3outline

                elide: Text.ElideRight
                width: root.width - icon.width - favouriteIcon.width - Tokens.rounding.extraLargeIncreased

                anchors.top: name.bottom
            }
        }

        Loader {
            id: favouriteIcon

            asynchronous: true
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            active: root.modelData && Strings.testRegexList(GlobalConfig.launcher.favouriteApps, root.modelData.id)

            sourceComponent: MaterialIcon {
                text: "favorite"
                fill: 1
                color: Colours.palette.m3primary
            }
        }
    }
}
