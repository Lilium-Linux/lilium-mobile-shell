import QtQuick
import QtQuick.Shapes

// A Control Center icon, drawn as vector strokes in one colour: crisp at any
// scale and the same on every icon theme. `name` picks it.
Item {
    id: glyph
    property string name: ""
    property color color: "white"
    property real stroke: 2.2
    // Drawn solid rather than stroked: the shapes that are closed outlines
    // (an aeroplane, a moon) read as the iPad's filled symbols.
    readonly property bool solid: ["airplane", "moon"].indexOf(name) >= 0
    implicitWidth: 24; implicitHeight: 24

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        // Every path is drawn on a 24-unit square and scaled to the item.
        transform: Scale { xScale: glyph.width / 24; yScale: glyph.height / 24 }

        ShapePath {
            strokeColor: glyph.solid ? "transparent" : glyph.color
            strokeWidth: glyph.stroke * 24 / Math.max(1, glyph.width)
            fillColor: glyph.solid ? glyph.color : "transparent"; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: ({
                    // A crescent moon.
                    moon: "M 15.5 4.5 A 8 8 0 1 0 19.5 16 A 6.5 6.5 0 0 1 15.5 4.5 Z",
                    // A sun: a disc and eight rays.
                    sun: "M 12 8.5 A 3.5 3.5 0 1 1 11.99 8.5 M 12 2.5 L 12 4.5 M 12 19.5 L 12 21.5 M 2.5 12 L 4.5 12 M 19.5 12 L 21.5 12 M 5.3 5.3 L 6.7 6.7 M 17.3 17.3 L 18.7 18.7 M 5.3 18.7 L 6.7 17.3 M 17.3 6.7 L 18.7 5.3",
                    // A speaker and two waves.
                    volume: "M 4 9.5 L 7.5 9.5 L 12 5.5 L 12 18.5 L 7.5 14.5 L 4 14.5 Z M 15.5 9 A 4 4 0 0 1 15.5 15 M 18 6.5 A 7.5 7.5 0 0 1 18 17.5",
                    // Speed lines: motion, reduced or not.
                    motion: "M 4 7.5 L 15 7.5 M 8 12 L 20 12 M 4 16.5 L 15 16.5",
                    // Two panes side by side.
                    split: "M 4 5.5 L 10.5 5.5 L 10.5 18.5 L 4 18.5 Z M 13.5 5.5 L 20 5.5 L 20 18.5 L 13.5 18.5 Z",
                    // Stacked cards: the app switcher.
                    cards: "M 6 8 L 6 19 L 15 19 L 15 8 Z M 9 5 L 18 5 L 18 16",
                    // A house.
                    home: "M 4 11 L 12 4.5 L 20 11 M 6.5 9.5 L 6.5 19 L 17.5 19 L 17.5 9.5 M 10 19 L 10 14 L 14 14 L 14 19",
                    // A camera body and its lens.
                    camera: "M 3.5 8 L 7.5 8 L 9 5.5 L 15 5.5 L 16.5 8 L 20.5 8 L 20.5 18.5 L 3.5 18.5 Z M 12 9.8 A 3.3 3.3 0 1 1 11.99 9.8",
                    // Three arcs and a dot: Wi-Fi.
                    wifi: "M 3 9.5 A 13 13 0 0 1 21 9.5 M 6.2 13 A 8.4 8.4 0 0 1 17.8 13 M 9.4 16.4 A 3.8 3.8 0 0 1 14.6 16.4 M 12 19.6 L 12 19.7",
                    // An aeroplane, nose up and to the right.
                    airplane: "M 12 3 C 13 3 13.3 4 13.3 5 L 13.3 9.5 L 20.5 13.5 L 20.5 15.5 L 13.3 13.3 L 13.3 18 L 15.5 19.8 L 15.5 21.3 L 12 20.3 L 8.5 21.3 L 8.5 19.8 L 10.7 18 L 10.7 13.3 L 3.5 15.5 L 3.5 13.5 L 10.7 9.5 L 10.7 5 C 10.7 4 11 3 12 3 Z",
                    // The Bluetooth rune.
                    bluetooth: "M 7.5 7.5 L 16.5 16 L 12 20 L 12 4 L 16.5 8 L 7.5 16.5",
                    // A power button.
                    power: "M 12 3.5 L 12 11.5 M 7.2 6.4 A 7.5 7.5 0 1 0 16.8 6.4",
                    // A circular arrow: reload.
                    reload: "M 19 12 A 7 7 0 1 1 16.5 6.6 M 17 3 L 17 7 L 13 7",
                })[glyph.name] || ""
            }
        }
    }
}
