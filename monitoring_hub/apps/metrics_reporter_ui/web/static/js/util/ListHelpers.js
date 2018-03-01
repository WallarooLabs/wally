import {fromJS, List} from "immutable";

function partition(l, pred) {
    const asArrays = l.reduce(function(acc, x) {
        if (pred(x)) {
            acc[0].push(x);
        } else {
            acc[1].push(x);
        }
        return acc;
    }, [[],[]]);
    return List.of(fromJS(asArrays[0]), fromJS(asArrays[1]))
}

export {
    partition
}
