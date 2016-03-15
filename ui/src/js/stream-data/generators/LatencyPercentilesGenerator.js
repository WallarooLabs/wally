import Rand from "../../util/Rand";
import PipelineKeys from "../../buffy-ui/constants/PipelineKeys";

const pipelineKeys = [PipelineKeys.CLIENT_LIMIT, PipelineKeys.PRICE_SPREAD, PipelineKeys.MARKET_DATA];

const percentiles = [ 
        "0.001", "10.0", "20.0", 
        "30.0", "40.0", "50.0", 
        "60.0", "70.0", "75.0", 
        "80.0", "82.5", "85.0",
        "87.5", "90.0", "91.25", 
        "92.5", "93.75", "94.375", 
        "95.0", "96.0", "97.0", 
        "98.0", "99.0", "99.5", 
        "99.9", "99.99", "99.995", 
        "99.999", "99.9995", "99.9999", 
        "99.99995", "99.99999"
    ];

export default class LatencyPercentilesGenerator {
	constructor(pipelineKey) {
        this.pipelineKey = pipelineKey;
		let num = 350;
		let latencyPercentiles = {};
        let percentile;
		percentiles.forEach(p => {
			num = num + 100;
            percentile = p ;
            latencyPercentiles[percentile] = num;
		});
		this.latencyPercentiles = latencyPercentiles;
	}
	hasNext() {
		return true;
	}
	next() {
        const percentiles = Object.keys(this.latencyPercentiles);
        percentiles.forEach(percentile => {
            this.latencyPercentiles[percentile] = this.latencyPercentiles[percentile] + 10;
        })
		let latencyPercentiles = this.latencyPercentiles;
		return {
            time: Date.now(),
			"latency_percentiles": latencyPercentiles,
			"pipeline_key": this.pipelineKey
		}
	}
}
