import QtQuick

Rectangle {
    id: control
    property string label: ""
    property string symbol: ""
    property color ink: "#ffffff"
    property color fill: "#3a4054"
    property bool highlighted: false
    signal triggered()
    implicitWidth: Math.max(56, content.implicitWidth + 32)
    implicitHeight: 48
    radius: height / 2
    color: mouse.pressed ? "#596174" : (highlighted ? "#ffffff" : fill)
    scale: mouse.pressed ? 0.94 : 1
    opacity: enabled ? 1 : 0.35
    Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 160 } }
    Accessible.role: Accessible.Button
    Accessible.name: label.length ? label : symbol
    Row {
        id: content
        anchors.centerIn: parent
        spacing: 8
        Text {
            visible: text.length > 0; text: control.symbol
            color: control.highlighted ? "#007aff" : control.ink
            font.pixelSize: 20; anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            visible: text.length > 0; text: control.label
            color: control.highlighted ? "#007aff" : control.ink
            font { pixelSize: 13; weight: Font.Medium }
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    MouseArea { id: mouse; anchors.fill: parent; onClicked: control.triggered() }
}
