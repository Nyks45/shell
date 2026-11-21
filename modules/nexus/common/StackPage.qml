import QtQuick
import QtQuick.Controls
import Caelestia.Config
import qs.components
import qs.modules.nexus

StackView {
    id: root

    required property NexusState nState
    default property list<Component> pages
    property var pageSpecs: []
    readonly property int animMovement: Tokens.padding.extraExtraLarge * 2
    property bool _booting: true
    property bool initialReady: false

    Component {
        id: pageSlot

        Loader {
            id: slot

            required property url pageUrl
            required property var pageProps
            required property int slotDepth
            required property bool loadNow
            required property bool isInitialTop

            readonly property int nexusStackDepth: slotDepth
            property bool _started: false
            readonly property bool shouldLoad: loadNow || (!root._booting && (StackView.status === StackView.Activating || StackView.status === StackView.Active || StackView.visible))

            function ensureLoad(): void {
                if (_started || !shouldLoad)
                    return;
                _started = true;
                setSource(pageUrl, Object.assign({
                    nState: root.nState
                }, pageProps ?? {}));
                if (isInitialTop && (status === Loader.Ready || status === Loader.Error))
                    root.initialReady = true;
            }

            asynchronous: true
            onShouldLoadChanged: ensureLoad()
            Component.onCompleted: ensureLoad()
            onStatusChanged: {
                if (status === Loader.Error)
                    console.warn(logCat, "Failed to load sub-page", pageUrl);
                if (isInitialTop && (status === Loader.Ready || status === Loader.Error))
                    root.initialReady = true;
            }
        }
    }

    function openSubPage(idx: int, immediate: bool, loadNow = true, isInitialTop = false): void {
        const page = pages[idx];
        if (page) {
            push(page, {
                nState
            }, immediate ? StackView.Immediate : StackView.PushTransition);
            if (isInitialTop)
                root.initialReady = true;
            return;
        }
        const spec = pageSpecs[idx];
        if (spec) {
            const relPath = Array.isArray(spec) ? spec[0] : spec;
            const extraProps = Array.isArray(spec) ? spec[1] : null;
            push(pageSlot, {
                pageUrl: PageCompRegistry.pageUrl(relPath),
                pageProps: extraProps,
                slotDepth: root.depth,
                loadNow: loadNow,
                isInitialTop: isInitialTop
            }, immediate ? StackView.Immediate : StackView.PushTransition);
            return;
        }
        if (isInitialTop)
            root.initialReady = true;
        console.warn(logCat, "Attempted to open invalid sub-page index", idx);
        nState.closeSubPage();
    }

    clip: busy

    Component.onCompleted: {
        const stack = Array.from(nState.subPageIdxStack);
        openSubPage(0, true, stack.length === 0, stack.length === 0);
        for (let i = 0; i < stack.length; i++)
            openSubPage(stack[i], true, i === stack.length - 1, i === stack.length - 1);
        _booting = false;
    }

    pushEnter: Transition {
        SequentialAnimation {
            PropertyAction {
                property: "opacity"
                value: 0
            }
            PropertyAction {
                property: "x"
                value: root.animMovement
            }
            PauseAnimation {
                duration: Tokens.anim.durations.expressiveFastEffects
            }
            ParallelAnimation {
                Anim {
                    property: "opacity"
                    to: 1
                    type: Anim.DefaultEffects
                }
                Anim {
                    property: "x"
                    from: root.animMovement
                    to: 0
                    type: Anim.FastSpatial
                }
            }
        }
    }

    pushExit: Transition {
        Anim {
            property: "opacity"
            to: 0
            type: Anim.DefaultEffects
        }
    }

    popEnter: Transition {
        SequentialAnimation {
            PropertyAction {
                property: "opacity"
                value: 0
            }
            PropertyAction {
                property: "x"
                value: -root.animMovement
            }
            PauseAnimation {
                duration: Tokens.anim.durations.expressiveFastEffects
            }
            ParallelAnimation {
                Anim {
                    property: "opacity"
                    to: 1
                    type: Anim.DefaultEffects
                }
                Anim {
                    property: "x"
                    from: -root.animMovement
                    to: 0
                    type: Anim.FastSpatial
                }
            }
        }
    }

    popExit: Transition {
        Anim {
            property: "opacity"
            to: 0
            type: Anim.DefaultEffects
        }
    }

    LoggingCategory {
        id: logCat

        name: "caelestia.nexus"
        defaultLogLevel: LoggingCategory.Info
    }

    Connections {
        function onSubPageOpened(idx: int): void {
            root.openSubPage(idx, false);
        }

        function onSubPageClosed(): void {
            if (root.depth < root.nState.subPageIdxStack.length) {
                console.log(logCat, "Attempted to close page while depth < stack depth. Ignoring.");
                return;
            }
            root.pop();
        }

        target: root.nState
    }
}
