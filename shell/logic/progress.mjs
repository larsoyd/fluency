import { bezier } from "./curve.mjs"

export const storyboard = { period: 2000, firstEnd: 1500, secondStart: 750, spline: [0.4, 0, 0.6, 1] }

export function travel(width) {
    const width1 = width * 0.4, width2 = width * 0.6
    return { width1, start1: -width1, end1: width1 * 3, width2, start2: width2 * -1.5, end2: width2 * 1.66 }
}

export function indeterminate(width, ms) {
    const { period, firstEnd, secondStart, spline } = storyboard
    const t = travel(width), at = ms % period
    return {
        x1: t.start1 + (t.end1 - t.start1) * bezier(spline, at / firstEnd),
        x2: t.start2 + (t.end2 - t.start2) * bezier(spline, (at - secondStart) / (period - secondStart)),
    }
}

export function determinate(width, value) {
    return width * Math.min(1, Math.max(0, value))
}
