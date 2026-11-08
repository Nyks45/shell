pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit

// The shell is the session's polkit agent: every password request (the
// settings' own changes, udisks, systemctl, pkexec from anywhere) is asked by
// the shell, in the settings' style. A settings window that has focus shows
// it inside itself (it is usually what asked); otherwise a card over the
// screen does (PolkitOverlay).
//
// It is the only agent (no polkit-gnome): if registering fails (another
// agent still held the session for a moment), a fresh agent tries again every
// few seconds until it is the session's agent.
Singleton {
    id: root

    // The agent (made again until it registers, see above)
    property PolkitAgent agent: null
    // The agent's request, or the sandbox's simulated one (see demo below)
    readonly property var flow: demo ?? agent?.flow ?? null
    readonly property bool active: (!!agent?.isActive && !!agent?.flow) || !!demo
    readonly property bool registered: agent?.isRegistered ?? false

    // The settings' own helper (named actions): its prompt says what for
    readonly property bool ours: !!flow && flow.actionId === "org.caelestia.shell.admin"
    // What the settings are about to do, set by Admin just before it asks
    property string context

    // Settings windows able to show the prompt (Nexus registers itself, with
    // a windowActive property); the one with focus when a request starts
    // keeps it until it ends
    property list<Item> hosts: []
    property Item host: null
    // The host is chosen for the current request (until then neither the
    // overlay nor a window shows it, so it never flashes in the wrong place)
    property bool decided

    // Test sessions only (CAELESTIA_POLKIT_DEMO=1, set by the dev sandbox,
    // which can't be the session's agent while the real one is): a simulated
    // request, `qs ipc call polkit demo ACTION_ID`; the password "demo" is
    // accepted, anything else fails once.
    property QtObject demo: null
    readonly property bool testSession: Quickshell.env("CAELESTIA_POLKIT_DEMO") === "1"

    function addHost(item: Item): void {
        if (!hosts.includes(item))
            hosts.push(item);
    }

    function removeHost(item: Item): void {
        const i = hosts.indexOf(item);
        if (i >= 0)
            hosts.splice(i, 1);
        if (host === item)
            host = null;
    }

    function submit(password: string): void {
        if (flow && flow.isResponseRequired)
            flow.submit(password);
    }

    function cancel(): void {
        if (flow)
            flow.cancelAuthenticationRequest();
    }

    function pickHost(): void {
        host = hosts.find(h => h.windowActive) ?? null;
        decided = true;
    }

    function makeAgent(): void {
        if (agent)
            agent.destroy();
        agent = agentComp.createObject(root);
    }

    function ended(): void {
        decided = false;
        host = null;
        context = "";
    }

    Component.onCompleted: makeAgent()

    Component {
        id: agentComp

        PolkitAgent {
            onAuthenticationRequestStarted: root.pickHost()
            onFlowChanged: if (flow && !root.decided)
                root.pickHost()
            onIsActiveChanged: {
                if (!isActive)
                    root.ended();
            }
        }
    }

    // Not registered: a fresh agent tries again (not in test sessions: the dev
    // sandbox shares the real session, whose agent is the live shell)
    Timer {
        running: !root.registered && !root.testSession
        interval: 5000
        repeat: true
        onTriggered: {
            console.warn("Polkit: not the session's agent yet; trying again");
            root.makeAgent();
        }
    }

    IpcHandler {
        function demo(actionId: string): void {
            if (!root.testSession || root.demo)
                return;
            root.pickHost();
            root.demo = demoComp.createObject(root, {
                actionId
            });
        }

        target: "polkit"
    }

    Component {
        id: demoComp

        QtObject {
            id: d

            property string actionId
            readonly property string message: "Authentication is required to run a test as the super user"
            property string inputPrompt: "Password: "
            property bool isResponseRequired: true
            property bool responseVisible: false
            property string supplementaryMessage
            property bool supplementaryIsError
            property bool failed

            property Timer checkTimer: Timer {
                property string value

                interval: 600
                onTriggered: {
                    if (value === "demo") {
                        console.info("Polkit demo: authorised");
                        root.demo = null;
                        root.ended();
                        d.destroy();
                        return;
                    }
                    console.info("Polkit demo: wrong password");
                    d.failed = true;
                    d.authenticationFailed();
                    d.isResponseRequired = true;
                }
            }

            signal authenticationFailed

            function submit(value: string): void {
                isResponseRequired = false;
                checkTimer.value = value;
                checkTimer.start();
            }

            function cancelAuthenticationRequest(): void {
                console.info("Polkit demo: cancelled");
                root.demo = null;
                root.ended();
                d.destroy();
            }
        }
    }
}
