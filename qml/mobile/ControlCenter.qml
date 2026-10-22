import QtQuick
import Solium

// The Control Center, after the iPad's (measured from a recording): pulled
// down from the top-right edge, it follows the finger; let go, a spring with
// no overshoot carries it the rest of the way from the finger's own speed. One
// progress, `shown`, draws all of it, in the iPad's order:
//   - the screen dims to about half (0.48 black), uniformly; only under and
//     round the panel is anything blurred (effects/cc-fade, effects/cc-blur,
//     masked to `panel`), so the tiles are frosted and the rest stays sharp;
//   - Wi-Fi and the battery slide with the finger from the status bar to
//     above the panel, and the power button fades in above its right edge;
//   - at about 60 % the modules appear, a few frames' fade, sitting higher by
//     as much as is left to pull, and glide down into place with the finger.
// The progress is reported to the policy every frame for the blur.
Item {
    id: root

    // ---- From the policy (mobile/policy.lua) ------------------------------
    property real progress: 0          // the finger's, while `dragging`
    property bool dragging: false
    property real target: 0            // where to settle once let go: 0 or 1
    property real releaseVelocity: 0   // progress per second at the release
    property int release: 0            // moves on each release, to start the spring
    property real pace: 1              // SOLIUM_MOBILE_PACE: slower is larger
    property bool reduceMotion: false
    property int statusHeight: 32
    property bool tablet: true
    property real brightness: 1        // 0..1
    property real volume: 0.5          // 0..1
    property bool darkAppearance: false
    property bool splitActive: false
    property int taskCount: 0
    property int battery: -1           // percent, -1 for none
    property bool charging: false
    property bool wifi: false          // the radio is on
    property bool wifiLinked: false    // and connected
    property bool bluetooth: false
    property bool airplane: false

    function send(action, data) { Solium.send("mobile.control." + action, data || {}) }

    // ---- Geometry ------------------------------------------------------------
    readonly property real cell: tablet ? 70 : 62
    readonly property real gap: 14
    readonly property real span: 4 * cell + 3 * gap
    readonly property real restY: tablet ? 142 : 116
    readonly property real rightMargin: tablet ? 96 : 16

    // The panel's place, for the blur's mask.
    function reportGeometry() {
        if (width <= 0 || height <= 0) return
        send("geometry", { x: panel.x / width, y: root.restY / height,
            w: panel.width / width, h: panel.height / height })
    }
    onWidthChanged: Qt.callLater(reportGeometry)
    onHeightChanged: Qt.callLater(reportGeometry)
    Component.onCompleted: { reportGeometry(); refreshTimer.start() }
    // The status the policy reads in the background, read again once it is in.
    Timer { id: refreshTimer; interval: 450; onTriggered: root.send("refresh") }

    // ---- The one progress -------------------------------------------------------
    property real shown: 0
    property real speed: 0
    // Critically damped, as the iPad's settles: no overshoot, about 0.55 s.
    readonly property real omega: 2 * Math.PI / (0.55 * Math.max(0.25, pace))

    onProgressChanged: if (dragging) { shown = progress; report() }
    onDraggingChanged: if (dragging) { spring.running = false; shown = progress }
    onReleaseChanged: settle(target, releaseVelocity)

    function settle(to, velocity) {
        target = to
        if (reduceMotion) { shown = to; speed = 0; report(); settled(); return }
        speed = velocity
        spring.running = true
    }

    FrameAnimation {
        id: spring
        running: false
        onTriggered: {
            const dt = Math.min(frameTime, 1 / 30)
            const accel = -root.omega * root.omega * (root.shown - root.target) - 2 * root.omega * root.speed
            root.speed += accel * dt
            root.shown += root.speed * dt
            if (Math.abs(root.shown - root.target) < 0.0015 && Math.abs(root.speed) < 0.02) {
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

    function report() { send("progress", { value: Math.max(0, Math.min(1, shown)) }) }
    function settled() { if (target === 0) send("closed") }

    // Shapes of the progress: `ramp(a, b)` is 0 before a, 1 after b, eased.
    function ramp(a, b) {
        const t = Math.max(0, Math.min(1, (shown - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }
    readonly property real s: Math.max(0, shown)
    // How far the cluster sits from rest: above while still being pulled,
    // a little below, rubber-banded, when pulled past open.
    readonly property real lift: shown < 1 ? (shown - 1) * 120 : (shown - 1) * 40

    // ---- Behind ------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.48 * root.ramp(0, 0.6)
    }
    // Anywhere but a control: a tap closes it, a swipe up pushes it back.
    MouseArea {
        anchors.fill: parent
        enabled: root.target === 1 && !root.dragging
        property real startY: 0
        property real lastY: 0
        property real lastTime: 0
        property real velocity: 0
        property bool pushing: false
        readonly property real travel: root.height * 0.42
        onPressed: mouse => { startY = lastY = mouse.y; lastTime = Date.now(); velocity = 0; pushing = false }
        onPositionChanged: mouse => {
            const now = Date.now()
            if (now > lastTime) velocity = (mouse.y - lastY) / ((now - lastTime) / 1000) / travel
            lastY = mouse.y; lastTime = now
            if (!pushing && startY - mouse.y > 10) { pushing = true; spring.running = false }
            if (pushing) { root.shown = Math.max(0, Math.min(1, 1 - (startY - mouse.y) / travel)); root.report() }
        }
        onReleased: {
            if (!pushing) { root.settle(0, 0); return }
            pushing = false
            root.settle(root.shown < 0.75 || velocity < -1.0 ? 0 : 1, velocity)
        }
    }

    // ---- The top: status and power ------------------------------------------------
    StatusCluster {
        id: cluster
        battery: root.battery; charging: root.charging; wifi: root.wifiLinked
        readonly property real fromX: root.width - width - 18
        readonly property real fromY: (root.statusHeight - height) / 2
        readonly property real toX: panel.x + panel.width - width
        readonly property real toY: root.restY - height - 14
        readonly property real t: Math.min(1, root.s)
        x: fromX + (toX - fromX) * t
        y: fromY + (toY - fromY) * t + Math.max(0, root.lift) * 0.5
        scale: 1 + 0.12 * t
        transformOrigin: Item.Right
        visible: root.s > 0.001
    }
    Rectangle {
        id: power
        width: 40; height: 40; radius: 20
        color: powerPress.pressed ? "#33ffffff" : "transparent"
        x: panel.x + panel.width - width + 4
        y: root.tablet ? 30 : 22
        opacity: root.ramp(0.35, 0.6)
        Accessible.role: Accessible.Button
        Accessible.name: "Suspend"
        Glyph { anchors.centerIn: parent; width: 22; height: 22; name: "power" }
        MouseArea { id: powerPress; anchors.fill: parent; enabled: root.target === 1; onClicked: root.send("power") }
    }

    // ---- The panel ------------------------------------------------------------------
    Item {
        id: panel
        width: root.span; height: 5 * root.cell + 4 * root.gap
        x: root.width - width - root.rightMargin
        y: root.restY + root.lift
        // The modules appear together, over a few frames, at about 60 %.
        opacity: root.ramp(0.56, 0.66)
        visible: opacity > 0.001

        // Frosted material: what is behind is blurred by the effect under
        // the panel; the tile adds a pale veil, a hairline and a soft sheen.
        component Frost: Rectangle {
            id: frost
            radius: Math.min(width, height) * 0.27
            color: "#2bffffff"
            // A sheen down from the top edge, and a light rim brightest
            // along the top: what makes the tile read as a pane of frost.
            Rectangle {
                anchors.fill: parent
                radius: frost.radius
                gradient: Gradient {
                    GradientStop { position: 0; color: "#1cffffff" }
                    GradientStop { position: 0.5; color: "#00ffffff" }
                }
            }
            Rectangle {
                anchors.fill: parent
                radius: frost.radius
                color: "transparent"
                border { width: 1.2; color: "#3dffffff" }
            }
        }
        // A round button: on its own (frosted) or inside a tile.
        component Round: Rectangle {
            id: round
            property string icon: ""
            property bool on: false
            property color accent: "#0a84ff"
            property bool inset: false
            property string label: ""
            signal triggered()
            width: root.cell * (inset ? 0.8 : 1); height: width; radius: width / 2
            color: on ? accent : (inset ? "#2effffff" : "#2bffffff")
            border { width: inset ? 0 : 1.2; color: "#3dffffff" }
            Accessible.role: Accessible.Button
            Accessible.name: label
            Glyph { anchors.centerIn: parent; width: parent.width * 0.45; height: width; name: round.icon; color: "white" }
            scale: tap.pressed ? 0.9 : 1
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            MouseArea { id: tap; anchors.fill: parent; onClicked: round.triggered() }
        }
        // A tall slider: the fill follows the finger, which keeps its own
        // value while it drags and hands it over at most 20 times a second.
        component Pill: Frost {
            id: pill
            property real value: 0
            property string icon: ""
            property color tint: "white"
            property string label: ""
            signal moved(real value)
            property real held: value
            readonly property real drawn: drag.pressed ? held : value
            radius: width / 2
            Accessible.role: Accessible.Slider
            Accessible.name: label
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: parent.height * Math.max(0, Math.min(1, pill.drawn))
                color: "#f2f2f7"
                bottomLeftRadius: Math.min(pill.radius, height / 2); bottomRightRadius: bottomLeftRadius
                topLeftRadius: Math.max(0, pill.radius - (pill.height - height)); topRightRadius: topLeftRadius
            }
            Glyph {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: parent.width * 0.3 }
                width: parent.width * 0.42; height: width; name: pill.icon
                color: pill.drawn > 0.2 ? pill.tint : "white"
            }
            Timer { id: handOver; interval: 50; onTriggered: pill.moved(pill.held) }
            MouseArea {
                id: drag
                anchors.fill: parent
                property real from: 0
                property real startY: 0
                onPressed: mouse => { from = pill.value; pill.held = pill.value; startY = mouse.y }
                onPositionChanged: mouse => {
                    pill.held = Math.max(0, Math.min(1, from + (startY - mouse.y) / pill.height))
                    if (!handOver.running) handOver.start()
                }
                onReleased: { handOver.stop(); pill.moved(pill.held) }
            }
        }

        readonly property real c: root.cell
        readonly property real g: root.gap
        function at(column) { return column * (c + g) }

        // Connectivity: airplane, split screen, Wi-Fi, Bluetooth.
        Frost {
            x: 0; y: 0; width: 2 * panel.c + panel.g; height: width
            Grid {
                anchors.centerIn: parent; columns: 2; spacing: panel.g
                Round { inset: true; icon: "airplane"; label: "Airplane mode"; on: root.airplane; accent: "#ff9f0a"; onTriggered: root.send("airplane") }
                Round { inset: true; icon: "split"; label: "Split screen"; on: root.splitActive; enabled: root.tablet; opacity: enabled ? 1 : 0.4; onTriggered: root.send("split") }
                Round { inset: true; icon: "wifi"; label: "Wi-Fi"; on: root.wifi && !root.airplane; onTriggered: root.send("wifi") }
                Round { inset: true; icon: "bluetooth"; label: "Bluetooth"; on: root.bluetooth && !root.airplane; onTriggered: root.send("bluetooth") }
            }
        }
        // The battery, where the iPad has Now Playing.
        Frost {
            x: panel.at(2); y: 0; width: 2 * panel.c + panel.g; height: width
            Item {
                x: 18; y: 18; width: 44; height: 22
                Rectangle {
                    width: 40; height: 22; radius: 6; color: "transparent"; border { width: 2; color: "#d9ffffff" }
                    Rectangle {
                        x: 3; y: 3; height: parent.height - 6; radius: 3
                        width: Math.max(2, (parent.width - 6) * Math.max(0, root.battery) / 100)
                        color: root.charging ? "#30d158" : (root.battery >= 0 && root.battery <= 20 ? "#ff453a" : "white")
                    }
                }
                Rectangle { x: 41; y: 7; width: 3; height: 8; radius: 1.5; color: "#d9ffffff" }
            }
            Text {
                x: 18; anchors { bottom: parent.bottom; bottomMargin: 44 }
                text: root.battery >= 0 ? root.battery + "%" : "—"
                color: "white"; font { pixelSize: 34; weight: Font.DemiBold }
            }
            Text {
                x: 18; anchors { bottom: parent.bottom; bottomMargin: 22 }
                text: root.battery < 0 ? "No battery" : (root.charging ? "Charging" : "Battery")
                color: "#b3ffffff"; font { pixelSize: 13; weight: Font.Medium }
            }
        }
        // Reduce motion and the app switcher; brightness and volume, tall.
        Round { x: 0; y: panel.at(2); icon: "motion"; label: "Reduce motion"; on: root.reduceMotion; onTriggered: root.send("setting", { key: "reduceMotion" }) }
        Round { x: panel.at(1); y: panel.at(2); icon: "cards"; label: "App switcher, " + root.taskCount + " running"; onTriggered: root.send("recents") }
        Pill {
            x: panel.at(2); y: panel.at(2); width: panel.c; height: 2 * panel.c + panel.g
            icon: "sun"; tint: "#ff9f0a"; label: "Brightness"; value: root.brightness
            onMoved: v => root.send("brightness", { value: v })
        }
        Pill {
            x: panel.at(3); y: panel.at(2); width: panel.c; height: 2 * panel.c + panel.g
            icon: "volume"; tint: "#0a84ff"; label: "Volume"; value: root.volume
            onMoved: v => root.send("volume", { value: v })
        }
        // Appearance, wide, as the iPad's Focus.
        Frost {
            x: 0; y: panel.at(3); width: 2 * panel.c + panel.g; height: panel.c
            radius: height / 2
            Rectangle {
                x: 9; anchors.verticalCenter: parent.verticalCenter
                width: parent.height - 18; height: width; radius: width / 2
                color: root.darkAppearance ? "#5e5ce6" : "#24ffffff"
                Glyph { anchors.centerIn: parent; width: parent.width * 0.5; height: width; name: "moon" }
            }
            Text {
                x: parent.height + 2; anchors.verticalCenter: parent.verticalCenter
                text: root.darkAppearance ? "Dark" : "Light"
                color: "white"; font { pixelSize: 15; weight: Font.DemiBold }
            }
            MouseArea { anchors.fill: parent; onClicked: root.send("setting", { key: "dark" }) }
        }
        // Home, a screenshot, a reload.
        Round { x: 0; y: panel.at(4); icon: "home"; label: "Home"; onTriggered: root.send("home") }
        Round { x: panel.at(1); y: panel.at(4); icon: "camera"; label: "Screenshot"; onTriggered: root.send("screenshot") }
        Round { x: panel.at(2); y: panel.at(4); icon: "reload"; label: "Reload the shell"; onTriggered: root.send("reload") }
    }
}
