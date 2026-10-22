import QtQuick

Rectangle {
    id: tile
    property string glyph: ""
    property string label: ""
    property string detail: ""
    property bool active: false
    signal triggered()
    radius: 23
    color: active ? "#f2f2f7" : "#b52e354a"
    Accessible.role: Accessible.Button
    Accessible.name: label + ", " + detail
    Text { x: 16; y: 13; text: tile.glyph; color: tile.active ? "#007aff" : "white"; font.pixelSize: 26 }
    Text { x: 16; y: parent.height - 43; text: tile.label; color: tile.active ? "#1c1c1e" : "white"; font { pixelSize: 14; weight: Font.DemiBold } }
    Text { x: 16; y: parent.height - 24; text: tile.detail; color: tile.active ? "#707078" : "#bdc1ce"; font.pixelSize: 11 }
    MouseArea { anchors.fill: parent; onClicked: tile.triggered() }
}
