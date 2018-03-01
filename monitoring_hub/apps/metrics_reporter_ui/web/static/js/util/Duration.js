function milliseconds(n) {
    return n;
}
function seconds(n) {
    return n * 1000;
}
function minutes(n) {
    return seconds(n) * 60;
}
function hours(n) {
    return minutes(n) * 60;
}
function days(n) {
    return hours(n) * 24;
}
function weeks(n) {
    return days(n) * 7;
}

function toMilliseconds(ms) {
    return ms;
}
function toSeconds(ms) {
    return ms / 1000;
}
function toMinutes(ms) {
    return toSeconds(ms) / 60;
}
function toHours(ms) {
    return toMinutes(ms) / 60;
}
function toDays(ms) {
    return toHours(ms) / 24;
}
function toWeeks(ms) {
    return toDays(ms) / 7;
}

export {
    milliseconds,
    seconds,
    minutes,
    hours,
    days,
    weeks,
    toMilliseconds,
    toSeconds,
    toMinutes,
    toHours,
    toDays,
    toWeeks
}
