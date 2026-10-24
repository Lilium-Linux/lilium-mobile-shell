import QtQuick
import Solium

// The same pane-bound chrome as mobile, with no client corner mask while
// an application occupies its full tile. Insets remain identical in both.
PaneStyle {
    requires: []
    client.radius: 0
    Layer { name: "icon"; depth: "behind"; source: "../mobile/Icon.qml" }
    // Its bleed is also the room a card's shadow is drawn in: mobile-card's
    // frag draws it from the card's own rounded shape, 48 px around.
    Layer { name: "identity"; depth: "above"; bleed: { "top": 160, "left": 48, "right": 48, "bottom": 48 }; source: "../mobile/Identity.qml" }
    // The gesture bar at the bottom of an application's window, which shows
    // where the swipe up starts.
    Layer { name: "bar"; depth: "above"; source: "../mobile/GestureBar.qml" }
}
