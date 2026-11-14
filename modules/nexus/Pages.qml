import QtQuick
import Caelestia.Config
import qs.components
import qs.modules.nexus

Item {
    id: root

    required property NexusState nState

    property int lastPageIdx
    property int animOff
    property bool animateNextAttach
    property Item currentItem

    // Each load's number: pages are created asynchronously, and switching
    // quickly started several; one that finished after a newer one was asked
    // for attached too, and the pages piled up over each other
    property int loadToken

    function loadPage(idx: int): void {
        const token = ++loadToken;
        if (currentItem) {
            currentItem.destroy();
            currentItem = null;
        }

        const pageSpecs = PageCompRegistry.specs[idx];
        const comp = pageSpecs ? PageCompRegistry.stackPageComp : PageCompRegistry.placeholderComp;
        const incubator = comp.incubateObject(container, pageSpecs ? {
            nState,
            pageSpecs
        } : {
            nState
        });

        const attach = () => {
            // A newer page was asked for meanwhile: this one is stale
            if (token !== root.loadToken) {
                incubator.object.destroy();
                return;
            }
            incubator.object.anchors.fill = container;
            currentItem = incubator.object;
            if (root.animateNextAttach) {
                root.animateNextAttach = false;
                fadeInAnim.restart();
            } else {
                container.opacity = 1;
                container.anchors.topMargin = 0;
                container.anchors.bottomMargin = 0;
            }
        };

        if (incubator.status === Component.Ready)
            attach();
        else
            incubator.onStatusChanged = status => {
                if (status === Component.Ready)
                    attach();
            };
    }

    Item {
        id: container

        objectName: "PageContainer"
        anchors.fill: parent
        layer.enabled: opacity < 1
        Component.onCompleted: {
            root.lastPageIdx = root.nState.currentPageIdx;
            root.loadPage(root.nState.currentPageIdx);
        }
    }

    Connections {
        function onCurrentPageIdxChanged(): void {
            fadeOutAnim.stop();
            fadeInAnim.stop();
            root.animateNextAttach = false;
            root.animOff = root.Tokens.padding.extraLarge * (root.nState.currentPageIdx > root.lastPageIdx ? 1 : -1);
            root.lastPageIdx = root.nState.currentPageIdx;
            fadeOutAnim.start();
        }

        target: root.nState
    }

    SequentialAnimation {
        id: fadeOutAnim

        Anim {
            target: container
            property: "opacity"
            to: 0
            type: Anim.DefaultEffects
        }
        ScriptAction {
            script: {
                root.animateNextAttach = true;
                root.loadPage(root.nState.currentPageIdx);
            }
        }
    }

    SequentialAnimation {
        id: fadeInAnim

        PropertyAction {
            target: container.anchors
            property: "topMargin"
            value: root.animOff
        }
        PropertyAction {
            target: container.anchors
            property: "bottomMargin"
            value: -root.animOff
        }
        ParallelAnimation {
            Anim {
                target: container
                property: "opacity"
                from: 0
                to: 1
                type: Anim.DefaultEffects
            }
            Anim {
                target: container.anchors
                properties: "topMargin,bottomMargin"
                to: 0
                type: Anim.DefaultSpatial
            }
        }
    }
}
