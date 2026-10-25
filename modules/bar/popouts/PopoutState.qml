import QtQuick

QtObject {
    property string currentName
    property bool hasCurrent
    // The taskbar app under the pointer ("taskbar" popout): its workspace and key.
    property int taskbarWs
    property string taskbarKey

    signal detachRequested(mode: string)
}
