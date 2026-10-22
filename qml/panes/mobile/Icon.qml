import QtQuick
import Solium

// The window's own icon, behind its client, while the window flies to or from
// its launcher icon (policy.lua's start_flight hands `mobileFlight` to every
// pane). The present fades the client inside the pane (`client_opacity`) and
// what shows through is this: the window turns into its icon as it lands, and
// a launch grows out of the icon before the app shows. One object, the pane;
// nothing else moves.
//
// The root covers the pane's outer rect. Drawn as a square tile stretched to
// the pane, because the present scales the
// pane to the icon's square: the stretch and that scale cancel at the landing,
// where it is exactly the launcher's icon.
Item {
    id: art
    property string title: ""
    property string appId: ""
    property var values: ({})
    readonly property var flight: values.mobileFlight || null
    // A launch flies the loading window: no application id yet, and named
    // after the program started (policy.lua hands its name over when it knows
    // it). Going home flies the window that is named.
    readonly property bool mine: flight !== null && (flight.kind === "launch"
        ? appId === "" && (!flight.program || title === "" || title === flight.program)
        : title === flight.title && appId === flight.appId)
    property bool dormant: !mine

    readonly property string key: flight ? flight.key : ""
    readonly property string iconName: {
        if (!key) return ""
        const app = Apps.get(key)
        return app && app.icon ? app.icon : key
    }

    Item {
        visible: art.mine
        width: art.height; height: art.height
        transform: Scale { xScale: art.height > 0 ? art.width / art.height : 1 }
        // As the launcher draws it (mobile/AppTile.qml): the icon alone, or a
        // flat square with the initial.
        Rectangle {
            visible: !image.visible
            anchors.fill: parent; radius: width / 4; color: "#5b6478"
            Text {
                anchors.centerIn: parent
                text: art.key.slice(0, 1).toUpperCase()
                color: "white"; font { pixelSize: parent.width * 0.47; weight: Font.Medium }
            }
        }
        Image {
            id: image
            anchors.fill: parent
            // Only the window that is flying loads it: an icon decoded for
            // every pane each time a flight starts is a frame lost per window.
            source: art.mine && art.iconName ? "image://solium/icon/" + art.iconName + "?size=256" : ""
            visible: status === Image.Ready
            smooth: true; mipmap: true
        }
    }
}
