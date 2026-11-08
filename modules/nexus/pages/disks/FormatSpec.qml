import QtQuick

// The choices of FormatOptions, kept by the dialog that shows them.
QtObject {
    property string fstype: "ext4"
    property string label
    property bool encrypt
    property string passphrase
    property string repeat
    property bool erase

    readonly property bool encrypting: encrypt && fstype !== "swap" && fstype !== "empty"
    readonly property bool valid: !encrypting || (passphrase.length > 0 && passphrase === repeat)

    // Arguments for caelestia-disks after the type and label
    readonly property list<string> flags: [...(encrypting ? ["--encrypt"] : []), ...(erase ? ["--erase"] : [])]

    function reset(type: string): void {
        fstype = type || "ext4";
        label = "";
        encrypt = false;
        passphrase = "";
        repeat = "";
        erase = false;
    }
}
