import React from "react"
import SourceTableBody from "./SourceTableBody"
import ThroughputStatsStore from "../../stores/ThroughputStatsStore"
import LatencyPercentileBinStatsStore from "../../stores/LatencyPercentileBinStatsStore"

export default class SourceTableBodyContainer extends React.Component {
	constructor(props) {
		super(props);
		this.state = this.connectToMetricStoresAndUpdateState(props);
	}
	connectToMetricStoresAndUpdateState(props) {
		const { appName, sourceType, sourceName } = props;
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
		const latencyPercentileBinStats = LatencyPercentileBinStatsStore.getLatencyPercentileBinStats(appName, updatedSourceType, sourceName);

		let throughputStatsListener = ThroughputStatsStore.addListener(function() {
			if (!this.isUnmounted) {
				const throughputStats = ThroughputStatsStore.getThroughputStats(appName, updatedSourceType, sourceName);
				this.setState({
					throughputStats: throughputStats
				});
			}
		}.bind(this));
		let latencyPercentileBinStatsListener = LatencyPercentileBinStatsStore.addListener(function() {
			if (!this.isUnmounted) {
				const latencyPercentileBinStats = LatencyPercentileBinStatsStore.getLatencyPercentileBinStats(appName, updatedSourceType, sourceName);
				this.setState({
					latencyPercentileBinStats: latencyPercentileBinStats
				});
			}
		}.bind(this));
		let listeners = [throughputStatsListener, latencyPercentileBinStatsListener];
		return {
			throughputStats: throughputStats,
			latencyPercentileBinStats: latencyPercentileBinStats,
			listeners: listeners
		}
	}
	componentDidMount() {
		this.isUnmounted = false;
	}
	componentWillUnmount() {
		this.isUnmounted = true;
		this.removeListeners(this.state);
	}
	componentWillReceiveProps(nextProps) {
		if (this.props.appName != nextProps.appName) {
			this.removeListeners(this.state);
        	const newState = this.connectToMetricStoresAndUpdateState(nextProps);
		}
	}
	removeListeners(state) {
		let listeners = state.listeners;
		listeners.forEach((listener) => {
			listener.remove();
		})
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
