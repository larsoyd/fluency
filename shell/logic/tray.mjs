const statuses = ["passive", "active", "attention"]

export function split(items) {
    for (const item of items)
        if (!statuses.includes(item.status)) throw new Error(`refused: unknown status ${item.status} of ${item.id}`)
    return { shown: items.filter(item => item.status !== "passive"), hidden: items.filter(item => item.status === "passive") }
}

// two icons of one app get the same id, a button needs its own key
export function keyed(items) {
    const seen = {}, used = new Set()
    return items.map(item => {
        const count = seen[item.id] = (seen[item.id] ?? 0) + 1
        let key = count === 1 && item.id ? item.id : `${item.id}#${count}`
        while (used.has(key)) key += "#2"
        used.add(key)
        return Object.assign({}, item, { key })
    })
}

export function press(item, input) {
    if (!item) throw new Error("refused: no tray item")
    if (input === "click") return item.onlyMenu ? "menu" : "activate"
    if (input === "middle") return "secondary"
    if (input !== "menu") throw new Error(`refused: unknown input ${input}`)
    if (!item.menu) throw new Error(`refused: ${item.key} has no menu`)
    return "menu"
}

// lines of id, bus name and object path, as the lookup in the tray host prints them
export function entries(text) {
    const out = {}
    for (const line of text.split("\n")) {
        const [id, service, path] = line.split("\t")
        const name = /^s "(.*)"$/.exec(id ?? "")
        if (name && service && path) out[name[1]] = { service, path }
    }
    return out
}

export function activation(entry, x, y) {
    if (!entry) throw new Error("refused: no bus entry for the tray item")
    if (!/^:?[A-Za-z0-9_.-]+$/.test(entry.service) || entry.service.startsWith("-")) throw new Error(`refused: bad bus name ${entry.service}`)
    if (!/^(\/[A-Za-z0-9_]+)+$/.test(entry.path)) throw new Error(`refused: bad object path ${entry.path}`)
    return ["busctl", "--user", "--timeout=2", "call", entry.service, entry.path, "org.kde.StatusNotifierItem", "Activate", "ii", String(x), String(y)]
}

// plasma opens the menu when an item has no activate, apps of libappindicator have none
export function failed(err) {
    return /No such method|UnknownMethod/.test(err) ? "menu" : ""
}

export function link(devices) {
    const up = kind => devices.some(device => device.kind === kind && device.connected)
    return up("wired") ? "wired" : up("wifi") ? "wifi" : "none"
}

export function cell(content, metrics) {
    return Math.max(metrics.trayIconMinWidth, content + 2 * metrics.trayIconPaddingX)
}

// the contents of one button, the first and the last keep a distance to its edge
export function omni(items, metrics) {
    const at = []
    let x = metrics.omniEdgePadding
    for (const item of items) {
        const padding = item.bare ? 0 : metrics.trayIconPaddingX
        at.push(x + padding)
        x += item.width + 2 * padding
    }
    return { width: items.length ? x + metrics.omniEdgePadding : 0, at }
}

export function flyout(count, metrics) {
    const columns = Math.min(count, metrics.overflowColumns), rows = columns ? Math.ceil(count / columns) : 0
    const around = columns ? 2 * (metrics.flyoutBorder + metrics.overflowGridMargin) : 0
    return { columns, rows, width: around + columns * metrics.overflowCell, height: around + rows * metrics.overflowCell }
}

export function flyoutX(centre, width, screen, margin) {
    return Math.max(margin, Math.min(Math.round(centre - width / 2), screen - width - margin))
}

// the full tray goes where asked, else on the screen at the origin
export function screen(screens, wanted) {
    const pick = screens.find(s => s.name === wanted) ?? screens.find(s => s.x === 0 && s.y === 0) ?? screens[0]
    return pick?.name ?? ""
}

export function volume(level, muted) {
    const percent = Math.round(level * 100)
    if (muted) return "\ue74f"
    if (percent <= 0) return "\ue992"
    return percent < 33 ? "\ue993" : percent < 66 ? "\ue994" : "\ue995"
}

export function network(kind) {
    const glyph = { wired: "\ue839", wifi: "\ue701", none: "\uf384" }[kind]
    if (!glyph) throw new Error(`refused: unknown network ${kind}`)
    return glyph
}

// a stack of two lines centred in the bar, the margin shifts it
export function clockTop(height, line, margin) {
    const [, top, , bottom] = margin
    return (height - (2 * line + top + bottom)) / 2 + top
}

const loudest = "\ue995"

// the level is drawn over a faint full speaker, as the text icons of the tray do
export function glyphs({ network: kind, volume: level, muted }) {
    const base = volume(level, muted), sound = { name: "volume", base }
    if (!muted && base !== loudest) sound.underlay = loudest
    return [{ name: "network", base: network(kind) }, sound]
}
