function propFor(prop) {
    return (a, b) => {
        if (a.get) {
            if (a.get(prop) < b.get(prop)) return -1;
            else if (a.get(prop) > b.get(prop)) return 1;
            else return 0;
        } else {
            if (a[prop] < b[prop]) return -1;
            else if (a[prop] > b[prop]) return 1;
            else return 0;
        }
    }
}

function propForNaturalSort(prop) {
    return (a, b) => {
        let stringA = a.get(prop);
        let stringB = b.get(prop);

        let stringAChars = stringA.match(/[a-zA-Z]*/)[0].toLowerCase();
        let stringBChars = stringB.match(/[a-zA-Z]*/)[0].toLowerCase();
        let stringANum = parseFloat(stringA.match(/\d+/));
        let stringBNum = parseFloat(stringB.match(/\d+/));

        if (stringAChars < stringBChars) return -1;
        else if (stringAChars > stringBChars) return 1;
        else {
            if (stringANum < stringBNum) return -1;
            else if (stringANum > stringBNum) return 1;
            else return 0;
        }
    }
}
function reverseComp(result) {
    if (result > 0) return -1;
    else if (result < 0) return 1;
    else return 0;
}
function reverseOf(cmp) {
    return function(a, b) {
        return reverseComp(cmp(a, b))
    }
}

const xComparator = propFor("x");
const yComparator = propFor("y");

export default {
    propFor: propFor,
    reverseOf: reverseOf,
    xComparator: xComparator,
    yComparator: yComparator,
    propForNaturalSort: propForNaturalSort
}
