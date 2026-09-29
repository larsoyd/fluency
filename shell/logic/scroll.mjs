// a notch moves 15 percent of the view but at least 48 px
export function wheelStep(view, delta) {
    const size = Math.round(Math.abs(delta) * Math.max(48, Math.round(view * 0.15)) / 120)
    return -Math.sign(delta) * Math.min(Math.floor(view), size)
}

export function wheelTarget(target, delta, view, content) {
    return Math.max(0, Math.min(content - view, target + wheelStep(view, delta)))
}
