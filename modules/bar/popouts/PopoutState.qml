import QtQuick

QtObject {
    property string currentName
    property bool hasCurrent
    // The taskbar window under the pointer ("taskbar" popout).
    property var taskbarToplevel

    signal detachRequested(mode: string)
}
