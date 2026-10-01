// an app may ask to stay forever, the toast still leaves the screen
export function shown(expire, fallback) {
    return expire > 0 ? expire : fallback
}

export function stack(list, item, max) {
    return [item, ...list].slice(0, max)
}

export function text(n) {
    return { app: n.appName, title: n.summary || n.appName || "Notification", body: n.body }
}

export const key = n => String(n.id)

// a toast that went stays under the one above it until it has slid out, new ones come on top
export function order(have, want) {
    const keys = want.slice(), leaving = [], fresh = want.findIndex(k => have.includes(k))
    have.forEach((k, at) => {
        if (want.includes(k)) return
        leaving.push(k)
        keys.splice(at ? keys.indexOf(have[at - 1]) + 1 : fresh < 0 ? want.length : fresh, 0, k)
    })
    return { keys, leaving }
}

// a path or url stands for itself, a name goes through the icon theme
export function source(n, themed) {
    const name = n.appIcon || n.image || "application-x-executable"
    if (name.startsWith("/")) return "file://" + name
    return name.startsWith("file:") || name.startsWith("image:") ? name : themed(name)
}

// the value hint is a percent, two fluency hints name the step and the count beside the bar
export function progress(n) {
    const hints = n.hints || {}, raw = Number(hints.value)
    if (!("value" in hints) || !(raw >= 0)) return null
    const pct = Math.min(100, Math.round(raw))
    return { value: pct / 100, status: hints["x-fluency-status"] || "", text: hints["x-fluency-value"] || `${pct}%` }
}

// windows shows at most five buttons, the default action is the toast itself
export function buttons(n) {
    return (n.actions || []).filter(a => a.identifier !== "default").slice(0, 5).map(a => ({ id: a.identifier, text: a.text }))
}

export function view(n, themed) {
    return Object.assign(text(n), { icon: source(n, themed), bar: progress(n), buttons: buttons(n) })
}
