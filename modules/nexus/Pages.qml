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
    property bool initialized: false

    // Each load's number: pages are created asynchronously, and switching
    // quickly started several; one that finished after a newer one was asked
    // for attached too, and the pages piled up over each other
    property int loadToken

    function start(): void {
        fadeOutAnim.stop();
        fadeInAnim.stop();
        animateNextAttach = false;
        lastPageIdx = nState.currentPageIdx;
        initialized = true;
        loadPage(nState.currentPageIdx);
    }

    function clear(): void {
        initialized = false;
        loadToken++;
        fadeOutAnim.stop();
        fadeInAnim.stop();
        animateNextAttach = false;
        if (currentItem) {
            currentItem.destroy();
            currentItem = null;
        }
    }

    function loadPage(idx: int): void {
        const token = ++loadToken;
        if (currentItem) {
            currentItem.destroy();
            currentItem = null;
        }

        const pageSpecs = PageCompRegistry.specs[idx];
        const comp = pageSpecs ? PageCompRegistry.stackPageComp : PageCompRegistry.placeholderComp;
        const item = comp.createObject(container, pageSpecs ? {
            nState,
            pageSpecs
        } : {
            nState
        });
        item.anchors.fill = container;
        currentItem = item;

        const reveal = () => {
            if (token !== root.loadToken)
                return;
            if (root.animateNextAttach) {
                root.animateNextAttach = false;
                fadeInAnim.restart();
            } else {
                container.opacity = 1;
                container.anchors.topMargin = 0;
                container.anchors.bottomMargin = 0;
            }
        };

        if (!pageSpecs || item.initialReady || !root.animateNextAttach) {
            reveal();
        } else {
            const onReady = () => {
                if (item && item.initialReady) {
                    item.initialReadyChanged.disconnect(onReady);
                    reveal();
                }
            };
            item.initialReadyChanged.connect(onReady);
        }
    }

    Item {
        id: container

        objectName: "PageContainer"
        anchors.fill: parent
        layer.enabled: opacity < 1
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

        enabled: root.initialized
        target: root.nState
    }

    SequentialAnimation {
        id: fadeOutAnim

        Anim {
            target: container
            property: "opacity"
            to: 0
            type: Anim.FastEffects
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
