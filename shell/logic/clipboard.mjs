import { glyph } from "./glyphs.mjs"

const texts = ["text/plain;charset=utf-8", "UTF8_STRING", "text/plain", "STRING", "TEXT"]
const verbs = ["list", "select", "text", "pin", "unpin", "delete", "clear"]

function names(uris) {
    return uris.split(/\r?\n/).filter(line => line && !line.startsWith("#"))
        .map(uri => uri.startsWith("file://") ? decodeURIComponent(uri.slice(uri.lastIndexOf("/") + 1)) : uri)
}

export function body(entry) {
    if (entry.kind === "files") return names(entry.text).join("\n")
    if (entry.kind === "other") return entry.mimes[0] ?? ""
    return entry.text.replace(/\s+$/, "")
}

export function age(time, now) {
    const minutes = Math.floor((now - time) / 60000)
    if (minutes < 1) return "now"
    if (minutes < 60) return `${minutes}m`
    if (minutes < 24 * 60) return `${Math.floor(minutes / 60)}h`
    return `${Math.floor(minutes / (24 * 60))}d`
}

export function filter(entries, query) {
    const words = query.toLowerCase().split(/\s+/).filter(word => word)
    return entries.filter(entry => {
        const hay = `${body(entry)} ${entry.app}`.toLowerCase()
        return words.every(word => hay.includes(word))
    })
}

export function hasText(entry) {
    return entry.mimes.some(mime => texts.includes(mime))
}

export function step(index, by, count) {
    if (count === 0) return -1
    return Math.max(0, Math.min(count - 1, index + by))
}

// the more button opens these in place of the card
export function actions(entry) {
    return [
        { name: "text", label: "Paste as text", glyph: glyph("pasteText"), enabled: hasText(entry) },
        { name: "delete", label: "Delete", glyph: glyph("delete"), enabled: true },
    ]
}

export function read(line) {
    let message
    try { message = JSON.parse(line) } catch (e) { return { refused: `refused: unreadable line ${line}` } }
    if (message.type === "entries") return { entries: message.entries }
    return { result: message.result, request: message.request }
}

export function request(verb, id) {
    if (!verbs.includes(verb)) throw new Error(`refused: unknown clipboard request ${verb}`)
    return id === undefined ? `${verb}\n` : `${verb} ${id}\n`
}

const terminals = ["kitty", "foot", "footclient", "alacritty", "org.kde.konsole", "org.gnome.terminal", "org.gnome.ptyxis", "com.mitchellh.ghostty", "org.wezfurlong.wezterm", "xterm", "terminator", "tilix"]

function window(address) {
    if (!/^[0-9a-f]+$/.test(address)) throw new Error(`refused: bad window address ${address}`)
    return `"address:0x${address}"`
}

// the window the user copied for gets the keys back, quickshell gives its address without 0x
export function focus(address) {
    return `hl.dsp.focus({ window = ${window(address)} })`
}

// terminals keep ctrl v for themselves and paste on ctrl shift v
export function paste(address, app) {
    const mods = terminals.includes(app.toLowerCase()) ? "CTRL SHIFT" : "CTRL"
    return `hl.dsp.send_shortcut({ mods = "${mods}", key = "V", window = ${window(address)} })`
}
