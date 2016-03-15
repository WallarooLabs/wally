import Rand from "../../util/Rand.js";
import PipelineKeys from "../../buffy-ui/constants/PipelineKeys.js"

const pipelineKeys = [PipelineKeys.CLIENT_LIMIT, PipelineKeys.PRICE_SPREAD, PipelineKeys.MARKET_DATA];

export default class ThroughputGenerator {
    constructor(pipelineKey) {
        this.pipelineKey = pipelineKey;
        this.lastThr = Rand.rollFromZero(1000);
    }
    hasNext() {
        return true;
    }
    next() {
        let throughput;
        const time = Date.now();
        if (Rand.rolledByOdds(0.1)) {
            throughput = Rand.rollFromZero(100000);
        } else {
            const thrDiff = Rand.rollFromZero(1000) - 500;
            throughput = this.lastThr + thrDiff;
            if (throughput < 1000) throughput = 1000;
            if (throughput > 1000000) throughput = 1000000;
        }
        this.lastThr = throughput;
        return {
            time: time,
            throughput: throughput,
            "pipeline_key": this.pipelineKey
        }
    }
}
