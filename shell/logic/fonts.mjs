export function firstAvailable(wanted, available) {
    return wanted.find(family => available.includes(family)) ?? ""
}
