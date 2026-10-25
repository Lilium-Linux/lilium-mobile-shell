import QtQuick
import Solium

// The Control Center, after the iPad's (measured frame by frame from a
// recording). Its surface is always there: at rest it draws only the status
// bar's Wi-Fi and battery, so they are one set of pixels from the bar to the
// open panel and nothing is handed over between scenes.
//   - Pulled down from the top-right edge, the Wi-Fi and battery, the dim and
//     the blur follow the finger one to one over `travel` pixels; past it they
//     give only a little (rubber band) and come back when let go.
//   - The modules are not dragged in. Past about half way they fade in over a
//     few frames, drifting down a few pixels into place; back under a third,
//     or closed, they fade out drifting up.
//   - Let go, a spring takes it the rest of the way from the finger's own
//     speed, and stops at the end instead of going past it.
// The dim's progress is reported to the policy every frame for the blur.
Item {
    id: root

    // ---- From the policy (mobile/policy.lua) ------------------------------
    property real progress: 0          // the finger's travel since it went down, while `dragging`
    property bool dragging: false
    property real target: 0            // where to settle once let go: 0 or 1
    property real releaseVelocity: 0   // progress per second at the release
    property real fingerDx: 0          // pixels sideways since the finger went down
    property int release: 0            // moves on each release, to start the spring
    property real travel: 150          // pixels of finger from closed to open
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
    property string mediaStatus: ""    // Playing, Paused, or empty for none
    property string mediaTitle: ""
    property string mediaArtist: ""

    function send(action, data) { Solium.send("mobile.control." + action, data || {}) }

    // ---- Geometry ------------------------------------------------------------
    readonly property real cell: tablet ? 70 : 62
    readonly property real gap: 14
    readonly property real span: 4 * cell + 3 * gap
    readonly property real restY: tablet ? 142 : 116
    readonly property real rightMargin: tablet ? 96 : 16

    // Where the blur is: the right side, from a little left of the panel to
    // the edge, top to bottom, fading out leftwards over a fifth of the width.
    function reportGeometry() {
        if (width <= 0 || height <= 0) return
        const left = Math.max(0, panel.x - 40) / width
        send("geometry", { x: left, y: 0, w: 1 - left + 0.1, h: 1.1, soft: 0.2 })
    }
    onWidthChanged: Qt.callLater(reportGeometry)
    onHeightChanged: Qt.callLater(reportGeometry)
    Component.onCompleted: reportGeometry()
    // The status the policy reads in the background on each open, read again
    // once it is in.
    Timer { id: refreshTimer; interval: 450; onTriggered: root.send("refresh") }

    // ---- The one progress -------------------------------------------------------
    property real shown: 0
    property real speed: 0
    // Critically damped and quick, as the iPad's: within 1 % in about a
    // quarter of a second, and never past the end.
    readonly property real omega: 2 * Math.PI / (0.32 * Math.max(0.25, pace))
    // Whether the modules are in: past 45 % on the way down, until back
    // under 30 %, so a finger wavering at the threshold does not flicker them.
    property bool armed: false

    function track(value) {
        nudgeBack.stop()
        nudge = Math.max(-16, Math.min(16, fingerDx * 0.12))
        shown = value
        if (value >= 0.45) armed = true
        else if (value < 0.3) armed = false
        report()
    }
    // The policy hands `dragging`, `progress`, `target` and `release` over in
    // one declaration, in no particular order, so each is acted on once all
    // of them are in: read on its own, `release` could start the spring
    // towards the last `target`, and leave the screen dimmed with no panel,
    // or closed with the panel's tap-anywhere-to-close still taking presses.
    // A finger already being followed is followed at once, so it is never a
    // frame behind.
    onProgressChanged: if (dragging && following) track(fingered(progress)); else Qt.callLater(follow)
    onDraggingChanged: Qt.callLater(follow)
    onReleaseChanged: Qt.callLater(released)
    property int settledRelease: 0
    property bool following: false
    // Where the sheet was when the finger took it: a pull while it is still
    // opening or closing, or open, moves it on from there instead of from
    // closed, so nothing jumps. Past open it gives only a quarter (rubber
    // band).
    property real grabbedAt: 0
    function fingered(travelled) {
        const value = grabbedAt + travelled
        return Math.max(0, value <= 1 ? value : 1 + (value - 1) * 0.25)
    }
    function follow() {
        if (!dragging) { following = false; return }
        if (!following) {
            following = true
            spring.running = false
            grabbedAt = Math.max(0, Math.min(1, shown))
            refreshTimer.restart()
        }
        track(fingered(progress))
    }
    function released() {
        if (release === settledRelease) return
        settledRelease = release
        following = false
        letGo()
        settle(target, releaseVelocity)
    }

    function settle(to, velocity) {
        if (to === 1 && shown <= 0) refreshTimer.restart()
        target = to
        armed = to === 1
        if (reduceMotion) { shown = to; speed = 0; report(); settled(); return }
        speed = velocity
        spring.running = true
    }

    FrameAnimation {
        id: spring
        running: false
        onTriggered: {
            const dt = Math.min(frameTime, 1 / 30)
            const before = root.shown - root.target
            const accel = -root.omega * root.omega * before - 2 * root.omega * root.speed
            root.speed += accel * dt
            root.shown += root.speed * dt
            const after = root.shown - root.target
            // Done once close, or at the end if the finger's speed would carry
            // it past: it stops there rather than swinging back.
            if ((before !== 0 && after * before <= 0)
                    || (Math.abs(after) < 0.0015 && Math.abs(root.speed) < 0.02)) {
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

    // The blur follows the dim; the policy keeps where the sheet is, for the
    // next finger that takes it.
    function report() { send("progress", { value: dim, shown: shown }) }
    function settled() {
        if (target !== 0) return
        armed = false
        send("closed")
    }

    // Shapes of the progress: `ramp(a, b)` is 0 before a, 1 after b, eased.
    function ramp(a, b) {
        const t = Math.max(0, Math.min(1, (shown - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }
    readonly property real s: Math.max(0, Math.min(1, shown))
    readonly property real dim: ramp(0, 0.5)
    // The iPad's jelly, measured frame by frame: pulled past open the
    // content moves down about 14 px and stretches about 5 % downwards from
    // the top of the screen, and on its way after a release it is up to 2 %
    // longer still while it moves fast; it all relaxes with the spring, with
    // no swing back. Under the finger nothing is smoothed: it is where the
    // finger puts it.
    // `over` is how far past open the finger is, in travels (the policy
    // hands over a quarter of it), and `give` that rubber-banded to 0..1.
    readonly property real over: shown > 1 ? (shown - 1) / 0.25 : 0
    readonly property real give: 1 - 1 / (1 + 1.5 * over)
    readonly property real squish: reduceMotion || !spring.running ? 0 : 0.02 * Math.min(1, Math.abs(speed) / 8)
    readonly property real sag: reduceMotion ? 0 : 14 * give
    readonly property real stretchY: reduceMotion ? 0 : 0.055 * give + squish
    // The status icons go down first and across after, as the iPad's: the
    // sideways part is the square of the way down. A sideways finger moves
    // them a little off that path, and once let go they ease back onto it.
    readonly property real across: s * s
    property real nudge: 0
    NumberAnimation {
        id: nudgeBack
        target: root; property: "nudge"; to: 0
        duration: 280 * Math.max(0.25, root.pace); easing.type: Easing.OutCubic
    }
    function letGo() { if (reduceMotion) nudge = 0; else nudgeBack.restart() }
    // The modules' fade, a few frames each way.
    property real reveal: armed ? 1 : 0
    Behavior on reveal {
        enabled: !root.reduceMotion
        NumberAnimation { duration: (root.armed ? 120 : 100) * Math.max(0.25, root.pace); easing.type: Easing.OutCubic }
    }

    // ---- Behind ------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.48 * root.dim
        visible: opacity > 0.001
    }
    // Anywhere but a control: a tap closes it, a swipe up pushes it back.
    MouseArea {
        anchors.fill: parent
        enabled: root.target === 1 && !root.dragging && root.shown > 0
        visible: enabled
        property real startY: 0
        property real lastY: 0
        property real lastTime: 0
        property real velocity: 0
        property bool pushing: false
        // Where the push took the sheet, and the finger then: pushed while it
        // is still opening, it goes on from where it was.
        property real pushedFrom: 1
        property real pushY: 0
        onPressed: mouse => { startY = lastY = mouse.y; lastTime = Date.now(); velocity = 0; pushing = false }
        onPositionChanged: mouse => {
            const now = Date.now()
            if (now > lastTime) velocity = (mouse.y - lastY) / ((now - lastTime) / 1000) / root.travel
            lastY = mouse.y; lastTime = now
            if (!pushing && startY - mouse.y > 10) {
                pushing = true
                spring.running = false
                pushedFrom = Math.min(1, root.shown)
                pushY = mouse.y
            }
            if (pushing) root.track(Math.max(0, Math.min(1, pushedFrom - (pushY - mouse.y) / root.travel)))
        }
        onReleased: {
            if (!pushing) { root.settle(0, 0); return }
            pushing = false
            root.settle(root.shown < 0.65 || velocity < -1.0 ? 0 : 1, velocity)
        }
    }

    // Everything but the dim: one sheet, so the jelly stretches it as one.
    Item {
        id: content
        anchors.fill: parent
        transform: [
            Scale { origin.y: 0; yScale: 1 + root.stretchY },
            Translate { y: root.sag }
        ]

        // ---- The top: the clock, status and power -------------------------------------
        // The status bar's clock, faded out as the Control Center comes down,
        // as the iPad's is. Read at the start of each minute only.
        Text {
            id: clock
            property date now: new Date()
            x: 24; y: (root.statusHeight - height) / 2
            text: Qt.formatTime(now, "h:mm")
            color: "white"; font { pixelSize: 13; weight: Font.DemiBold }
            opacity: 1 - root.ramp(0, 0.35)
            visible: opacity > 0.001
            Timer {
                interval: Math.max(1000, 60000 - clock.now.getSeconds() * 1000 - clock.now.getMilliseconds())
                running: true; repeat: true
                onTriggered: clock.now = new Date()
            }
        }
        // The status bar's own Wi-Fi and battery: at rest where the bar has them,
        // carried with the finger to above the panel.
        StatusCluster {
            id: cluster
            battery: root.battery; charging: root.charging; wifi: root.wifiLinked
            readonly property real fromX: root.width - width - 18
            readonly property real fromY: (root.statusHeight - height) / 2
            readonly property real toX: panel.x + panel.width - width
            readonly property real toY: root.restY - height - 14
            x: fromX + (toX - fromX) * root.across + root.nudge
            y: fromY + (toY - fromY) * root.s
            scale: 1 + 0.1 * root.s
            transformOrigin: Item.Right
        }
        Rectangle {
            id: power
            width: 40; height: 40; radius: 20
            color: powerPress.pressed ? "#33ffffff" : "transparent"
            x: panel.x + panel.width - width + 4
            y: root.tablet ? 30 : 22
            opacity: root.ramp(0.15, 0.7)
            visible: opacity > 0.001
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
            // In from a few pixels above, out to them.
            y: root.restY - 8 * (1 - root.reveal)
            opacity: root.reveal
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
                property string label: ""
                signal triggered()
                width: root.cell; height: width; radius: width / 2
                color: on ? accent : "#2bffffff"
                border { width: 1.2; color: on ? Qt.lighter(accent, 1.25) : "#3dffffff" }
                Accessible.role: Accessible.Button
                Accessible.name: label
                Glyph { anchors.centerIn: parent; width: parent.width * 0.45; height: width; name: round.icon; color: "white" }
                scale: tap.pressed ? 0.9 : 1
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                MouseArea { id: tap; anchors.fill: parent; onClicked: round.triggered() }
            }
            // A tall slider: the fill follows the finger, which keeps its own
            // value while it drags and hands it over at most 20 times a second,
            // and goes on showing it once let go until the policy's value is back.
            component Pill: Frost {
                id: pill
                property real value: 0
                property string icon: ""
                property color tint: "white"
                property string label: ""
                signal moved(real value)
                property real held: value
                property bool handing: false
                readonly property real drawn: Math.max(0, Math.min(1, drag.pressed || handing ? held : value))
                onValueChanged: if (handing && Math.abs(value - held) < 0.01) handing = false
                radius: width / 2
                Accessible.role: Accessible.Slider
                Accessible.name: label
                Glyph {
                    id: glyph
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: parent.width * 0.3 }
                    width: parent.width * 0.42; height: width; name: pill.icon
                }
                // The fill: the pill's own shape cut at the level, so however low
                // it is its bottom is the pill's round end, and the icon in the
                // tint where the fill covers it.
                Item {
                    id: level
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: parent.height * pill.drawn
                    clip: true
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: pill.height; radius: pill.radius
                        color: "#f2f2f7"
                    }
                    // Only once the fill reaches the icon: the software renderer
                    // does not clip a Shape, and below that the icon is white.
                    Glyph {
                        x: glyph.x; y: glyph.y - level.y
                        width: glyph.width; height: glyph.height; name: pill.icon; color: pill.tint
                        visible: level.height > pill.height - glyph.y - glyph.height
                    }
                }
                Timer { id: handOver; interval: 50; onTriggered: pill.moved(pill.held) }
                Timer { id: handedBack; interval: 600; onTriggered: pill.handing = false }
                MouseArea {
                    id: drag
                    anchors.fill: parent
                    property real from: 0
                    property real startY: 0
                    onPressed: mouse => { from = pill.drawn; pill.held = from; startY = mouse.y }
                    onPositionChanged: mouse => {
                        pill.held = Math.max(0, Math.min(1, from + (startY - mouse.y) / pill.height))
                        if (!handOver.running) handOver.start()
                    }
                    onReleased: {
                        handOver.stop()
                        pill.handing = true
                        handedBack.restart()
                        pill.moved(pill.held)
                    }
                }
            }

            readonly property real c: root.cell
            readonly property real g: root.gap
            function at(column) { return column * (c + g) }

            // Connectivity: airplane, split screen, Wi-Fi, Bluetooth, each a
            // button like every other.
            Round { x: 0; y: 0; icon: "airplane"; label: "Airplane mode"; on: root.airplane; accent: "#ff9f0a"; onTriggered: root.send("airplane") }
            Round { x: panel.at(1); y: 0; icon: "split"; label: "Split screen"; on: root.splitActive; enabled: root.tablet; opacity: enabled ? 1 : 0.4; onTriggered: root.send("split") }
            Round { x: 0; y: panel.at(1); icon: "wifi"; label: "Wi-Fi"; on: root.wifi && !root.airplane; onTriggered: root.send("wifi") }
            Round { x: panel.at(1); y: panel.at(1); icon: "bluetooth"; label: "Bluetooth"; on: root.bluetooth && !root.airplane; onTriggered: root.send("bluetooth") }
            // Now Playing: whatever an MPRIS player is playing (playerctl).
            Frost {
                id: media
                readonly property bool playing: root.mediaStatus === "Playing"
                readonly property bool none: root.mediaStatus === ""
                x: panel.at(2); y: 0; width: 2 * panel.c + panel.g; height: width
                Rectangle {
                    x: 16; y: 16; width: 46; height: 46; radius: 12
                    color: "#24ffffff"
                    Glyph { anchors.centerIn: parent; width: 22; height: 22; name: "note"; color: "#99ffffff" }
                }
                Column {
                    x: 16; y: 72; width: parent.width - 32; spacing: 1
                    Text {
                        width: parent.width; elide: Text.ElideRight
                        text: media.none ? "Not Playing" : (root.mediaTitle || "Unknown")
                        color: "white"; font { pixelSize: 14; weight: Font.DemiBold }
                    }
                    Text {
                        width: parent.width; elide: Text.ElideRight; visible: !media.none && root.mediaArtist !== ""
                        text: root.mediaArtist; color: "#b3ffffff"; font { pixelSize: 12 }
                    }
                }
                Row {
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 10 }
                    spacing: 6
                    opacity: media.none ? 0.45 : 1
                    Repeater {
                        model: [{ icon: "previous", act: "previous", size: 18 },
                                { icon: media.playing ? "pause" : "play", act: "play", size: 22 },
                                { icon: "next", act: "next", size: 18 }]
                        Rectangle {
                            required property var modelData
                            width: 40; height: 40; radius: 20
                            color: hit.pressed ? "#33ffffff" : "transparent"
                            Glyph { anchors.centerIn: parent; width: modelData.size; height: width; name: modelData.icon }
                            MouseArea { id: hit; anchors.fill: parent; enabled: !media.none; onClicked: root.send("media", { act: modelData.act }) }
                        }
                    }
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
            // Solium's own Audio when it has it (#347): live, and coalesced
            // there, so the slider may write on every move. Else the policy's
            // `wpctl`.
            Pill {
                readonly property bool live: typeof Audio !== "undefined" && Audio.available && Audio.output.present
                x: panel.at(3); y: panel.at(2); width: panel.c; height: 2 * panel.c + panel.g
                icon: "volume"; tint: "#0a84ff"; label: "Volume"
                value: live ? Audio.output.volume : root.volume
                onMoved: v => live ? Audio.output.setVolume(v) : root.send("volume", { value: v })
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
            // Do not disturb: only critical notifications get a banner, the
            // rest go straight to the lock sheet's list. Solium's own switch.
            Round {
                readonly property bool known: typeof Notifications !== "undefined"
                x: panel.at(3); y: panel.at(4); icon: "bell-off"; label: "Do not disturb"
                accent: "#5e5ce6"; on: known && Notifications.dnd
                enabled: known && Notifications.available; opacity: enabled ? 1 : 0.4
                onTriggered: Notifications.setDnd(!Notifications.dnd)
            }
        }
    }
}
