import QtQuick

// The gesture bar, as on an iPhone or an Android phone: a short rounded pill
// at the bottom centre of an application's window, a few pixels above its
// edge, showing where the swipe up starts. Light with a faint dark outline,
// so it reads on light and dark applications alike. The policy hands over
// `mobileBar`, 1 shown to 0 gone (Recents, the home screen, and the first
// part of the swipe up, which fades it with the finger), and
// `mobileBarWidth`, its length (config.lua, `bar`).
Item {
    id: frame
    property var values: ({})
    readonly property real level: Math.max(0, Math.min(1, values.mobileBar || 0))
    readonly property real length: Math.min(values.mobileBarWidth || 134, width * 0.4)

    // What is drawn. Going down it follows the finger at once; coming back
    // from nothing (out of Recents, a swipe let go short) it fades in once
    // the window is most of the way back.
    // A layer just built (a new window, or the style changed under the
    // window, as when the swipe up starts) takes the policy's value as it is,
    // which can come a moment after the layer: it was already on screen.
    property real shown: 0
    property bool fresh: true
    Component.onCompleted: shown = level
    Timer { interval: 250; running: true; onTriggered: frame.fresh = false }
    onLevelChanged: {
        if (fresh || level <= shown || shown > 0.001) { fadeIn.stop(); shown = level; return }
        fadeTo.to = level
        fadeIn.restart()
    }
    SequentialAnimation {
        id: fadeIn
        PauseAnimation { duration: 160 }
        NumberAnimation { id: fadeTo; target: frame; property: "shown"; duration: 200; easing.type: Easing.OutCubic }
    }
    property bool dormant: shown <= 0.001 && !fadeIn.running && !fresh

    Rectangle {
        id: outline
        width: frame.length + 2; height: 7; radius: height / 2
        x: (frame.width - width) / 2
        y: frame.height - height - 7
        color: "#80000000"
        opacity: frame.shown
        visible: opacity > 0.001
        Rectangle {
            anchors { fill: parent; margins: 1 }
            radius: height / 2
            color: "#e6ffffff"
        }
    }
}
