import * as Apps from "./apps.mjs"
import { glyph } from "./glyphs.mjs"

export const tabs = [{ key: "all", name: "All" }, { key: "apps", name: "Apps" }, { key: "folders", name: "Folders" }]

const before = (a, b) => a < b ? -1 : a > b ? 1 : 0

const app = entry => ({ kind: "app", key: entry.id, name: entry.name, icon: entry.icon, glyph: "", kindName: "App" })
const folder = link => ({ kind: "folder", key: link.path, name: link.name, icon: "", glyph: link.glyph, kindName: "Folder" })

function apps(entries, text) {
    if (text) return Apps.search(entries, text)
    const shown = entries.filter(entry => !entry.noDisplay)
    return shown.sort((a, b) => before(a.name.toUpperCase(), b.name.toUpperCase()) || before(a.id, b.id))
}

function folders(links, text) {
    return links.filter(link => link.name.toLowerCase().includes(text))
}

export function home(tab, query) {
    return tab === "all" && !query.trim()
}

export function results(tab, query, entries, links) {
    if (!tabs.some(known => known.key === tab)) throw new Error(`refused: unknown search tab ${tab}`)
    const text = query.trim().toLowerCase()
    if (home(tab, query)) return []
    const found = []
    if (tab !== "folders") found.push(...apps(entries, text).map(app))
    if (tab !== "apps") found.push(...folders(links, text).map(folder))
    return found
}

export function step(at, by, count) {
    return Math.max(0, Math.min(count - 1, at + by))
}

export function actions(hit, start, taskbar) {
    const open = { action: "open", text: "Open", glyph: glyph("open") }
    return hit.kind === "app" ? [open, ...Apps.menu(hit.key, false, start, taskbar)] : [open]
}

// the first hit of a typed search stands alone, the rest gather under their kind
export function placed(hits, best, sizes) {
    const rows = []
    let y = sizes.top, group = ""
    hits.forEach((hit, index) => {
        const alone = best && index === 0, name = alone ? "Best match" : hit.kindName + "s"
        if (alone || name !== group) {
            if (rows.length) y += sizes.section
            rows.push({ kind: "header", text: name, y })
            y += sizes.header + sizes.gap
            group = name
        }
        const height = alone ? sizes.best : sizes.row
        rows.push({ kind: "hit", index, hit, y, height })
        y += height
    })
    return { rows, height: y + sizes.top }
}
