// six weeks always, so the card keeps its height from month to month
export function month(year, month, firstDay, today, names) {
    const lead = (new Date(year, month, 1).getDay() - firstDay + 7) % 7
    const cells = []
    for (let i = 0; i < 42; i++) {
        const date = new Date(year, month, 1 - lead + i)
        cells.push({
            day: date.getDate(),
            inMonth: date.getMonth() === month,
            today: !!today && date.toDateString() === today.toDateString(),
        })
    }
    const weekdays = (names ?? []).map((_, i) => names[(firstDay + i) % 7])
    return { cells, weekdays }
}

export function step(year, month, by) {
    const date = new Date(year, month + by, 1)
    return { year: date.getFullYear(), month: date.getMonth() }
}
