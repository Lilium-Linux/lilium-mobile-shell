import QtQuick
Item {
    property bool down: false
    property real px: 0
    property real py: 0
    property real vx: 0
    property real vy: 0
    property real ax: 0
    property real ay: 0
    property string phase: ""
    Rectangle {
        x: px-width/2; y: py-height/2; width: 42; height: 42; radius: 21
        visible: down; color: "#7080dfff"; border.color: "white"; border.width: 2
        Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: "white" }
    }
    Rectangle {
        x: parent.width-width-18; y: Math.max(40, parent.height-height-44); width: 400; height: 80; radius: 12; color: "#e0182033"
        Column {
            anchors { left: parent.left; top: parent.top; margins: 10 }
            spacing: 3
            Text { text: "TOUCH · SURFACE MOBILE TEST"; color: "#80dfff"; font.pixelSize: 14 }
            Text { text: phase + (down ? " · finger down" : " · released"); color: "white"; font.pixelSize: 13 }
            Text { text: "v " + Math.round(vx) + ", " + Math.round(vy) + " px/s    a " + Math.round(ax) + ", " + Math.round(ay) + " px/s²"; color: "#dae2ef"; font.pixelSize: 12 }
        }
    }
}
