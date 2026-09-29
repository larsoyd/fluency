import { hidden } from "./hypr.mjs"

// hyprland can leave the focus on a window it just hid
const shown = w => w.active && !hidden(w)

export function group(pinned, windows) {
    const items = pinned.map(appId => ({ key: appId.toLowerCase(), appId, pinned: true, windows: [] }))
    const known = new Map(items.map(item => [item.key, item]))
    for (const w of windows) {
        let item = known.get(w.appId.toLowerCase())
        if (!item) {
            item = { key: w.appId ? w.appId.toLowerCase() : "@" + w.address, appId: w.appId, pinned: false, windows: [] }
            items.push(item)
            if (w.appId) known.set(item.key, item)
        }
        item.windows.push(w)
    }
    for (const item of items) {
        item.active = item.windows.some(shown)
        item.attention = item.windows.some(w => w.urgent)
        item.minimized = item.windows.filter(hidden).length
    }
    return items
}

export function visible(windows, monitor, mode) {
    if (mode === "all") return windows
    if (mode === "own") return windows.filter(w => w.monitor === monitor)
    throw new Error(`unknown taskbar mode ${mode}`)
}

export function click(item) {
    const [first, ...rest] = item.windows
    if (!first) return { action: "launch", appId: item.appId }
    if (rest.length) return scroll(item, 1)
    return { action: shown(first) ? "minimize" : "focus", address: first.address }
}

export function middleClick(item) {
    return { action: "launch", appId: item.appId }
}

export function scroll(item, steps) {
    const count = item.windows.length, at = item.windows.findIndex(shown)
    if (!count || !steps) return { action: "none" }
    const from = at < 0 && steps > 0 ? -1 : Math.max(at, 0)
    const next = ((from + steps) % count + count) % count
    if (next === at) return { action: "none" }
    return { action: "focus", address: item.windows[next].address }
}

export function wheel(carry, delta) {
    const sum = carry + delta
    return { steps: -Math.trunc(sum / 120), carry: sum % 120 }
}

export function sync(have, want) {
    const steps = [], now = have.slice()
    for (let at = now.length - 1; at >= 0; at--) {
        if (want.includes(now[at])) continue
        steps.push({ op: "remove", at })
        now.splice(at, 1)
    }
    want.forEach((key, to) => {
        if (now[to] === key) return
        const from = now.indexOf(key)
        if (from < 0) {
            steps.push({ op: "insert", at: to, key })
            now.splice(to, 0, key)
        } else {
            steps.push({ op: "move", from, to })
            now.splice(to, 0, now.splice(from, 1)[0])
        }
    })
    return steps
}

export function reach(from, dx, pitch, count) {
    return Math.max(-from * pitch, Math.min(dx, (count - 1 - from) * pitch))
}

export function slot(from, dx, pitch, count) {
    return from + Math.round(reach(from, dx, pitch, count) / pitch)
}

export function shift(index, from, to) {
    if (from < index && index <= to) return -1
    if (to <= index && index < from) return 1
    return 0
}

export function moved(keys, from, to) {
    const out = keys.slice()
    out.splice(to, 0, out.splice(from, 1)[0])
    return out
}

export function arrange(items, order) {
    const place = item => order.includes(item.key) ? order.indexOf(item.key) : order.length
    return items.map((item, index) => ({ item, index })).sort((a, b) => place(a.item) - place(b.item) || a.index - b.index).map(entry => entry.item)
}

export function remember(orders, monitor, keys) {
    const out = Object.assign({}, orders)
    const previous = Array.isArray(out[monitor]) ? out[monitor] : []
    out[monitor] = keys.concat(previous.filter(key => !keys.includes(key)))
    return out
}
