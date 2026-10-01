// a notch moves 15 percent of the view but at least 48 px
export function wheelStep(view, delta) {
    const size = Math.round(Math.abs(delta) * Math.max(48, Math.round(view * 0.15)) / 120)
    return -Math.sign(delta) * Math.min(Math.floor(view), size)
}

export function wheelTarget(target, delta, view, content) {
    return Math.max(0, Math.min(content - view, target + wheelStep(view, delta)))
}

// the thumb takes the share of the track the view has of the content
export function thumb(contentY, view, content, track, least) {
    if (content <= view) return { y: 0, h: track }
    const h = Math.min(track, Math.max(least, Math.round(track * view / content)))
    return { y: Math.round((track - h) * contentY / (content - view)), h }
}

export function fromThumb(y, h, track, view, content) {
    return Math.max(0, Math.min(content - view, Math.round((content - view) * y / (track - h))))
}
