import Rand from "../../util/Rand.js";
import PipelineKeys from "../../buffy-ui/constants/PipelineKeys"

const pipelineKeys = [PipelineKeys.CLIENT_LIMIT, PipelineKeys.PRICE_SPREAD, PipelineKeys.MARKET_DATA];

export default class LatencyGenerator {
    constructor() {
        this.lastLat = Rand.randInt(850, 10000);
    }
    hasNext() {
        return true;
    }
    next() {
        let latency;
        const time = Date.now();
        if (Rand.rolledByOdds(0.1)) {
            latency = Rand.randInt(850, 10000);
        } else {
            const latDiff = Rand.randInt(5000, 10000) - 1000;
            latency = this.lastLat + latDiff;
            if (latency < 850) latency = 850;
            if (latency > 10000) latency = 10000;
        }
        this.lastLat = latency;
        return {
            time: time,
            latency: latency,
            category: pipelineKeys[1]
        }
    }
}
