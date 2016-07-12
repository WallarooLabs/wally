import Rand from "../../util/Rand";
import PipelineKeys from "../../buffy-ui/constants/PipelineKeys";

const pipelineKeys = [PipelineKeys.CLIENT_LIMIT, PipelineKeys.MARKET_SPREAD, PipelineKeys.MARKET_DATA];

const bins = [
        "0.00001", "0.0001", "0.001", "0.01", "0.1", "1.0", "10.0"
    ];
const maxBin = "10.0";

export default class LatencyPercentilesGenerator {
	constructor(pipelineKey) {
        this.pipelineKey = pipelineKey;
		let acc = Rand.roll(50);
		let latencyBins = {};
		bins.forEach(bin => {
            latencyBins[bin] = acc;
            if (acc < 100) {
                acc = acc + Rand.roll(100 - acc);
            }
		});
		this.latencyBins = latencyBins;
        this.latencyBins[this.latencyBins.length - 1] = 100;
	}
	hasNext() {
		return true;
	}
    updateBins() {
        let lastVal = 0;
        bins.forEach(bin => {
            let change = 10 - Rand.roll(20);
            let newVal = this.latencyBins[bin] + change;

            if (!(newVal < 0 || newVal < lastVal || newVal > 100)) {
                lastVal = newVal;
            }
            delete this.latencyBins[NaN];
            this.latencyBins[bin] = lastVal;
        });
        this.latencyBins[maxBin] = 100;
    }
 	next() {
        this.updateBins();
		return {
            time: Math.floor(Date.now() / 1000),
			"latency_bins": this.latencyBins,
			"pipeline_key": this.pipelineKey
		}
	}
}
