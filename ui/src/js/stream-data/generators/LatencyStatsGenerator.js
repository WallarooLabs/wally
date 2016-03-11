import Rand from "../../util/Rand.js";
//import PipelineKeys from "../../gridgain-poc/constants/PipelineKeys.js"

//const pipelineKeys = [PipelineKeys.CLIENT_LIMIT, PipelineKeys.PRICE_SPREAD, PipelineKeys.MARKET_DATA];

export default class LatencyStatsGenerator {
    constructor() {
        this.pctl50 = 450;
        this.pctl75 = 2000;
        this.pctl90 = 10000;
    }
    hasNext() {
        return true;
    }
    next() {
        if (Rand.rolledByOdds(0.1)) {
            this.pctl50 = this.pctl50 - Rand.randInt(10,100);
            if (this.pctl50 < 0) this.pctl50 = 100;
        }

        if (Rand.rolledByOdds(0.1)) {
            this.pctl90 = this.pctl90 + Rand.randInt(100,200);
            if (this.pctl50 < 0) this.pctl50 = 0.1;
        }

        const medDiff = Rand.randInt(50,250) - 50;
        this.pctl75 = this.pctl75 + medDiff;
        if (this.pctl75 < this.pctl50) this.pctl75 = this.pctl50;
        if (this.pctl75 > this.pctl90) this.pctl75 = this.pctl90;

        return {
            pctl50: this.pctl50,
            pctl75: this.pctl75,
            pctl90: this.pctl90,
            category: "MARKET_SPREAD"
        }
    }
}
