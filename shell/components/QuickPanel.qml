import QtQuick
import qs.tokens
import "../logic/acrylic.mjs" as Acrylic
import "../logic/curve.mjs" as Curve
import "../logic/tray.mjs" as Tray
import "../logic/volume.mjs" as Volume
import "../logic/glyphs.mjs" as Glyphs

Item {
    id: root

    property string page: "main"
    property real level: 0
    property bool muted: false
    property var outputs: []
    property var apps: []
    property var icon: names => ""
    readonly property bool resizing: growing.running
    readonly property int mainHeight: 2 * Metrics.quickPaddingTop + Metrics.quickRow + Metrics.soundFooter
    readonly property int soundHeight: Volume.soundHeight(outputs.length, apps.length, Metrics)
    readonly property int edge: Metrics.quickPaddingX - 4
    readonly property var fill: Acrylic.fill({
        tint: [Colors.flyoutTint.r, Colors.flyoutTint.g, Colors.flyoutTint.b],
        luminosityOpacity: Colors.flyoutLuminosityOpacity,
    })

    signal moved(real value)
    signal muteAsked(bool silent)
    signal chosen(int id)
    signal appMoved(var ids, real value)

    function reset() {
        page = "main"
    }

    width: Metrics.quickWidth
    height: page === "main" ? mainHeight : soundHeight
    clip: true

    Behavior on height {
        NumberAnimation {
            id: growing
            duration: Motion.pageSlide
            easing.bezierCurve: Curve.easing(Motion.curveDecelerate)
        }
    }

    component GlyphButton: StartButton {
        property string glyph
        width: Metrics.quickButton
        height: Metrics.quickButton

        Text {
            anchors.centerIn: parent
            text: parent.glyph
            color: Colors.textPrimary
            font.family: Type.iconFamily
            font.pixelSize: Metrics.trayGlyphSize
        }
    }

    component Label: Text {
        color: Colors.textPrimary
        font.family: Type.family
        font.pixelSize: Type.body.size
        renderType: Text.NativeRendering
    }

    component Footer: Rectangle {
        y: parent.height - height
        width: parent.width
        height: Metrics.soundFooter
        color: Colors.footerBand

        Rectangle {
            width: parent.width
            height: 1
            color: Colors.divider
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

    Item {
        id: pages
        objectName: "pages"
        property alias sliding: sliding
        readonly property bool moving: sliding.running
        x: root.page === "main" ? 0 : -root.width
        width: 2 * root.width
        height: parent.height

        Behavior on x {
            NumberAnimation {
                id: sliding
                duration: Motion.pageSlide
                easing.bezierCurve: Curve.easing(Motion.curveDecelerate)
            }
        }

        Item {
            objectName: "main"
            width: root.width
            height: root.mainHeight

            GlyphButton {
                objectName: "mute"
                x: root.edge
                y: Metrics.quickPaddingTop + (Metrics.quickRow - height) / 2
                glyph: Tray.volume(root.level, root.muted)
                onClicked: root.muteAsked(!root.muted)
            }

            VolumeSlider {
                objectName: "level"
                x: root.edge + Metrics.quickButton
                y: Metrics.quickPaddingTop + (Metrics.quickRow - height) / 2
                width: root.width - 2 * root.edge - 2 * Metrics.quickButton
                value: root.level
                onMoved: value => root.moved(value)
            }

            GlyphButton {
                objectName: "more"
                x: root.width - root.edge - width
                y: Metrics.quickPaddingTop + (Metrics.quickRow - height) / 2
                glyph: Glyphs.glyph("more")
                onClicked: root.page = "sound"
            }

            Footer {}
        }

        Item {
            objectName: "sound"
            x: root.width
            width: root.width
            height: root.soundHeight

            GlyphButton {
                objectName: "back"
                x: Metrics.soundBackX
                y: (Metrics.soundHeader - height) / 2
                width: 32
                height: 32
                glyph: Glyphs.glyph("back")
                onClicked: root.page = "main"
            }

            Label {
                objectName: "title"
                x: Metrics.soundTitleX
                height: Metrics.soundHeader
                verticalAlignment: Text.AlignVCenter
                text: "Sound output"
            }

            Column {
                y: Metrics.soundHeader
                width: parent.width

                Label {
                    objectName: "outputsHeader"
                    x: Metrics.soundTextX
                    height: Metrics.soundSection
                    verticalAlignment: Text.AlignVCenter
                    text: "Output device"
                    font.weight: Type.bodyStrong.weight
                }

                Repeater {
                    model: root.outputs

                    StartButton {
                        required property var modelData
                        objectName: "output:" + modelData.id
                        x: Metrics.soundInsetX
                        width: root.width - 2 * Metrics.soundInsetX
                        height: Metrics.soundRow
                        onClicked: root.chosen(modelData.id)

                        Rectangle {
                            anchors.fill: parent
                            radius: Metrics.buttonRadius
                            color: Colors.itemFillSecondary
                            visible: modelData.selected
                        }

                        Rectangle {
                            objectName: "pill"
                            visible: modelData.selected
                            y: (parent.height - height) / 2
                            width: Metrics.soundPillWidth
                            height: Metrics.soundPillHeight
                            radius: width / 2
                            color: Colors.accentLight2
                        }

                        Text {
                            x: Metrics.soundRowIconX - Metrics.soundInsetX
                            anchors.verticalCenter: parent.verticalCenter
                            text: Glyphs.glyph("speakers")
                            color: Colors.textPrimary
                            font.family: Type.iconFamily
                            font.pixelSize: Metrics.trayGlyphSize
                        }

                        Label {
                            objectName: "label"
                            x: Metrics.soundRowTextX - Metrics.soundInsetX
                            width: parent.width - x - Metrics.soundTextX
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: modelData.label
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: Metrics.soundDivider

                    Rectangle {
                        y: (parent.height - height) / 2
                        width: parent.width
                        height: 1
                        color: Colors.divider
                    }
                }

                Item {
                    width: parent.width
                    height: Metrics.soundSection

                    Label {
                        objectName: "mixerHeader"
                        x: Metrics.soundTextX
                        height: parent.height
                        verticalAlignment: Text.AlignVCenter
                        text: "Volume mixer"
                        font.weight: Type.bodyStrong.weight
                    }
                }

                Repeater {
                    model: root.apps

                    Item {
                        required property var modelData
                        objectName: "app:" + modelData.key
                        width: root.width
                        height: Metrics.soundAppRow

                        Image {
                            objectName: "icon"
                            x: Metrics.soundAppIconX
                            anchors.verticalCenter: parent.verticalCenter
                            width: Metrics.soundAppIcon
                            height: Metrics.soundAppIcon
                            sourceSize: Qt.size(width, height)
                            source: root.icon(modelData.icons)
                        }

                        VolumeSlider {
                            objectName: "slider"
                            x: Metrics.soundSliderX
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.width - Metrics.soundSliderX - Metrics.soundSliderRight
                            value: modelData.volume
                            onMoved: value => root.appMoved(modelData.ids, value)
                        }
                    }
                }
            }

            Footer {}
        }
    }
}
