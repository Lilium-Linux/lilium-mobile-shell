import QtQuick

// Wi-Fi and the battery, as the status bar shows them and as the Control
// Center carries them above its panel: one item, so the two are the same
// pixels wherever it is drawn.
Row {
    id: cluster
    property int battery: -1     // percent, -1 for none
    property bool charging: false
    property bool wifi: false    // connected
    spacing: 7
    height: 16
    Glyph {
        visible: cluster.wifi
        width: 16; height: 16; stroke: 2.1; name: "wifi"
        anchors.verticalCenter: parent.verticalCenter
    }
    Text {
        visible: cluster.battery >= 0
        text: cluster.battery + "%"; color: "white"
        font { pixelSize: 13; weight: Font.DemiBold }
        anchors.verticalCenter: parent.verticalCenter
    }
    Item {
        visible: cluster.battery >= 0
        width: 27; height: 13
        anchors.verticalCenter: parent.verticalCenter
        Rectangle {
            width: 24; height: 13; radius: 4
            color: "transparent"; border { width: 1.2; color: "#b3ffffff" }
            Rectangle {
                x: 2; y: 2; height: parent.height - 4; radius: 2
                width: Math.max(1.5, (parent.width - 4) * cluster.battery / 100)
                color: cluster.charging ? "#30d158" : (cluster.battery <= 20 ? "#ff453a" : "white")
            }
        }
        Rectangle { x: 25; y: 4.5; width: 2; height: 4; radius: 1; color: "#b3ffffff" }
    }
}
