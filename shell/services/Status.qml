pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Services.Pipewire
import "../logic/tray.mjs" as Logic
import "../logic/volume.mjs" as Volume

Singleton {
    id: root

    readonly property string network: Logic.link(Networking.devices.values.map(device => ({
        kind: ["none", "wifi", "wired"][device.type],
        connected: device.connected,
    })))
    readonly property real volume: Pipewire.defaultAudioSink?.audio?.volume ?? 0
    readonly property bool muted: Pipewire.defaultAudioSink?.audio?.muted ?? true
    readonly property int sink: Pipewire.defaultAudioSink?.id ?? -1
    readonly property bool ready: Pipewire.ready && (Pipewire.defaultAudioSink?.ready ?? false)
    readonly property var audio: Pipewire.nodes.values.filter(node => node.audio && node.isSink)
    readonly property var nodes: audio.map(node => ({
        id: node.id,
        kind: node.isStream ? "stream" : "sink",
        description: node.description,
        nickname: node.nickname,
        name: node.name,
        app: node.properties["application.name"] ?? "",
        icon: node.properties["application.icon-name"] ?? "",
        binary: node.properties["application.process.binary"] ?? "",
        volume: node.audio.volume,
        muted: node.audio.muted,
    }))

    function node(id: int): var {
        return audio.find(node => node.id === id) ?? null
    }

    function setVolume(level: real): void {
        if (Pipewire.defaultAudioSink?.audio) Pipewire.defaultAudioSink.audio.volume = Volume.clamp(level)
    }

    function setMuted(silent: bool): void {
        if (Pipewire.defaultAudioSink?.audio) Pipewire.defaultAudioSink.audio.muted = silent
    }

    function choose(id: int): string {
        const found = node(id)
        const result = found && !found.isStream ? "ok" : `refused: no output ${id}`
        if (result === "ok") Pipewire.preferredDefaultAudioSink = found
        console.log(`[audio] action=choose id=${id} result="${result}"`)
        return result
    }

    function setApp(ids: var, level: real): void {
        for (const id of ids) {
            const found = node(id)
            if (found?.isStream) found.audio.volume = Volume.clamp(level)
        }
    }

    function muteApp(ids: var, silent: bool): void {
        for (const id of ids) {
            const found = node(id)
            if (found?.isStream) found.audio.muted = silent
        }
    }

    // volume and mute read as nothing until the node is tracked
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, ...root.audio]
    }
}
