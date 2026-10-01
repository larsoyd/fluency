import { glyph } from "./glyphs.mjs"

export function add(history, n, max) {
    return [n, ...history.filter(old => old !== n)].slice(0, max)
}

export function remove(history, n) {
    return history.filter(old => old !== n)
}

// history is newest first, so the first time an app shows up is its newest
export function groups(history) {
    const out = [], byApp = {}
    for (const n of history) {
        const app = n.appName || "Other"
        if (!byApp[app]) out.push(byApp[app] = { app, items: [] })
        byApp[app].items.push(n)
    }
    return out
}

// a toast without a timeout of its own only leaves the screen and stays in the center
export function timeout(expire) {
    return expire > 0 ? "expire" : "hide"
}

// a quiet bell wins over the badge, the colour still says something waits
export function bell(count, dnd) {
    return { glyph: glyph(dnd ? "bellQuiet" : count > 0 ? "bellWaiting" : "bell"), filled: count > 0 }
}
