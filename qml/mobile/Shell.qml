import QtQuick
import "../icons.js" as Icons
import QtQml.Models
import Solium

Item {
    id: root
    // One file, two surfaces: "home" is the icon grid, drawn below windows so
    // a window dragged home stays in front of it; "chrome" is everything else,
    // drawn above windows.
    property string part: "chrome"
    readonly property bool home: part === "home"
    property bool gestureActive: false
    // The launcher slot whose window is flying to or from it (policy.lua's
    // start_flight): empty while the pane stands in for its icon, for
    // `emptiedMs` from each new flight.
    property string emptiedKey: ""
    property int emptiedSerial: 0
    property int emptiedMs: 0
    property bool emptying: false
    // The window in the finger's hand while it swipes up from an app: the
    // icon it will become, so its slot is empty for the whole drag.
    property string draggedKey: ""
    onEmptiedSerialChanged: { emptying = emptiedKey !== ""; emptiedTimer.restart() }
    Timer { id: emptiedTimer; interval: Math.max(1, root.emptiedMs); onTriggered: root.emptying = false }
    property real navigationProgress: 0
    property string page: "home"
    property string shadeBackground: "home"
    property bool tablet: false
    property var cards: []
    property int taskCount: 0
    property int activeId: 0
    property bool splitActive: false
    property bool pickingSplit: false
    property int statusHeight: 32
    property int navigationHeight: 36
    property real brightness: 1
    property bool darkAppearance: false
    property bool reduceMotion: false
    property var installed: []
    property int homeRequest: 0
    property var iconItems: []
    function registerIcon(tile) { iconItems.push(tile); Qt.callLater(reportIcons) }
    function unregisterIcon(tile) { iconItems = iconItems.filter(item => item !== tile) }
    function reportIcons() {
        if (!home || (page !== "home" && page !== "apps")) return
        let icons = {}
        for (const tile of iconItems) {
            const r = tile.iconRect()
            if (tile.appKey && r.x >= 0 && r.y >= 0 && r.x + r.size <= width + 1 && r.y + r.size <= height + 1)
                icons[tile.appKey] = r
        }
        send("icons", { epoch: homeRequest, w: width, h: height, items: icons })
    }
    onHomeRequestChanged: Qt.callLater(reportIcons)
    onWidthChanged: Qt.callLater(reportIcons)
    onHeightChanged: Qt.callLater(reportIcons)
    readonly property string underneath: page === "shade" ? shadeBackground : page
    readonly property int columns: tablet ? Math.max(6, Math.floor(width / 112)) : 4
    readonly property int rows: Math.max(1, Math.min(tablet ? 5 : 6, Math.floor((height - 160) / 106)))
    readonly property int capacity: columns * rows
    // Only what is installed: the grid is the desktop's own applications.
    readonly property var launchEntries: installed
    readonly property int pageCount: Math.max(1, Math.ceil(launchEntries.length / capacity))
    // The Recents dock: a few applications by their desktop id, in this order,
    // those that are installed.
    property var dockIds: ["org.kde.dolphin", "org.kde.konsole", "org.kde.elisa", "org.kde.gwenview"]
    readonly property var dockEntries: dockIds.map(id => installed.find(entry => entry.desktopId === id))
        .filter(entry => entry !== undefined)
    function send(action, data) { Solium.send("mobile." + action, data || {}) }
    function launch(entry, origin) {
        send("desktop", { id: entry.desktopId, origin: origin })
    }
    function refreshApps() {
        let entries = []
        for (let i = 0; i < appIndex.count; ++i) {
            const app = appIndex.objectAt(i)
            if (app && app.present) entries.push({ name: app.appName, desktopId: app.desktopId,
                glyph: app.appName.slice(0, 1), icon: app.iconName, tone: "#576c9e" })
        }
        installed = entries
        if (desktops.currentIndex >= pageCount) desktops.currentIndex = pageCount - 1
    }
    Instantiator {
        id: appIndex
        model: root.home ? Apps : null
        delegate: QtObject {
            required property var model
            readonly property string appName: model.name
            readonly property string desktopId: model.id
            readonly property string iconName: model.icon
            readonly property bool present: model.present
            onAppNameChanged: Qt.callLater(root.refreshApps)
            onDesktopIdChanged: Qt.callLater(root.refreshApps)
            onIconNameChanged: Qt.callLater(root.refreshApps)
            onPresentChanged: Qt.callLater(root.refreshApps)
        }
        onObjectAdded: Qt.callLater(root.refreshApps)
        onObjectRemoved: Qt.callLater(root.refreshApps)
    }
    focus: !home && page !== "app"
    Solium.keyboard.wants: !home && page !== "app"
    Solium.keyboard.claims: ["Escape"]
    Keys.onEscapePressed: root.send("back")

    Item {
        id: launcher
        anchors { top: parent.top; topMargin: root.statusHeight; bottom: parent.bottom; bottomMargin: root.navigationHeight; left: parent.left; right: parent.right }
        opacity: root.underneath === "home" || root.underneath === "apps" ? 1 : root.navigationProgress
        visible: root.home && opacity > 0.001
        enabled: root.page === "home" || root.page === "apps"
        scale: 1 // Icon targets stay in layout space throughout Home fade.
        Behavior on opacity { enabled: !root.gestureActive; NumberAnimation { duration: root.reduceMotion ? 0 : 280; easing.type: Easing.OutCubic } }
        ListView {
            id: desktops
            interactive: false
            anchors { fill: parent; topMargin: 28; bottomMargin: 44 }
            orientation: ListView.Horizontal
            snapMode: ListView.SnapOneItem
            boundsBehavior: Flickable.StopAtBounds
            maximumFlickVelocity: 1800
            clip: true
            model: root.pageCount
            onCurrentIndexChanged: Qt.callLater(root.reportIcons)
            onMovementEnded: { currentIndex = Math.round(contentX / Math.max(1, width)); Qt.callLater(root.reportIcons) }
            delegate: Item {
                required property int index
                width: desktops.width; height: desktops.height
                Grid {
                    anchors { top: parent.top; left: parent.left; right: parent.right; margins: root.tablet ? 36 : 12 }
                    columns: root.columns
                    Repeater {
                        model: root.launchEntries.slice(index * root.capacity, (index + 1) * root.capacity)
                        Item {
                            required property var modelData
                            width: (desktops.width - (root.tablet ? 72 : 24)) / root.columns
                            height: Math.min(112, desktops.height / root.rows)
                            AppTile {
                                id: appTile
                                appKey: modelData.desktopId || ""
                                readonly property string bareKey: appKey.replace(/\.desktop$/, "")
                                artHidden: (root.emptying && bareKey === root.emptiedKey)
                                    || (root.draggedKey !== "" && bareKey === root.draggedKey)
                                Component.onCompleted: root.registerIcon(appTile)
                                Component.onDestruction: root.unregisterIcon(appTile)
                                anchors.horizontalCenter: parent.horizontalCenter
                                title: modelData.name; glyph: modelData.glyph; tone: modelData.tone
                                imageSource: Icons.source(modelData.icon, 60)
                                onTriggered: origin => root.launch(modelData, origin)
                            }
                        }
                    }
                }
            }
            MouseArea {
                anchors.fill: parent; acceptedButtons: Qt.NoButton
                onWheel: wheel => {
                    const d = wheel.angleDelta.x || wheel.angleDelta.y
                    if (d) desktops.currentIndex = Math.max(0, Math.min(root.pageCount - 1, desktops.currentIndex + (d < 0 ? 1 : -1)))
                }
            }
        }
        Row {
            anchors { bottom: parent.bottom; bottomMargin: 16; horizontalCenter: parent.horizontalCenter }
            spacing: 8
            Repeater {
                model: root.pageCount
                Rectangle {
                    required property int index
                    width: 6; height: 6; radius: 3
                    color: index === Math.round(desktops.contentX / Math.max(1, desktops.width)) ? "white" : "#65ffffff"
                    MouseArea { anchors { fill: parent; margins: -9 } onClicked: desktops.currentIndex = index }
                }
            }
        }
    }

    Item {
        id: chrome
        anchors.fill: parent
        visible: !root.home
        // Raw touch recognition lives in Lua; QML displays real-pane controls.
        Item {
            anchors.fill: parent
            visible: root.page === "recents" && root.taskCount === 0
            Text { anchors.centerIn: parent; text: "No recent apps"; color: "white"; font.pixelSize: 24 }
        }

        Rectangle {
            id: overviewDock
            visible: root.tablet && root.underneath === "recents"
            enabled: root.page === "recents"
            width: Math.min(root.width - 64, 420); height: 92; radius: 27
            anchors { horizontalCenter: parent.horizontalCenter; bottom: navigation.top; bottomMargin: 14 }
            color: "#4affffff"; border { width: 1; color: "#30ffffff" }
            Row {
                anchors.centerIn: parent; spacing: 14
                Repeater {
                    model: root.dockEntries
                    AppTile {
                        required property var modelData
                        width: 70; height: 60; showTitle: false
                        appKey: modelData.desktopId
                        title: modelData.name; glyph: modelData.glyph; tone: modelData.tone
                        imageSource: Icons.source(modelData.icon, 60)
                        onTriggered: origin => root.launch(modelData, origin)
                    }
                }
            }
        }
        Rectangle {
            id: status
            width: parent.width; height: root.statusHeight
            color: root.underneath === "app" ? "#13151c" : "transparent"
            // The clock on the left and the Wi-Fi and battery on the right are
            // the Control Center's (ControlCenter.qml): drawn above this bar,
            // the clock fades and the status icons travel as it comes down.
            MouseArea {
                anchors.fill: parent
                onClicked: root.send("shade")
            }
        }

        Rectangle {
            anchors.fill: parent; color: "black"; opacity: (1 - root.brightness) * 0.7
            // Visual dimming only; no input item, so it never intercepts a client.
        }
        Rectangle {
            id: navigation
            visible: root.navigationHeight > 0
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: root.navigationHeight
            color: root.page === "app" ? "#13151c" : "#14000000"
            Row {
                visible: root.page === "app" && root.splitActive
                anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter } spacing: 8
                ActionButton { width: 38; height: 30; symbol: "↔"; onTriggered: root.send("ratio") }
                ActionButton { width: 38; height: 30; symbol: "▣"; onTriggered: root.send("unsplit") }
            }
            Row {
                anchors.centerIn: parent; spacing: root.tablet ? 44 : 32
                ActionButton { width: 52; height: 34; symbol: "‹"; fill: "transparent"; Accessible.name: "Back"; onTriggered: root.send("back") }
                ActionButton { width: 52; height: 34; symbol: "○"; fill: "transparent"; Accessible.name: "Home"; onTriggered: root.send("home") }
                ActionButton { width: 52; height: 34; symbol: "▢"; fill: "transparent"; Accessible.name: "App switcher"; onTriggered: root.send("recents") }
            }
        }
    }
}
