export function firstAvailable(wanted, available) {
    return wanted.find(family => available.includes(family)) ?? ""
}

// hind at a fluent size draws digits and words about a tenth smaller than segoe ui variable
const scales = { Hind: 1.08 }

export function scale(family) {
    return scales[family] ?? 1
}

// native text draws up to a pixel past its advance
export function drawnWidth(advance) {
    return advance ? Math.ceil(advance) + 1 : 0
}
