import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.tokens
import qs.components
import qs.services
import "../logic/curve.mjs" as Curve
import "../logic/apps.mjs" as AppLogic

PanelWindow {
    id: root

    property bool open: false
    property real shift: 1
    property bool grabbing: false
    property alias sliding: sliding
    property string asked: ""
    readonly property int reach: panel.height + Metrics.flyoutOffset

    function choose(menu: var, index: int): string {
        const row = menu.rows[index]
        if (!row) return `refused: no row ${index}`
        if (menu === appMenu) {
            appMenu.open = false
            return pin(row.action, asked)
        }
        open = false
        return Session.run(row.action)
    }

    function pin(action: string, id: string): string {
        return action.endsWith("-taskbar") ? Windows.pin(action.slice(0, -"-taskbar".length), id) : Apps.pin(action, id)
    }

    // the menu opens at the pointer and flips up when it would leave the panel
    function ask(id: string, tile: bool, at: point): void {
        powerMenu.open = userMenu.open = false
        asked = id
        appMenu.rows = AppLogic.menu(id, tile, Apps.pins, Windows.pinned).map(row => Object.assign({ kind: "item", enabled: true }, row))
        appMenu.x = Math.min(at.x, panel.width - appMenu.width)
        appMenu.y = panel.y + (at.y + appMenu.height > panel.height ? at.y - appMenu.height : at.y)
        appMenu.open = true
    }

    function launch(id: string): string {
        open = false
        return Apps.launch(id)
    }

    visible: open || shift < 1
    anchors { left: true; bottom: true }
    margins.left: Math.round((screen.width - panel.width) / 2)
    implicitWidth: panel.width
    implicitHeight: reach
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "fluency-start"
    // map exclusive for the keyboard, then on demand gives the pointer back
    WlrLayershell.keyboardFocus: !open ? WlrKeyboardFocus.None : grabbing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

    // set here, a binding on open could still hold the other direction when shift moves
    onOpenChanged: {
        sliding.duration = Motion.calmed(open ? Motion.startOpen : Motion.startClose)
        sliding.easing.bezierCurve = Curve.easing(open ? Motion.curveDecelerate : Motion.curveStartClose)
        shift = open ? 0 : 1
        powerMenu.open = userMenu.open = appMenu.open = false
        if (open) {
            panel.query = ""
            panel.typing = false
            panel.forceActiveFocus()
            grabbing = true
        }
    }

    // the next frame after the map
    FrameAnimation {
        running: root.grabbing
        onTriggered: if (currentFrame > 1) root.grabbing = false
    }

    Behavior on shift {
        // the box takes focus after the slide, its first focus costs a frame
        NumberAnimation {
            id: sliding
            onRunningChanged: if (!running && root.open) panel.typing = true
        }
    }

    Item {
        objectName: "startmenu"
        anchors.fill: parent
        clip: true

        StartPanel {
            id: panel
            objectName: "panel"
            y: root.shift * root.reach
            userName: Session.name
            avatar: Session.avatar
            entries: Apps.entries
            pins: Apps.pins
            onLaunched: id => root.launch(id)
            onDismissed: root.open = false
            onPowerAsked: powerMenu.open = !powerMenu.open
            onUserAsked: userMenu.open = !userMenu.open
            onAppAsked: (id, tile, at) => root.ask(id, tile, at)
        }

        // a click beside an open menu only closes it
        MouseArea {
            anchors.fill: panel
            enabled: powerMenu.open || userMenu.open || appMenu.open
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: powerMenu.open = userMenu.open = appMenu.open = false
        }

        MenuFlyout {
            id: powerMenu
            objectName: "powerMenu"
            rows: Session.powerRows
            x: Math.min(panel.power.x + (panel.power.width - width) / 2, panel.width - width)
            y: panel.y + panel.power.y - height
            onChosen: index => root.choose(powerMenu, index)
        }

        MenuFlyout {
            id: userMenu
            objectName: "userMenu"
            rows: Session.userRows
            x: panel.user.x
            y: panel.y + panel.user.y - height
            onChosen: index => root.choose(userMenu, index)
        }

        MenuFlyout {
            id: appMenu
            objectName: "appMenu"
            onChosen: index => root.choose(appMenu, index)
        }
    }
}
