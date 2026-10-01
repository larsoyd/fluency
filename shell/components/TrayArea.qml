import QtQuick
import qs.tokens

Item {
    id: root

    property bool full: true
    property var icons: []
    property int hidden: 0
    property bool open: false
    property bool quickOpen: false
    property bool notifyOpen: false
    property var glyphs: []
    property string time: ""
    property string date: ""

    signal toggled()
    signal pressed(string id, string input, real x, real y)
    signal scrolled(string id, int delta)
    signal asked(string name)
    signal turned(int delta)

    width: row.width
    height: Metrics.taskbarHeight

    Slots {
        id: slots
        items: root.icons
    }

    Row {
        id: row
        objectName: "row"
        height: parent.height

        Chevron {
            objectName: "chevron"
            visible: root.full && root.hidden > 0
            checked: root.open
            onClicked: root.toggled()
        }

        Repeater {
            model: slots

            TrayIcon {
                required property string key
                objectName: "icon:" + key
                visible: root.full
                source: slots.byKey[key].icon
                onClicked: root.pressed(key, "click", x + pointer.x, pointer.y)
                onMiddleClicked: root.pressed(key, "middle", x + pointer.x, pointer.y)
                onMenuRequested: root.pressed(key, "menu", x + pointer.x, pointer.y)
                onScrolled: delta => root.scrolled(key, delta)
            }
        }

        StatusButton {
            objectName: "status"
            visible: root.full && root.glyphs.length > 0
            glyphs: root.glyphs
            checked: root.quickOpen
            onClicked: root.asked("status")
            onScrolled: delta => root.turned(delta)
        }

        ClockButton {
            objectName: "clock"
            time: root.time
            date: root.date
            checked: root.notifyOpen
            onClicked: root.asked("clock")
        }

        ShowDesktop {
            objectName: "desktop"
            visible: root.full
            onClicked: root.asked("desktop")
        }
    }
}
