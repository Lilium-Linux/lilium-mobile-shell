import QtQuick
import Solium

// No titlebar reservation. Both the client mask and this header belong to
// the pane, and go through exactly the same presentation matrix as its pixels.
PaneStyle {
    requires: []
    client.radius: 0 // corners are the present's: mobile-card, mobile-flight
    Layer { name: "icon"; depth: "behind"; source: "Icon.qml" }
    // Its bleed is also the room a card's shadow is drawn in: mobile-card's
    // frag draws it from the card's own rounded shape, 48 px around.
    Layer { name: "identity"; depth: "above"; bleed: { "top": 160, "left": 48, "right": 48, "bottom": 48 }; source: "Identity.qml" }
    // The gesture bar at the bottom of an application's window, which shows
    // where the swipe up starts.
    Layer { name: "bar"; depth: "above"; source: "GestureBar.qml" }
}
