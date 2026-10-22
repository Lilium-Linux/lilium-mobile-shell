import QtQuick

Rectangle {
    id: wallpaper
    property bool dark: false
    property bool overview: false
    // Dimmed behind an open application, as the iPad's is (about half), and
    // brightened as the window goes home: `dim` follows the finger through a
    // swipe (`dragging`), and eases otherwise.
    property real dim: 0
    property bool dragging: false
    // One flat colour: nothing behind the icons competes with them.
    color: dark ? "#141821" : "#3a4256"
    Rectangle {
        anchors.fill: parent; color: "black"; opacity: wallpaper.dim
        Behavior on opacity { enabled: !wallpaper.dragging; NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    }
    Rectangle { anchors.fill: parent; color: "#171a30"; opacity: parent.overview ? 0.25 : 0
        Behavior on opacity { NumberAnimation { duration: 280 } }
    }
}
