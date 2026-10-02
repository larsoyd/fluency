// a window hyprland never sized has no picture, and asking for one takes the shell down
export function capturable(size) {
    return size?.[0] > 0 && size?.[1] > 0
}

// a window keeps its shape inside the box and is never blown up
export function fit(size, box) {
    const [w, h] = size
    if (!(w > 0 && h > 0)) return { w: box.w, h: box.h }
    const scale = Math.min(1, box.w / w, box.h / h)
    return { w: Math.round(w * scale), h: Math.round(h * scale) }
}

// one row of thumbnails, shrunk as a whole when the screen has no room for it
export function layout(sizes, m, room) {
    if (!sizes.length) return { cards: [], width: 0, height: 0 }
    const around = 2 * m.pad + (sizes.length - 1) * m.gap
    let fits = sizes.map(size => fit(size, { w: m.width, h: m.height }))
    const used = fits.reduce((sum, f) => sum + f.w, 0)
    if (around + used > room) {
        const scale = Math.max(0, room - around) / used
        fits = fits.map(f => ({ w: Math.max(1, Math.floor(f.w * scale)), h: Math.max(1, Math.floor(f.h * scale)) }))
    }
    const tallest = Math.max(...fits.map(f => f.h))
    let x = m.pad
    const cards = fits.map(f => {
        const card = { x, y: m.pad + Math.round((tallest - f.h) / 2), w: f.w, h: f.h }
        x += f.w + m.gap
        return card
    })
    return { cards, width: x - m.gap + m.pad, height: 2 * m.pad + m.title + tallest }
}
