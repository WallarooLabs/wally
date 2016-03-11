import {minutes} from "./Duration"


function filterLast5Minutes(benchmarks) {
    const now = Date.now();
    return benchmarks.filter(d => {
        return now - d.get("time") < minutes(5)
    })
}

export default {
	filterLast5Minutes: filterLast5Minutes
}