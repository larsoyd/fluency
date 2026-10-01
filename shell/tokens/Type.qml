pragma Singleton
import QtQuick
import "../logic/fonts.mjs" as Fonts

QtObject {
    readonly property var families: ["Hind", "Noto Sans"]
    readonly property var iconFamilies: ["FluentSystemIcons-Regular"]
    readonly property string family: Fonts.firstAvailable(families, Qt.fontFamilies())
    readonly property string iconFamily: Fonts.firstAvailable(iconFamilies, Qt.fontFamilies())

    readonly property var caption: ({ size: 12, lineHeight: 16, weight: 400 })
    readonly property var body: ({ size: 14, lineHeight: 20, weight: 400 })
    readonly property var bodyStrong: ({ size: 14, lineHeight: 20, weight: 600 })
    readonly property var subtitle: ({ size: 20, lineHeight: 28, weight: 600 })
}
