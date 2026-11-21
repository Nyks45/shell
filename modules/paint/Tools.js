.pragma library

// Paint's tools: id, Material icon, one-key shortcut, group (for the rail's separators)
var list = [
    { id: "select", icon: "arrow_selector_tool", key: "V", group: 0 },
    { id: "area", icon: "select", key: "M", group: 0 },
    { id: "crop", icon: "crop", key: "C", group: 0 },
    { id: "pen", icon: "draw", key: "P", group: 1 },
    { id: "highlighter", icon: "ink_highlighter", key: "H", group: 1 },
    { id: "eraser", icon: "ink_eraser", key: "X", group: 1 },
    { id: "line", icon: "pen_size_2", key: "L", group: 2 },
    { id: "arrow", icon: "arrow_right_alt", key: "A", group: 2 },
    { id: "rect", icon: "rectangle", key: "R", group: 2 },
    { id: "ellipse", icon: "circle", key: "E", group: 2 },
    { id: "text", icon: "title", key: "T", group: 3 },
    { id: "callout", icon: "chat_bubble", key: "U", group: 3 },
    { id: "step", icon: "counter_1", key: "N", group: 3 },
    { id: "redact", icon: "blur_on", key: "B", group: 4 },
    { id: "spotlight", icon: "highlight", key: "S", group: 4 },
    { id: "magnifier", icon: "zoom_in", key: "G", group: 4 },
    { id: "eyedropper", icon: "colorize", key: "I", group: 5 }
];

// What each tool does, for tooltips and the status bar (translated by the caller)
var names = {
    select: "Select and move",
    area: "Select an area",
    crop: "Crop",
    pen: "Pen",
    highlighter: "Highlighter",
    eraser: "Eraser",
    line: "Line",
    arrow: "Arrow",
    rect: "Rectangle",
    ellipse: "Ellipse",
    text: "Text",
    callout: "Callout",
    step: "Numbered step",
    redact: "Blur / pixelate",
    spotlight: "Spotlight",
    magnifier: "Magnifier",
    eyedropper: "Pick a colour",
    hand: "Move the view"
};

var hints = {
    select: "Click: select · drag: move · Shift: add · double-click: edit text",
    area: "Drag to select · drag it to move · Del clears · Ctrl+C copies",
    crop: "Drag the frame or its handles · Enter applies · Esc cancels",
    pen: "Drag to draw · right button: second colour",
    highlighter: "Drag to highlight",
    eraser: "Drag over objects to remove them",
    line: "Drag to draw · Shift: straight",
    arrow: "Drag to draw · Shift: straight",
    rect: "Drag to draw · Shift: square",
    ellipse: "Drag to draw · Shift: circle",
    text: "Click to type · Enter: new line · Esc or click outside: done",
    callout: "Drag a bubble, then type · drag the dot to point it",
    step: "Click to place the next number",
    redact: "Drag over what should be hidden",
    spotlight: "Drag around what matters · the rest is dimmed",
    magnifier: "Drag from the centre outwards",
    eyedropper: "Click to take a colour · right button: second colour",
    hand: "Drag to move the view"
};
