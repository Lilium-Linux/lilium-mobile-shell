import QtQuick
import Solium

// The Control Center: pulled down from the top-right corner, it follows the
// finger, and on release a spring carries it the rest of the way from the
// finger's own speed. Everything here is one progress, `shown`: 0 closed, 1
// open, a little past either while the spring settles. The dim, the panel and
// each module are drawn from it, and it is reported to the policy every frame
// so the blur behind (effects/cc-fade, effects/cc-blur) follows it too.
Item {
    id: root

    // From the policy (mobile/policy.lua).
    property real progress: 0          // the finger's, while `dragging`
    property bool dragging: false
    property real target: 0            // where to settle once let go: 0 or 1
    property real releaseVelocity: 0   // progress per second at the release
    property int release: 0            // moves on each release, to start the spring
    property real pace: 1              // SOLIUM_MOBILE_PACE: slower is larger
    property bool reduceMotion: false
    property int statusHeight: 32
    property bool tablet: true
    property real brightness: 1
    property real volume: 0.5
    property bool darkAppearance: false
    property bool splitActive: false
    property int taskCount: 0
    property int battery: -1           // percent, -1 for none
    property bool charging: false
    property bool wifi: false

    function send(action, data) { Solium.send("mobile.control." + action, data || {}) }

    // ---- The one progress -------------------------------------------------

    property real shown: 0
    property real speed: 0
    // A spring a little under critical: it lands with the faintest settle, as
    // the iPad's does. Its response is 0.38 s at pace 1.
    readonly property real omega: 2 * Math.PI / (0.38 * Math.max(0.25, pace))
    readonly property real zeta: 0.86

    onProgressChanged: if (dragging) { shown = progress; report() }
    onDraggingChanged: if (dragging) { spring.running = false; shown = progress }
    onReleaseChanged: {
        if (reduceMotion) { shown = target; speed = 0; report(); settled(); return }
        speed = releaseVelocity
        spring.running = true
    }

    FrameAnimation {
        id: spring
        running: false
        onTriggered: {
            const dt = Math.min(frameTime, 1 / 30)
            const accel = -root.omega * root.omega * (root.shown - root.target)
                - 2 * root.zeta * root.omega * root.speed
            root.speed += accel * dt
            root.shown += root.speed * dt
            if (Math.abs(root.shown - root.target) < 0.001 && Math.abs(root.speed) < 0.01) {
                root.shown = root.target
                root.speed = 0
                running = false
                root.report()
                root.settled()
                return
            }
            root.report()
        }
    }

    // Let go here, in the scene: the spring takes it to `to` from `velocity`.
    function settle(to, velocity) {
        target = to
        if (reduceMotion) { shown = to; speed = 0; report(); settled(); return }
        speed = velocity
        spring.running = true
    }

    // The policy blurs what is behind by the same amount.
    function report() { send("progress", { value: Math.max(0, Math.min(1, shown)) }) }
    function settled() { if (target === 0) send("closed") }

    readonly property real s: Math.max(0, shown)

    // ---- Behind the panel ---------------------------------------------------

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.32 * Math.min(1, root.s)
    }
    // Anywhere but on a control: a tap closes it, and a swipe up pushes it
    // back with the finger, the spring taking over from the finger's speed.
    MouseArea {
        id: back
        anchors.fill: parent
        enabled: root.target === 1 && !root.dragging
        property real startY: 0
        property real lastY: 0
        property real lastTime: 0
        property real velocity: 0
        property bool pushing: false
        readonly property real travel: root.height * 0.42
        onPressed: mouse => {
            startY = lastY = mouse.y; lastTime = Date.now(); velocity = 0; pushing = false
        }
        onPositionChanged: mouse => {
            const now = Date.now()
            if (now > lastTime) velocity = (mouse.y - lastY) / ((now - lastTime) / 1000) / travel
            lastY = mouse.y; lastTime = now
            if (!pushing && startY - mouse.y > 10) { pushing = true; spring.running = false }
            if (pushing) {
                root.shown = Math.max(0, Math.min(1, 1 - (startY - mouse.y) / travel))
                root.report()
            }
        }
        onReleased: {
            if (!pushing) { root.settle(0, 0); return }
            pushing = false
            root.settle(root.shown < 0.7 || velocity < -1.2 ? 0 : 1, velocity)
        }
    }

    // ---- The status, travelling with the finger -------------------------------

    // Wi-Fi and the battery leave the status bar's right end as the finger
    // pulls and land above the panel, a little larger, as the iPad's do.
    Row {
        id: statusRow
        spacing: 8
        readonly property real from: (root.statusHeight - height) / 2
        readonly property real to: panel.y - height - 16
        x: panel.x + panel.width - width
        y: from + (to - from) * root.s
        transformOrigin: Item.Right
        scale: 1 + 0.2 * Math.min(1, root.s)
        opacity: Math.min(1, root.s * 4)
        Glyph { visible: root.wifi; width: 17; height: 17; name: "wifi"; anchors.verticalCenter: parent.verticalCenter }
        Text {
            visible: root.battery >= 0
            text: root.battery + "%"; color: "white"
            font { pixelSize: 13; weight: Font.DemiBold }
            anchors.verticalCenter: parent.verticalCenter
        }
        // A battery: its outline, its charge, its terminal.
        Item {
            visible: root.battery >= 0
            width: 26; height: 13
            anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                width: 23; height: 13; radius: 3.5
                color: "transparent"; border { width: 1.2; color: "#c8ffffff" }
                Rectangle {
                    x: 2; y: 2; height: parent.height - 4; radius: 2
                    width: Math.max(1, (parent.width - 4) * root.battery / 100)
                    color: root.charging ? "#7ee08a" : (root.battery <= 20 ? "#ff6b5e" : "white")
                }
            }
            Rectangle { x: 24; y: 4.5; width: 2; height: 4; radius: 1; color: "#c8ffffff" }
        }
    }

    // ---- The panel ------------------------------------------------------------

    // Cells of `cell` with `gap` between them, four columns, anchored to the
    // top-right corner the finger pulled it from.
    readonly property real cell: tablet ? 70 : 64
    readonly property real gap: 14
    readonly property real span: 4 * cell + 3 * gap

    Item {
        id: panel
        width: root.span; height: 3 * root.cell + 2 * root.gap
        x: root.width - width - (root.tablet ? 30 : 18)
        y: root.statusHeight + 18
        transformOrigin: Item.TopRight
        scale: 0.94 + 0.06 * Math.min(1, root.s)

        // Each module appears from the corner outward: `rank` is its distance
        // from the top-right cell, in cells.
        component Module: Item {
            id: module
            property real rank: 0
            readonly property real lead: 0.07 * rank
            readonly property real t: Math.max(0, (root.shown - lead) / (1 - lead))
            opacity: Math.min(1, t)
            scale: 0.86 + 0.14 * t
            transform: Translate { y: -18 * (1 - Math.min(1, module.t)) }
        }

        // A round toggle on a module.
        component Toggle: Rectangle {
            id: toggle
            property string icon: ""
            property bool on: false
            property string label: ""
            signal triggered()
            width: root.cell * 0.82; height: width; radius: width / 2
            color: on ? "#f2f2f2" : "#38ffffff"
            Accessible.role: Accessible.Button
            Accessible.name: label
            Glyph { anchors.centerIn: parent; width: parent.width * 0.42; height: width; name: toggle.icon; color: toggle.on ? "#1b1c20" : "white" }
            scale: press.pressed ? 0.92 : 1
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            MouseArea { id: press; anchors.fill: parent; onClicked: toggle.triggered() }
        }

        // A module's tile: flat and translucent, a hairline at its edge.
        component Tile: Rectangle {
            radius: Math.min(30, height / 2)
            color: "#2effffff"
            border { width: 1; color: "#24ffffff" }
        }

        // A tall slider: drag anywhere on it, the fill follows the finger.
        component Slider: Tile {
            id: slider
            property real value: 0
            property string icon: ""
            property string label: ""
            signal moved(real value)
            radius: width / 2
            Accessible.role: Accessible.Slider
            Accessible.name: label
            // The fill: round where it meets the pill's own ends, flat across
            // its top until it reaches the pill's top.
            Rectangle {
                id: fill
                readonly property real round: slider.width / 2
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: parent.height * Math.max(0, Math.min(1, slider.value))
                color: "#f2f2f2"
                bottomLeftRadius: Math.min(round, height / 2); bottomRightRadius: bottomLeftRadius
                topLeftRadius: Math.max(0, round - (slider.height - height)); topRightRadius: topLeftRadius
            }
            Glyph {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: parent.width * 0.32 }
                width: parent.width * 0.4; height: width; name: slider.icon
                color: slider.value > 0.18 ? "#1b1c20" : "white"
            }
            MouseArea {
                anchors.fill: parent
                property real from: 0
                property real startY: 0
                onPressed: mouse => { from = slider.value; startY = mouse.y }
                onPositionChanged: mouse => slider.moved(Math.max(0, Math.min(1, from + (startY - mouse.y) / slider.height)))
            }
        }

        // Display: four toggles in one tile.
        Module {
            rank: 2
            x: 0; y: 0; width: 2 * root.cell + root.gap; height: width
            Tile {
                anchors.fill: parent
                Grid {
                    anchors.centerIn: parent
                    columns: 2; spacing: root.gap
                    Toggle { icon: "moon"; label: "Dark appearance"; on: root.darkAppearance; onTriggered: root.send("setting", { key: "dark" }) }
                    Toggle { icon: "motion"; label: "Reduce motion"; on: root.reduceMotion; onTriggered: root.send("setting", { key: "reduceMotion" }) }
                    Toggle { icon: "split"; label: "Split screen"; on: root.splitActive; visible: root.tablet; onTriggered: root.send("split") }
                    Toggle { icon: "cards"; label: "App switcher, " + root.taskCount + " running"; onTriggered: root.send("recents") }
                }
            }
        }
        // Brightness and volume, tall.
        Module {
            rank: 1
            x: 2 * (root.cell + root.gap); y: 0; width: root.cell; height: 2 * root.cell + root.gap
            Slider { anchors.fill: parent; icon: "sun"; label: "Brightness"; value: (root.brightness - 0.25) / 0.75; onMoved: v => root.send("setting", { key: "brightness", value: 0.25 + 0.75 * v }) }
        }
        Module {
            rank: 0
            x: 3 * (root.cell + root.gap); y: 0; width: root.cell; height: 2 * root.cell + root.gap
            Slider { anchors.fill: parent; icon: "volume"; label: "Volume"; value: root.volume; onMoved: v => root.send("setting", { key: "volume", value: v }) }
        }
        // The third row: home as a wide pill, then a screenshot and a reload.
        Module {
            rank: 3
            x: 0; y: 2 * (root.cell + root.gap); width: 2 * root.cell + root.gap; height: root.cell
            Tile {
                anchors.fill: parent
                Glyph { x: parent.height * 0.32; anchors.verticalCenter: parent.verticalCenter; width: parent.height * 0.36; height: width; name: "home" }
                Text {
                    x: parent.height * 0.8; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x - parent.height * 0.3; elide: Text.ElideRight
                    text: "Home"; color: "white"; font { pixelSize: 14; weight: Font.DemiBold }
                }
                MouseArea { anchors.fill: parent; onClicked: root.send("home") }
            }
        }
        Module {
            rank: 2
            x: 2 * (root.cell + root.gap); y: 2 * (root.cell + root.gap); width: root.cell; height: root.cell
            Toggle { anchors.centerIn: parent; width: root.cell; icon: "camera"; label: "Screenshot"; onTriggered: root.send("screenshot") }
        }
        Module {
            rank: 1
            x: 3 * (root.cell + root.gap); y: 2 * (root.cell + root.gap); width: root.cell; height: root.cell
            Toggle { anchors.centerIn: parent; width: root.cell; icon: "reload"; label: "Reload the shell"; onTriggered: root.send("reload") }
        }
    }
}
