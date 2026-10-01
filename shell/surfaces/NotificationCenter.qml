import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.tokens
import qs.components
import qs.services
import "../logic/curve.mjs" as Curve
import "../logic/notify.mjs" as Notify
import "../logic/toast.mjs" as Words

// both cards come in from the edge of the screen together
PanelWindow {
    id: root

    property bool open: false
    property real shift: 1
    property bool grabbing: false
    property alias sliding: sliding
    property alias panel: panel
    property alias calendar: calendar
    readonly property int reach: Metrics.notifyWidth + Metrics.flyoutOffset

    visible: open || shift < 1
    anchors { right: true; bottom: true }
    implicitWidth: reach
    implicitHeight: panel.height + calendar.height + 2 * Metrics.flyoutOffset
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "fluency-notify"
    WlrLayershell.keyboardFocus: !open ? WlrKeyboardFocus.None : grabbing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

    onOpenChanged: {
        sliding.duration = Motion.calmed(open ? Motion.notifyOpen : Motion.notifyClose)
        sliding.easing.bezierCurve = Curve.easing(open ? Motion.curveDecelerate : Motion.curveAccelerate)
        shift = open ? 0 : 1
        if (!open) return
        calendar.reset()
        cards.forceActiveFocus()
        grabbing = true
    }

    FrameAnimation {
        running: root.grabbing
        onTriggered: if (currentFrame > 1) root.grabbing = false
    }

    Behavior on shift {
        NumberAnimation { id: sliding }
    }

    Item {
        id: cards
        objectName: "notify"
        anchors.fill: parent
        clip: true
        Keys.onEscapePressed: root.open = false

        Item {
            x: root.shift * root.reach
            width: Metrics.notifyWidth
            height: parent.height
            opacity: root.open ? 1 : 1 - root.shift

            NotificationPanel {
                id: panel
                objectName: "panel"
                groups: Notify.groups(Notifications.history)
                dnd: Notifications.dnd
                maxHeight: root.screen.height - Metrics.taskbarHeight - 3 * Metrics.flyoutOffset - calendar.height
                iconOf: n => Words.source(n, name => Quickshell.iconPath(name, "application-x-executable"))
                onActivated: n => Notifications.activate(n)
                onDismissed: n => Notifications.dismiss(n)
                onInvoked: (n, id) => Notifications.invoke(n, id)
                onCleared: Notifications.clear()
                onClearedApp: app => Notifications.clearApp(app)
                onDndToggled: Notifications.setDnd(!Notifications.dnd)
            }

            CalendarCard {
                id: calendar
                objectName: "calendar"
                y: panel.height + Metrics.flyoutOffset
                now: Clock.now
            }
        }
    }
}
