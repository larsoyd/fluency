import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.tokens
import qs.components
import qs.services
import "../logic/desktop.mjs" as Logic

PanelWindow {
    id: root

    property alias grid: grid
    readonly property var flyout: context.flyout
    property alias context: context
    property var targets: []
    property bool holding: false
    property bool grabbing: false
    readonly property var launches: ["open", "terminal", "location"]
    property point spot: Qt.point(-1, -1)

    function showMenu(names: var, x: real, y: real): void {
        targets = names
        spot = Qt.point(x, y)
        if (!names.length) Desktop.probe()
        const subs = { view: Logic.viewMenu(Desktop.settings), sort: Logic.sortMenu(), new: Logic.newMenu() }
        flyout.show(rows(), subs, x, y)
    }

    function rows(): var {
        if (!targets.length) return Logic.desktopMenu({ paste: Desktop.pasteable })
        return Logic.itemMenu(targets.map(name => Desktop.items.find(item => item.name === name)).filter(item => item), Apps.pins)
    }

    // new windows get no focus while a layer holds the keys
    // taking the keys lets go of every button, the release takes them instead
    function hold(): void {
        if (grid.pressing) return
        holding = true
        grabbing = true
        grid.forceActiveFocus()
    }

    function letGo(): void {
        holding = false
        grabbing = false
    }

    function pick(action: string): string {
        if (launches.includes(action)) letGo()
        else hold()
        const said = Desktop.act(action, targets, spot.x, spot.y)
        if (launches.includes(action) || action === "delete") grid.clear()
        return said
    }

    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Normal
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "fluency-desktop"
    // exclusive for one frame takes the keyboard, on demand then gives the pointer back
    WlrLayershell.keyboardFocus: !holding ? WlrKeyboardFocus.None : grabbing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

    DesktopGrid {
        id: grid
        objectName: "desktop"
        anchors.fill: parent
        items: Desktop.items
        settings: Desktop.settings
        places: Desktop.settings.places
        cut: Desktop.cut
        active: activeFocus || editing !== ""
        onOpened: names => {
            root.letGo()
            Desktop.act("open", names, -1, -1)
        }
        // the release still counts as pressed while its handler runs
        onTouched: Qt.callLater(root.hold)
        onActiveFocusChanged: if (!activeFocus && editing === "" && !root.grabbing && !root.flyout.open) root.letGo()
        onMenu: (names, x, y) => root.showMenu(names, x, y)
        onMoved: (places, order) => Desktop.place(places, order)
        onKeyed: action => {
            Desktop.act(action, action === "rename" ? [focusName()] : selected, -1, -1)
            if (action === "delete") clear()
        }
        onDropped: (names, folder) => {
            Desktop.act("into:" + folder, names, -1, -1)
            clear()
        }
        onRenamed: (name, text) => Desktop.rename(name, text)
    }

    // a new item shows up a moment after the file is made
    Timer {
        property int tries: 0
        interval: 50
        repeat: true
        running: Desktop.renaming !== ""
        onRunningChanged: tries = 0
        onTriggered: {
            if (grid.items.some(item => item.name === Desktop.renaming)) {
                root.hold()
                grid.choose(Desktop.renaming, {})
                grid.edit(Desktop.renaming)
                Desktop.renaming = ""
            } else if (++tries > 40) {
                console.log(`[desktop] action=rename name="${Desktop.renaming}" result="refused: it never showed up"`)
                Desktop.renaming = ""
            }
        }
    }

    FrameAnimation {
        running: root.grabbing
        onTriggered: if (currentFrame > 1) root.grabbing = false
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "openwindow" && root.holding) root.letGo()
        }
    }

    Connections {
        target: Desktop
        function onRenamed(from, to) { grid.rename(from, to) }
        function onPasteableChanged() {
            if (flyout.open && !root.targets.length) flyout.rows = root.rows()
        }
    }

    // menus stay above the bar, the work area ends there
    Binding {
        target: root.flyout
        property: "area"
        value: Qt.size(root.width, root.height)
    }

    ContextMenu {
        id: context
        screen: root.screen
        onPicked: action => root.pick(action)
        onDismissed: root.hold()
    }
}
