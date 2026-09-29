import { sample } from "./curve.mjs"

export function total(frames) {
    return frames.reduce((sum, frame) => sum + frame.duration, 0)
}

export function offset(frames, t) {
    let from = 0, start = 0
    for (const frame of frames) {
        if (t < start + frame.duration) return sample(from, frame.to, frame.curve, frame.duration, t - start)
        from = frame.to
        start += frame.duration
    }
    return from
}

export function trigger(before, after) {
    const shown = item => item.windows - item.minimized
    if (after.minimized > before.minimized && shown(after) < shown(before)) return "iconMinimize"
    if (shown(after) > shown(before)) return "iconRestore"
    return ""
}
