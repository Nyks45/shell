pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import qs.modules.nexus.common

// AUR recipe (PKGBUILD) review modal: fetches package metadata and the
// raw PKGBUILD before building/installing or updating any AUR package.
DialogRowButton {
    id: root

    property var pkgItem: null
    property var info: null
    property bool loading
    property string error
    property string actionText: Tr.tr("Build & install")
    property bool readOnly
    property var acceptCallback: null

    function openFor(item: var, label: string, callback: var): void {
        pkgItem = item;
        readOnly = typeof callback !== "function";
        acceptCallback = readOnly ? null : callback;
        actionText = label || (readOnly ? Tr.trCtx("Close", "button") : Tr.tr("Build & install"));
        fetch();
        open = true;
    }

    function fetch(): void {
        if (!pkgItem?.name)
            return;
        info = null;
        error = "";
        loading = true;
        pkgbuildProc.running = false;
        pkgbuildProc.command = [Packages.helper, "pkgbuild", pkgItem.name];
        pkgbuildProc.running = true;
    }

    visible: false
    openWidth: Math.min(rootParent.width * 0.9, 680)
    openHeight: Math.min(rootParent.height * 0.88, 640)
    separateContent: true
    showCancel: !readOnly
    icon: "security"
    label: ""
    header: pkgItem?.name ? Tr.tr("Review AUR recipe: %1").arg(pkgItem.name) : Tr.tr("Review AUR recipe")
    acceptLabel: actionText
    acceptAllowed: readOnly || (!loading && !error && !!(info?.pkgbuild))

    onOpenChanged: if (!open) {
        pkgbuildProc.running = false;
        loading = false;
        acceptCallback = null;
    }

    onAccepted: {
        if (!readOnly && typeof acceptCallback === "function")
            acceptCallback();
    }

    Process {
        id: pkgbuildProc

        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                try {
                    const parsed = JSON.parse(text);
                    root.info = parsed;
                    root.error = parsed.error ?? "";
                } catch (e) {
                    root.error = Tr.tr("Couldn't read the PKGBUILD response.");
                }
            }
        }
        onExited: code => {
            if (code !== 0 && root.loading) {
                root.loading = false;
                root.error = Tr.tr("Couldn't load the PKGBUILD.");
            }
        }
    }

    content: Component {
        ColumnLayout {
            spacing: Tokens.spacing.small

            readonly property bool riskyMeta: !!(root.info && (!root.info.maintainer || root.info.outOfDate))

            StyledRect {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.small
                implicitHeight: warnLayout.implicitHeight + Tokens.padding.medium * 2
                radius: Tokens.rounding.medium
                color: riskyMeta ? Colours.palette.m3errorContainer : Colours.tPalette.m3surfaceContainerHigh

                RowLayout {
                    id: warnLayout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: riskyMeta ? "warning" : "info"
                        color: riskyMeta ? Colours.palette.m3onErrorContainer : Colours.palette.m3primary
                        fontStyle: Tokens.font.icon.medium
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: {
                            const base = Tr.tr("Community package (AUR) — built on this computer from a user-submitted recipe, not vetted by Arch.");
                            if (!root.info)
                                return base;
                            const notes = [];
                            if (!root.info.maintainer)
                                notes.push(Tr.tr("Currently unmaintained (orphan)."));
                            if (root.info.outOfDate)
                                notes.push(Tr.tr("Flagged out of date."));
                            return notes.length ? `${base} ${notes.join(" ")}` : base;
                        }
                        color: riskyMeta ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSurface
                        font: Tokens.font.label.small
                        wrapMode: Text.WordWrap
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: !!root.info
                spacing: Tokens.spacing.medium

                StyledText {
                    Layout.fillWidth: true
                    readonly property string maint: root.info?.maintainer || Tr.tr("None (orphan)")
                    readonly property string updated: root.info?.lastModified ? Qt.formatDate(new Date(root.info.lastModified * 1000), "d MMM yyyy") : Tr.tr("Unknown")
                    text: Tr.tr("Maintainer: %1 · Votes: %2 · Updated: %3").arg(maint).arg(root.info?.votes ?? 0).arg(updated)
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                    wrapMode: Text.WordWrap
                }

                TextButton {
                    text: Tr.tr("Open on AUR")
                    type: TextButton.Text
                    onClicked: Qt.openUrlExternally(root.info?.aurPage || `https://aur.archlinux.org/packages/${encodeURIComponent(root.pkgItem?.name ?? "")}`)
                }
            }

            StyledRect {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.bottomMargin: Tokens.spacing.small
                radius: Tokens.rounding.medium
                color: Colours.palette.m3surfaceContainer
                clip: true

                StyledFlickable {
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    clip: true
                    visible: !root.loading && !root.error
                    contentHeight: pkgText.implicitHeight
                    contentWidth: width

                    StyledText {
                        id: pkgText

                        width: parent.width
                        text: root.info ? ((root.info.pkgbuild || "") + (root.info.truncated ? "\n… " + Tr.tr("(PKGBUILD truncated — open on AUR to see all)") : "")) : ""
                        font: Tokens.font.mono.small
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - Tokens.padding.extraLarge * 2
                    visible: root.loading || !!root.error
                    spacing: Tokens.spacing.small

                    LoadingIndicator {
                        Layout.alignment: Qt.AlignHCenter
                        visible: root.loading
                    }

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: root.loading ? Tr.tr("Fetching PKGBUILD from AUR…") : root.error
                        color: root.error ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        wrapMode: Text.WordWrap
                    }

                    TextButton {
                        Layout.alignment: Qt.AlignHCenter
                        visible: !root.loading && !!root.error
                        text: Tr.tr("Retry")
                        type: TextButton.Tonal
                        onClicked: root.fetch()
                    }
                }
            }
        }
    }
}
