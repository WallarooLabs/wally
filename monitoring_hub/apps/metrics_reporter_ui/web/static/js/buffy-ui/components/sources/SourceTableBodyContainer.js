import React from "react"
import SourceTableBody from "./SourceTableBody"
import ThroughputStatsStore from "../../stores/ThroughputStatsStore"
import LatencyPercentileBinStatsStore from "../../stores/LatencyPercentileBinStatsStore"

export default class SourceTableBodyContainer extends React.Component {
	constructor(props) {
		super(props);
		const { sourceType, sourceName } = this.props;
		const throughputStats = ThroughputStatsStore.getThroughputStats(sourceType, sourceName);
		const latencyPercentileBinStats = LatencyPercentileBinStatsStore.getLatencyPercentileBinStats(sourceType, sourceName);
		this.state = {
			throughputStats: throughputStats,
			latencyPercentileBinStats: latencyPercentileBinStats
		}
		ThroughputStatsStore.addListener(function() {
			if (!this.isUnmounted) {
				const throughputStats = ThroughputStatsStore.getThroughputStats(sourceType, sourceName);
				this.setState({
					throughputStats: throughputStats
				});
			}
		}.bind(this));
		LatencyPercentileBinStatsStore.addListener(function() {
			if (!this.isUnmounted) {
				const latencyPercentileBinStats = LatencyPercentileBinStatsStore.getLatencyPercentileBinStats(sourceType, sourceName);
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