import QtQuick

Item {
    id: tile
    property string title: ""
    property string glyph: ""
    property string imageSource: ""
    property color tone: "#007aff"
    property bool showTitle: true
    property string appKey: ""
    // While its window flies to or from it, the tile's own art stands aside
    // for the pane that is the icon meanwhile; the name stays.
    property bool artHidden: false
    function iconRect() {
        const p = icon.mapToItem(null, 0, 0)
        return { x: p.x, y: p.y, size: icon.width }
    }
    signal triggered(var origin)
    width: 80; height: 92
    Accessible.role: Accessible.Button
    Accessible.name: title
    // The application's own icon, nothing behind it; a flat square with its
    // initial only when the theme has none.
    Item {
        id: icon
        width: 60; height: 60
        opacity: tile.artHidden ? 0 : 1
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top }
        scale: mouse.pressed ? 0.92 : 1
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Rectangle {
            visible: image.status !== Image.Ready
            anchors.fill: parent; radius: width / 4; color: "#5b6478"
            Text { anchors.centerIn: parent; text: tile.glyph; color: "white"; font { pixelSize: 28; weight: Font.Medium } }
        }
        Image { id: image; anchors.fill: parent; source: tile.imageSource; visible: status === Image.Ready; smooth: true; mipmap: true }
    }
    Text {
        visible: tile.showTitle
        anchors { top: icon.bottom; topMargin: 7; horizontalCenter: parent.horizontalCenter }
        width: parent.width; horizontalAlignment: Text.AlignHCenter
        text: tile.title; color: "white"; font.pixelSize: 12; elide: Text.ElideRight
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        onClicked: {
            tile.triggered(tile.iconRect())
        }
    }
}
