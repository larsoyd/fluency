const pad = n => String(n).padStart(2, "0")
const hour12 = d => d.getHours() % 12 || 12

const fields = {
    yyyy: d => d.getFullYear(),
    yy: d => pad(d.getFullYear() % 100),
    MM: d => pad(d.getMonth() + 1),
    M: d => d.getMonth() + 1,
    dd: d => pad(d.getDate()),
    d: d => d.getDate(),
    HH: d => pad(d.getHours()),
    H: d => d.getHours(),
    hh: d => pad(hour12(d)),
    h: d => hour12(d),
    mm: d => pad(d.getMinutes()),
    m: d => d.getMinutes(),
    ss: d => pad(d.getSeconds()),
    s: d => d.getSeconds(),
    tt: d => d.getHours() < 12 ? "AM" : "PM",
}

const quoted = "'(?:[^']|'')*'"
const text = part => part.slice(1, -1).replace(/''/g, "'")

export function format(date, picture) {
    const parts = new RegExp(`${quoted}|yyyy|yy|MM|M|dd|d|HH|H|hh|h|mm|m|ss|s|tt`, "g")
    return picture.replace(parts, part => part[0] === "'" ? text(part) : fields[part](date))
}

// qt counts h to 23 unless the format has a marker for the half of the day
export function fromQt(format) {
    const parts = format.match(new RegExp(`${quoted}|AP|Ap|aP|ap|A|a|([a-zA-Z])\\1*|[^a-zA-Z']+`, "g")) ?? []
    const marker = part => /^(AP|Ap|aP|ap|A|a)$/.test(part)
    const halves = parts.some(marker)
    return parts.map(part => {
        if (part[0] === "'" || !/[a-zA-Z]/.test(part)) return part
        if (marker(part)) return "tt"
        const field = /^h+$/.test(part) && !halves ? part.toUpperCase() : part
        if (!fields[field]) throw new Error(`refused: no field ${part} in a picture`)
        return field
    }).join("")
}

export function pictures(time, date) {
    const picture = (format, fallback) => {
        try { return fromQt(format) || fallback } catch (e) { return fallback }
    }
    return { time: picture(time, "HH:mm"), date: picture(date, "yyyy-MM-dd") }
}

export function lines(date, pictures) {
    return [format(date, pictures.time), format(date, pictures.date)]
}

export function untilNextMinute(date) {
    return 60000 - date.getSeconds() * 1000 - date.getMilliseconds()
}
