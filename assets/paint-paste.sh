#!/bin/sh
# Paint's paste: what's on the clipboard, for modules/paint/PaintWindow.qml.
# $1: a folder for a pasted picture. Prints "image\n<file>", "files\n<path>...", "text\n<text>" or "none".
dir=$1
types=$(wl-paste -l 2>/dev/null) || { echo none; exit 0; }
has() { printf '%s\n' "$types" | grep -qx "$1"; }
for m in image/png image/jpeg image/webp image/bmp image/gif image/tiff; do
    if has "$m"; then
        f="$dir/paste-$(date +%s%N).${m#image/}"
        if wl-paste -n -t "$m" > "$f" 2>/dev/null && [ -s "$f" ]; then
            printf 'image\n%s\n' "$f"
            exit 0
        fi
        rm -f "$f"
    fi
done
if has text/uri-list; then
    echo files
    wl-paste -n -t text/uri-list | tr -d '\r' | grep '^file://' | while IFS= read -r u; do
        # file:// URIs, percent-decoded
        p=${u#file://}
        printf '%s\n' "$p" | sed 's/%\([0-9A-Fa-f][0-9A-Fa-f]\)/\\x\1/g' | xargs -0 printf '%b'
    done
    exit 0
fi
if has 'text/plain;charset=utf-8' || has text/plain || has UTF8_STRING || has TEXT || has STRING; then
    echo text
    wl-paste -n -t 'text/plain;charset=utf-8' 2>/dev/null || wl-paste -n
    exit 0
fi
echo none
