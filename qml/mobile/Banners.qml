import QtQuick

// Notification banners, as the iPad shows them: dropped in from the top edge,
// newest on top, a swipe up puts one away and a tap opens it. Solium holds
// the notifications (`Notifications.banners`); this only draws them, and
// says what the finger did.
Item {
    id: root
    // The status bar's height: banners hang just under it.
    property real statusTop: 32
    property bool tablet: true
    // The newest few: an iPad shows one at a time and the rest wait under it.
    readonly property int shown: 3
    readonly property bool present: typeof Notifications !== "undefined"

    ListView {
        id: list
        x: (root.width - width) / 2
        y: root.statusTop + 8
        width: Math.min(root.tablet ? 420 : root.width - 16, root.width - 16)
        height: Math.min(contentHeight, root.height - y)
        spacing: 8
        interactive: false
        model: root.present ? Notifications.banners : null

        // In from above the top edge, as on the iPad, on a spring with no
        // overshoot; out the same way.
        add: Transition {
            NumberAnimation { property: "y"; from: -96; duration: 420; easing.type: Easing.OutQuart }
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
        }
        remove: Transition {
            NumberAnimation { property: "y"; to: -120; duration: 300; easing.type: Easing.InCubic }
            NumberAnimation { property: "opacity"; to: 0; duration: 260 }
        }
        displaced: Transition {
            NumberAnimation { property: "y"; duration: 320; easing.type: Easing.OutQuart }
        }

        delegate: Item {
            id: banner
            required property int index
            required property var model
            readonly property var n: root.present ? Notifications.get(model.id) : null
            width: list.width
            height: index < root.shown ? card.height : 0
            visible: index < root.shown
            z: -index

            Rectangle {
                id: card
                width: parent.width
                height: Math.max(68, body.implicitHeight + 28)
                radius: 22
                color: "#fa26262a"
                border { width: 1; color: "#26ffffff" }
                // Follows the finger up, and springs back unless it went far
                // enough or fast enough.
                y: drag.active ? Math.min(0, drag.activeTranslation.y) : 0
                Behavior on y { enabled: !drag.active; NumberAnimation { duration: 260; easing.type: Easing.OutQuart } }
                scale: press.pressed ? 0.98 : 1
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                Image {
                    id: picture
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    height: 40
                    source: banner.model.image || banner.model.icon
                    sourceSize.width: 80
                    sourceSize.height: 80
                    fillMode: Image.PreserveAspectFit
                }

                Column {
                    id: body
                    anchors.left: picture.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Row {
                        width: parent.width
                        Text {
                            width: parent.width - when.width
                            text: banner.model.summary
                            textFormat: Text.PlainText
                            color: "white"
                            font { pixelSize: 15; weight: Font.DemiBold }
                            elide: Text.ElideRight
                        }
                        Text {
                            id: when
                            text: "now"
                            color: "#99ffffff"
                            font.pixelSize: 13
                        }
                    }
                    Text {
                        width: parent.width
                        visible: text.length > 0
                        text: banner.model.bodyRich
                        textFormat: Text.StyledText
                        color: "#d9ffffff"
                        linkColor: "#64a8ff"
                        font.pixelSize: 14
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        visible: banner.model.appName.length > 0
                        text: banner.model.appName
                        textFormat: Text.PlainText
                        color: "#80ffffff"
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }

                // A finger, the pointer or a pull resting on it stops its
                // time. One state for all three: Solium's hold is a flag, not
                // a count, so a press let go under a resting pointer must not
                // release it.
                readonly property bool holding: press.pressed || hover.hovered || drag.active
                onHoldingChanged: {
                    if (!banner.n) return
                    if (holding) banner.n.hold(); else banner.n.release()
                }
                TapHandler {
                    id: press
                    onTapped: if (banner.n && banner.model.hasDefault) banner.n.invoke("default")
                }
                HoverHandler { id: hover }
                DragHandler {
                    id: drag
                    target: null
                    xAxis.enabled: false
                    // How far it went, kept past the release that ends it.
                    property real pulled: 0
                    onActiveTranslationChanged: if (active) pulled = activeTranslation.y
                    onActiveChanged: {
                        if (banner.n && !active && (pulled < -36 || centroid.velocity.y < -500))
                            banner.n.dismiss()
                    }
                }
            }
        }
    }
}
