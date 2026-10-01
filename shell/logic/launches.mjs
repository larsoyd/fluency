const before = (a, b) => a < b ? -1 : a > b ? 1 : 0

export function record(log, id, now) {
    if (!id) throw new Error("refused: no app id")
    const out = Object.assign({}, log)
    out[id] = { count: (log[id]?.count ?? 0) + 1, last: now }
    return out
}

function known(log, entries) {
    return entries.filter(entry => !entry.noDisplay && log[entry.id]).map(entry => ({ entry, seen: log[entry.id] }))
}

export function recent(log, entries, count) {
    const hits = known(log, entries)
    hits.sort((a, b) => b.seen.last - a.seen.last || before(a.entry.id, b.entry.id))
    return hits.slice(0, count).map(hit => hit.entry)
}

// a fresh log shows pins, so the pane is never empty
export function top(log, entries, count, pins) {
    const hits = known(log, entries)
    hits.sort((a, b) => b.seen.count - a.seen.count || b.seen.last - a.seen.last || before(a.entry.id, b.entry.id))
    const out = hits.map(hit => hit.entry)
    for (const id of pins ?? []) {
        const entry = entries.find(entry => entry.id === id && !entry.noDisplay)
        if (entry && !out.includes(entry)) out.push(entry)
    }
    return out.slice(0, count)
}

export function restore(text) {
    if (!text) return null
    const data = JSON.parse(text)
    if (!data || typeof data !== "object" || Array.isArray(data)) return null
    const out = {}
    for (const id in data) {
        const seen = data[id]
        if (Number.isInteger(seen?.count) && Number.isFinite(seen?.last)) out[id] = { count: seen.count, last: seen.last }
    }
    return out
}
