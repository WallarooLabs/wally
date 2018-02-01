import {minutes, toSeconds} from "./Duration"


function filterLast5Minutes(benchmarks) {
    const now = toSeconds(Date.now());
    return benchmarks.filter(d => {
        return now - d.get("time") < minutes(5)
    })
}

export {
	filterLast5Minutes
}
