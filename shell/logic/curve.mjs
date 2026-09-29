const axis = (t, a, b) => 3 * (1 - t) * (1 - t) * t * a + 3 * (1 - t) * t * t * b + t * t * t

export function bezier([x1, y1, x2, y2], x) {
    if (x <= 0) return 0
    if (x >= 1) return 1
    let lo = 0, hi = 1
    for (let i = 0; i < 50; i++) {
        const t = (lo + hi) / 2
        if (axis(t, x1, x2) < x) lo = t
        else hi = t
    }
    return axis((lo + hi) / 2, y1, y2)
}

export function sample(from, to, curve, duration, t) {
    return from + (to - from) * bezier(curve, duration > 0 ? t / duration : 1)
}

export function easing(curve) {
    return [...curve, 1, 1]
}
