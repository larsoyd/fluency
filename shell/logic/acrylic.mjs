const lum = ([r, g, b]) => 0.3 * r + 0.59 * g + 0.11 * b
const mix = (from, to, amount) => from.map((c, i) => c + (to[i] - c) * amount)

function clip(color) {
    const l = lum(color), low = Math.min(...color), high = Math.max(...color)
    let out = color
    if (low < 0) out = out.map(c => l + (c - l) * l / (l - low))
    if (high > 1) out = out.map(c => l + (c - l) * (1 - l) / (high - l))
    return out
}

const withLum = (color, l) => clip(color.map(c => c + l - lum(color)))

// blurred backdrop, then the luminosity blend, then the colour blend, in that order
export function reference(backdrop, { tint, tintOpacity, luminosityOpacity }) {
    const lit = mix(backdrop, withLum(backdrop, lum(tint)), luminosityOpacity)
    return mix(lit, withLum(tint, lum(lit)), tintOpacity)
}

export function over({ color, alpha }, backdrop) {
    return mix(backdrop, color, alpha)
}

// exact over neutral backdrops, a plain layer cannot keep the chroma the luminosity blend keeps
export function fill({ tint, luminosityOpacity }) {
    return { color: tint, alpha: luminosityOpacity }
}
