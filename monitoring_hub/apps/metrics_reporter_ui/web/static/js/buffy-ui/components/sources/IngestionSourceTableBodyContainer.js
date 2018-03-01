import React from "react"
import IngestionSourceTableBody from "./IngestionSourceTableBody"
import ThroughputStatsStore from "../../stores/ThroughputStatsStore"
import LatencyPercentileBinStatsStore from "../../stores/LatencyPercentileBinStatsStore"

export default class SourceTableBodyContainer extends React.Component {
	constructor(props) {
		super(props);
		const { appName, sourceType, sourceName, ingestionSourceName } = this.props;
		const ingestionSourceType = "pipeline-ingestion";
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
		const throughputStats = ThroughputStatsStore.getThroughputStats(appName, updatedSourceType, sourceName);
		const ingestionThroughputStats = ThroughputStatsStore.getThroughputStats(appName, ingestionSourceType, ingestionSourceName);
		const latencyPercentileBinStats = LatencyPercentileBinStatsStore.getLatencyPercentileBinStats(appName, updatedSourceType, sourceName);
		this.state = {
			throughputStats: throughputStats,
			ingestionThroughputStats: ingestionThroughputStats,
			latencyPercentileBinStats: latencyPercentileBinStats
		}
		ThroughputStatsStore.addListener(function() {
			if (!this.isUnmounted) {
				const throughputStats = ThroughputStatsStore.getThroughputStats(appName, updatedSourceType, sourceName);
				const ingestionThroughputStats = ThroughputStatsStore.getThroughputStats(appName, ingestionSourceType, ingestionSourceName);
				this.setState({
					throughputStats: throughputStats,
					ingestionThroughputStats: ingestionThroughputStats
				});
			}
		}.bind(this));
		LatencyPercentileBinStatsStore.addListener(function() {
			if (!this.isUnmounted) {
				const latencyPercentileBinStats = LatencyPercentileBinStatsStore.getLatencyPercentileBinStats(appName, updatedSourceType, sourceName);
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
		const { throughputStats, ingestionThroughputStats, latencyPercentileBinStats } = this.state;
		return(
			<IngestionSourceTableBody
				appName={appName}
				sourceName={sourceName}
				sourceType={sourceType}
				linked={linked}
				latencyPercentileBinStats={latencyPercentileBinStats}
				throughputStats={throughputStats}
				ingestionThroughputStats={ingestionThroughputStats} />
		);
	}
}
