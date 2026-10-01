import { glyph } from "./glyphs.mjs"

const wanted = [
    { key: "DOCUMENTS", name: "Documents", glyph: glyph("document") },
    { key: "DOWNLOAD", name: "Downloads", glyph: glyph("download") },
    { key: "PICTURES", name: "Pictures", glyph: glyph("image") },
    { key: "VIDEOS", name: "Videos", glyph: glyph("video") },
]

// xdg-user-dirs points a dir it does not want at home itself
export function links(text, home) {
    const set = {}
    for (const line of text.split("\n")) {
        const hit = /^XDG_([A-Z]+)_DIR="(.*)"$/.exec(line.trim())
        if (hit) set[hit[1]] = hit[2].replace(/^\$HOME/, home).replace(/\/+$/, "")
    }
    return wanted.map(dir => ({ name: dir.name, glyph: dir.glyph, path: set[dir.key] ?? `${home}/${dir.name}` }))
        .filter(link => link.path !== home && link.path !== "")
}
