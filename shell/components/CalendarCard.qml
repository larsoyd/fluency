import QtQuick
import qs.tokens
import "../logic/glyphs.mjs" as Glyphs
import "../logic/acrylic.mjs" as Acrylic
import "../logic/calendar.mjs" as Calendar
import "../logic/curve.mjs" as Curve

Item {
    id: root

    property date now: new Date()
    property int firstDay: Qt.locale().firstDayOfWeek % 7
    property bool collapsed: false
    property int year: now.getFullYear()
    property int month: now.getMonth()
    readonly property var names: [0, 1, 2, 3, 4, 5, 6].map(day => Qt.locale().dayName(day, Locale.ShortFormat).slice(0, 2))
    readonly property var shown: Calendar.month(year, month, firstDay, now, names)
    readonly property int inset: (width - 7 * Metrics.calendarCell) / 2
    readonly property int body: Metrics.calendarMonthRow + Metrics.calendarWeekRow + 6 * Metrics.calendarCell + Metrics.calendarBottom
    property real open: collapsed ? 0 : 1
    readonly property var fill: Acrylic.fill({
        tint: [Colors.flyoutTint.r, Colors.flyoutTint.g, Colors.flyoutTint.b],
        luminosityOpacity: Colors.flyoutLuminosityOpacity,
    })

    function reset() {
        year = now.getFullYear()
        month = now.getMonth()
    }

    function page(by) {
        const next = Calendar.step(year, month, by)
        year = next.year
        month = next.month
    }

    width: Metrics.notifyWidth
    height: Metrics.notifyHeader + Math.round(open * (1 + body))
    clip: true

    Behavior on open {
        NumberAnimation {
            duration: Motion.calendarFold
            easing.bezierCurve: Curve.easing(Motion.curveDecelerate)
        }
    }

    Rectangle {
        objectName: "backdrop"
        anchors.fill: parent
        radius: Metrics.flyoutRadius
        color: Qt.rgba(root.fill.color[0], root.fill.color[1], root.fill.color[2], root.fill.alpha)
        border.width: Metrics.flyoutBorder
        border.color: Colors.flyoutStroke
    }

    component Label: Text {
        renderType: Text.NativeRendering
        color: Colors.textPrimary
        font.family: Type.family
        font.pixelSize: Type.body.size
    }

    component Glyph: Text {
        signal clicked()
        width: Metrics.toastCloseSize
        height: Metrics.toastCloseSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        renderType: Text.NativeRendering
        color: Colors.textPrimary
        font.family: Type.iconFamily
        font.pixelSize: Type.caption.size

        Rectangle {
            anchors.fill: parent
            z: -1
            radius: Metrics.buttonRadius
            color: press.pressed ? Colors.menuItemPressed : press.containsMouse ? Colors.menuItemHover : "transparent"
        }

        MouseArea {
            id: press
            anchors.fill: parent
            hoverEnabled: true
            onClicked: parent.clicked()
        }
    }

    Item {
        objectName: "header"
        width: parent.width
        height: Metrics.notifyHeader

        Label {
            objectName: "today"
            x: Metrics.toastPadding
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.locale().toString(root.now, "dddd, MMMM d")
            font.weight: Type.bodyStrong.weight
        }

        Glyph {
            objectName: "fold"
            x: parent.width - width - (Metrics.notifyHeader - height) / 2
            anchors.verticalCenter: parent.verticalCenter
            text: Glyphs.glyph(root.collapsed ? "up" : "down")
            onClicked: root.collapsed = !root.collapsed
        }
    }

    Rectangle {
        y: Metrics.notifyHeader
        width: parent.width
        height: 1
        color: Colors.divider
    }

    Item {
        y: Metrics.notifyHeader + 1
        width: parent.width
        height: root.body

        Label {
            objectName: "month"
            x: root.inset + (Metrics.calendarCell - Metrics.calendarDot) / 2
            height: Metrics.calendarMonthRow
            verticalAlignment: Text.AlignVCenter
            text: Qt.locale().toString(new Date(root.year, root.month, 1), "MMMM yyyy")
            font.weight: Type.bodyStrong.weight
        }

        Glyph {
            objectName: "previous"
            x: next.x - width
            y: (Metrics.calendarMonthRow - height) / 2
            text: Glyphs.glyph("up")
            onClicked: root.page(-1)
        }

        Glyph {
            id: next
            objectName: "next"
            x: root.width - root.inset - (Metrics.calendarCell - width) / 2 - width
            y: (Metrics.calendarMonthRow - height) / 2
            text: Glyphs.glyph("down")
            onClicked: root.page(1)
        }

        Repeater {
            model: root.shown.weekdays

            Label {
                required property string modelData
                required property int index
                objectName: `weekday:${index}`
                x: root.inset + index * Metrics.calendarCell
                y: Metrics.calendarMonthRow
                width: Metrics.calendarCell
                height: Metrics.calendarWeekRow
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: modelData
                font.pixelSize: Type.caption.size
            }
        }

        Repeater {
            model: root.shown.cells

            Item {
                id: cell
                required property var modelData
                required property int index
                objectName: `day:${index}`
                x: root.inset + index % 7 * Metrics.calendarCell
                y: Metrics.calendarMonthRow + Metrics.calendarWeekRow + Math.floor(index / 7) * Metrics.calendarCell
                width: Metrics.calendarCell
                height: Metrics.calendarCell

                Rectangle {
                    objectName: "dot"
                    anchors.centerIn: parent
                    width: Metrics.calendarDot
                    height: Metrics.calendarDot
                    radius: width / 2
                    visible: cell.modelData.today || hover.containsMouse
                    color: cell.modelData.today ? Colors.accentLight2 : Colors.menuItemHover
                }

                Label {
                    objectName: "label"
                    anchors.centerIn: parent
                    text: cell.modelData.day
                    color: cell.modelData.today ? Colors.textOnAccent : cell.modelData.inMonth ? Colors.textPrimary : Colors.textDisabled
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                }
            }
        }
    }
}
