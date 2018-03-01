import React from "react"
import MonitoringGraphs from "./MonitoringGraphs"
import { Map, fromJS, is } from "immutable"
import {filterLast5Minutes} from "../../../util/BenchmarksHelpers"

export default class MonitoringGraphsContainer extends React.Component {
	toChartData(data, metric) {
		const chartData = data.map(d => new Map({
			x: d.get("time"),
			y: d.get(metric)
		}));

		return new Map({ line: chartData });
	}
	binsToChartData(data) {
		let bins = this.binsFor(data);
		const chartData = fromJS(bins.map(bin => new Map({
			x: bin,
			y: data.get(bin)
		})));

		return new Map({ bars: chartData });
	}
	binsFor(lBins) {
		return lBins.keySeq().toArray().sort((bin1, bin2) => {return parseInt(bin1) - parseInt(bin2)});
	}
	shouldComponentUpdate(nextProps) {
		return !is(this.props.throughputs, nextProps.throughputs) || !is(this.props.latencyPercentageBins, nextProps.latencyPercentageBins);
	}
	render() {
		const {throughputs, chartInterval, latencyPercentageBins} = this.props;

		return(
			<MonitoringGraphs
				throughputChartData={this.toChartData(throughputs, "total_throughput")}
				chartInterval={chartInterval}
				latencyPercentageBinData={this.binsToChartData(latencyPercentageBins)} />
		)
	}
}
