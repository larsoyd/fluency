pragma Singleton
import QtQuick
import "../logic/fonts.mjs" as Fonts

QtObject {
    readonly property var families: ["Hind", "Noto Sans"]
    readonly property var iconFamilies: ["FluentSystemIcons-Regular"]
    readonly property string family: Fonts.firstAvailable(families, Qt.fontFamilies())
    readonly property string iconFamily: Fonts.firstAvailable(iconFamilies, Qt.fontFamilies())

    readonly property real scale: Fonts.scale(family)
    readonly property var caption: style(12, 16, 400)
    readonly property var body: style(14, 20, 400)
    readonly property var bodyStrong: style(14, 20, 600)
    readonly property var subtitle: style(20, 28, 600)

    // design is the fluent ramp, size is what the shell draws in its own font
    function style(design, lineHeight, weight) {
        return { design, size: Math.round(design * scale), lineHeight, weight }
    }
}
