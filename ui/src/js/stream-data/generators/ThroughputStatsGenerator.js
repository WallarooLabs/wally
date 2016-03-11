import Rand from "../../util/Rand.js";
//import PipelineKeys from "../../gridgain-poc/constants/PipelineKeys.js"

//const pipelineKeys = [PipelineKeys.CLIENT_LIMIT, PipelineKeys.PRICE_SPREAD, PipelineKeys.MARKET_DATA];

export default class ThroughputGenerator {
    constructor() {
        this.lastMin = 250000;
        this.lastMedian = 500000;
        this.lastMax = 750000;
    }
    hasNext() {
        return true;
    }
    next() {
        if (Rand.rolledByOdds(0.1)) {
            this.lastMin = this.lastMin - Rand.floatRollFromZero(2, 1);
            if (this.lastMin < 0) this.lastMin = 0.1;
        }

        if (Rand.rolledByOdds(0.1)) {
            this.lastMax = this.lastMax + Rand.floatRollFromZero(5, 1);
            if (this.lastMin < 0) this.lastMin = 0.1;
        }

        const medDiff = Rand.floatRollFromZero(50, 1) - 25;
        this.lastMedian = this.lastMedian + medDiff;
        if (this.lastMedian < this.lastMin) this.lastMedian = this.lastMin;
        if (this.lastMedian > this.lastMax) this.lastMedian = this.lastMax;

        return {
            min: this.lastMin,
            median: this.lastMedian,
            max: this.lastMax,
            category: "MARKET_SPREAD"
        }
    }
}
