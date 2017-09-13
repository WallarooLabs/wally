import React from "react"
import SourceTableBody from "./SourceTableBody"
import ThroughputStatsStore from "../../stores/ThroughputStatsStore"
import LatencyPercentileBinStatsStore from "../../stores/LatencyPercentileBinStatsStore"

export default class SourceTableBodyContainer extends React.Component {
	constructor(props) {
		super(props);
		const { sourceType, sourceName } = this.props;
		let updatedSourceType;
		switch(sourceType) {
			case "computations-on-worker":
				updatedSourceType = "computation-by-worker";
				break;
			case "computations-for-pipeline-on-worker":
				updatedSourceType = "computation-by-worker";
				break;
			case "computations-for-pipeline":
				updatedSourceType = "computation";
				break;
			default:
				updatedSourceType = sourceType;
				break;
		}
		const throughputStats = ThroughputStatsStore.getThroughputStats(updatedSourceType, sourceName);
		const latencyPercentileBinStats = LatencyPercentileBinStatsStore.getLatencyPercentileBinStats(updatedSourceType, sourceName);
		this.state = {
			throughputStats: throughputStats,
			latencyPercentileBinStats: latencyPercentileBinStats
		}
		ThroughputStatsStore.addListener(function() {
			if (!this.isUnmounted) {
				const throughputStats = ThroughputStatsStore.getThroughputStats(updatedSourceType, sourceName);
				this.setState({
					throughputStats: throughputStats
				});
			}
		}.bind(this));
		LatencyPercentileBinStatsStore.addListener(function() {
			if (!this.isUnmounted) {
				const latencyPercentileBinStats = LatencyPercentileBinStatsStore.getLatencyPercentileBinStats(updatedSourceType, sourceName);
				this.setState({
					latencyPercentileBinStats: latencyPercentileBinStats
				});
			}
		}.bind(this));
	}
	componentDidMount() {
		this.isUnmounted = false;
	}
	componentWillUnmount() {
		this.isUnmounted = true;
	}
	render() {
		const { appName, linked, sourceName, sourceType } = this.props;
		const { throughputStats, latencyPercentileBinStats } = this.state;
		return(
			<SourceTableBody
				appName={appName}
				sourceName={sourceName}
				sourceType={sourceType}
				linked={linked}
				latencyPercentileBinStats={latencyPercentileBinStats}
				throughputStats={throughputStats} />
		);
	}
}
