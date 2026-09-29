import QtQuick
import qs.tokens
import "../logic/plate.mjs" as Logic

Item {
    id: root

    property bool active: false
    property bool hovered: false
    property bool pressed: false
    property bool attention: false
    property bool multi: false
    property bool tray: false
    property bool checked: false
    property int radius: Metrics.buttonRadius
    property alias fadeDuration: fade.duration
    readonly property var look: Logic.look(Logic.state({ active, hovered, pressed, attention, multi, tray, checked }), Colors)

    onLookChanged: stroke.requestPaint()
    onRadiusChanged: stroke.requestPaint()

    Rectangle {
        objectName: "fill"
        anchors.fill: parent
        anchors.margins: Metrics.buttonOutline
        radius: root.radius - Metrics.buttonOutline
        color: root.look.fill

        Behavior on color {
            ColorAnimation { id: fade; duration: Motion.plateFade }
        }
    }

    Canvas {
        id: stroke
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d"), half = Metrics.buttonOutline / 2
            ctx.clearRect(0, 0, width, height)
            if (root.look.strokeTop.a === 0 && root.look.strokeBottom.a === 0) return
            const fade = ctx.createLinearGradient(0, 0, 0, Metrics.strokeGradientExtent)
            fade.addColorStop(Metrics.strokeGradientStart, root.look.strokeTop)
            fade.addColorStop(1, root.look.strokeBottom)
            ctx.strokeStyle = fade
            ctx.lineWidth = Metrics.buttonOutline
            ctx.beginPath()
            ctx.roundedRect(half, half, width - 2 * half, height - 2 * half,
                            root.radius - half, root.radius - half)
            ctx.stroke()
        }
    }
}
