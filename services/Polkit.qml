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
// Only one agent can serve a session: when another one is already registered
// (polkit-gnome from an old autostart), that one keeps working. When none can
// be (the shell's failed), polkit-gnome is started as a fallback so password
// requests never go unanswered.
Singleton {
    id: root

    readonly property alias agent: agent
    // agent.flow, or the sandbox's simulated request (see demo below)
    readonly property var flow: demo ?? agent.flow
    readonly property bool active: (agent.isActive && !!agent.flow) || !!demo
    readonly property bool registered: agent.isRegistered

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

    PolkitAgent {
        id: agent

        onAuthenticationRequestStarted: root.pickHost()
        onFlowChanged: if (flow && !root.decided)
            root.pickHost()
        onIsActiveChanged: {
            if (!isActive)
                root.ended();
        }
    }

    function pickHost(): void {
        host = hosts.find(h => h.windowActive) ?? null;
        decided = true;
    }

    function ended(): void {
        decided = false;
        host = null;
        context = "";
    }

    // Test sessions only (CAELESTIA_POLKIT_DEMO=1, set by the dev sandbox,
    // which can't be the session's agent while the real one is): a simulated
    // request, `qs ipc call polkit demo ACTION_ID`; the password "demo" is
    // accepted, anything else fails once.
    property QtObject demo: null

    IpcHandler {
        function demo(actionId: string): void {
            if (Quickshell.env("CAELESTIA_POLKIT_DEMO") !== "1" || root.demo)
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
        }
    }

    // Fallback agent (see above): once, if the shell's isn't registered
    Timer {
        running: true
        interval: 4000
        onTriggered: if (!agent.isRegistered)
            fallbackCheck.running = true
    }

    Process {
        id: fallbackCheck

        command: ["sh", "-c", "pgrep -x polkit-gnome-au >/dev/null || pgrep -f '^/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1$' >/dev/null || { [ -x /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 ] && setsid -f /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 >/dev/null 2>&1; echo started; }"]
        stdout: StdioCollector {
            onStreamFinished: if (text.includes("started"))
                console.warn("Polkit: the shell's agent isn't registered; started polkit-gnome instead")
        }
    }
}
