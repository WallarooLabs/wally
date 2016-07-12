import Rand from "../../util/Rand.js";

export default class BenchmarkGenerator {
    constructor() {
        this.lastLat = Rand.rollFromZero(500);
        this.lastThr = Rand.rollFromZero(1000);
    }
    hasNext() {
        return true;
    }
    next() {
        let latency, throughput;
        const time = Date.now();
        if (Rand.rolledByOdds(0.1)) {
            latency = Rand.rollFromZero(500);
            throughput = Rand.rollFromZero(100000);
        } else {
            const latDiff = Rand.rollFromZero(200) - 100;
            const thrDiff = Rand.rollFromZero(1000) - 500;
            latency = this.lastLat + latDiff;
            if (latency < 1) latency = 1;
            if (latency > 500) latency = 500;
            throughput = this.lastThr + thrDiff;
            if (throughput < 1000) throughput = 1000;
            if (throughput > 1000000) throughput = 1000000;
        }
        this.lastLat = latency;
        this.lastThr = throughput;
        return {
            time: time,
            latency: latency,
            throughput: throughput
        }
    }
}
