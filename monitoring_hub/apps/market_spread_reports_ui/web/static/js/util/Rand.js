function normalizeRand(scalar, correction) {
    return Math.floor(Math.random() * scalar) + correction;
}

function fixedFloatRand(scalar, correction, trailing) {
    return parseFloat(((Math.random() * scalar) + correction).toFixed(trailing));
}

function roll(sides) {
    if (sides < 1) throw new Error("Rand.roll requires 1 or more sides.");
    return normalizeRand(sides, 1);
}

function rolls(count, sides) {
    var sum = 0;
    while (count > 0) {
        sum += roll(sides);
        count--;
    }
    return sum;
}

function rollFromZero(sides) {
    if (sides < 1) throw new Error("Rand.rollFromZero requires 1 or more sides.");
    return normalizeRand(sides, 0);
}

function floatRollFromZero(sides, trailing) {
    if (sides < 1) throw new Error("Rand.floatRollFromZero requires 1 or more sides.");
    return fixedFloatRand(sides, 0, trailing);
}

function randInt(low, high) {
    return normalizeRand((high - low + 1), low);
}

function rolledByOdds(odds) {
    if (odds < 0 || odds > 1) throw new Error("Rand.rolledByOdds requires a value from 0 to 1");
    return Math.random() < odds;
}

function pickItem(items) {
    //Takes an array of items
    var pick = rollFromZero(items.length);
    return items[pick];
}

function keys(table) {
    var keyList = [];
    for (var entry in table) {
        if (table.hasOwnProperty(entry)) {
            keyList.push(entry);
        }
    }
    return keyList;
}

function pickEntryKey(table) {
    var keyList = keys(table);
    return pickItem(keyList);
}

function pickByFreqTable(frequencyTable) {
    var rawFrequencyList = [];
    for (var entry in frequencyTable) {
        for (var i = 0; i < frequencyTable[entry]; i++) {
            rawFrequencyList.push(entry);
        }
    }
    return pickItem(rawFrequencyList);
}

module.exports = {
    roll: roll,
    rolls: rolls,
    rollFromZero: rollFromZero,
    floatRollFromZero: floatRollFromZero,
    rolledByOdds: rolledByOdds,
    randInt: randInt,
    pickItem: pickItem,
    pickEntryKey: pickEntryKey,
    pickByFreqTable: pickByFreqTable
};