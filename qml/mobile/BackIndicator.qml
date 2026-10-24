import QtQuick

// The back swipe's bubble, as an Android phone draws it: a rounded bubble
// with a chevron at the finger's height, coming in from the edge the finger
// started at, growing and moving inward with it, and stretching a little past
// the threshold. Past the threshold its chevron firms up; let go there, it
// goes on inward a little and fades, and let go short it shrinks back into
// the edge. The policy (policy.lua, back_show) hands `back` over: where the
// finger is, how far it has pulled, the threshold, and how it ended.
Item {
    id: root
    // { serial, active, outcome ("back", "cancel" or ""), side, y, pull, commit }
    property var back: ({})

    // What is drawn: the finger's while it is down, then the way out.
    property int serial: 0
    property string side: "left"
    property real pull: 0
    property real fingerY: 0
    property real fade: 0
    property bool committed: false
    property real commit: 130

    onBackChanged: {
        if (!back || !back.serial) return
        if (back.active) {
            leave.stop()
            serial = back.serial
            side = back.side === "right" ? "right" : "left"
            commit = Math.max(1, back.commit || 130)
            committed = false
            pull = Math.max(0, back.pull || 0)
            fingerY = back.y || 0
            fade = 1
        } else if (back.serial === serial && fade > 0) {
            committed = back.outcome === "back"
            pullOut.to = committed ? pull + 18 : 0
            pullOut.duration = fadeOut.duration = committed ? 160 : 220
            leave.restart()
        }
    }
    ParallelAnimation {
        id: leave
        NumberAnimation { id: pullOut; target: root; property: "pull"; easing.type: Easing.OutCubic }
        NumberAnimation { id: fadeOut; target: root; property: "fade"; to: 0; easing.type: Easing.InQuad }
    }

    // `grow` is 0 at the edge to 1 at the threshold; `over` the pixels past
    // it, rubber-banded into `stretch`.
    readonly property real grow: Math.min(1, pull / commit)
    readonly property real over: Math.max(0, pull - commit)
    readonly property real stretch: 1 - 1 / (1 + over / 90)
    readonly property bool armed: committed || pull >= commit

    Rectangle {
        id: bubble
        readonly property real inset: -width * (1 - root.grow) * 0.5 + 10 * root.grow + 0.12 * root.over
        width: 12 + 36 * root.grow + 30 * root.stretch
        height: (44 + 12 * root.grow) * (1 - 0.08 * root.stretch)
        radius: height / 2
        x: root.side === "left" ? inset : root.width - inset - width
        y: Math.max(0, Math.min(root.height - height, root.fingerY - height / 2))
        color: "#e01c1c1f"
        border { width: 1; color: "#55ffffff" }
        opacity: root.fade * Math.min(1, root.pull / 20)
        visible: opacity > 0.001

        Glyph {
            anchors.centerIn: parent
            // Drawn pointing left; mirrored on the right edge, so it points
            // at the edge it came from.
            transform: Scale { origin.x: 10; xScale: root.side === "left" ? 1 : -1 }
            width: 20; height: 20
            name: "chevron"
            stroke: root.armed ? 2.8 : 2.2
            opacity: root.armed ? 1 : 0.5
            scale: root.armed ? 1 : 0.82
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
        }
    }
}
