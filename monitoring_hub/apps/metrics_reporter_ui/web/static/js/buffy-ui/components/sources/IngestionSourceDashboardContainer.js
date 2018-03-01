import React from "react"
import ThroughputsStore from "../../stores/ThroughputsStore"
import ThroughputStatsStore from "../../stores/ThroughputStatsStore"
import LatencyPercentileBinStatsStore from "../../stores/LatencyPercentileBinStatsStore"
import LatencyPercentageBinsStore from "../../stores/LatencyPercentageBinsStore"
import AppConfigStore from "../../stores/AppConfigStore"
import IngestionSourceDashboard from "./IngestionSourceDashboard"
import { is } from "immutable"
import shallowCompare from "react-addons-shallow-compare"
import AppStreamConnections from "../../streaming/AppStreamConnections"
import PhoenixConnector from "../../streaming/PhoenixConnector"


export default class IngestionSourceDashboardContainer extends React.Component {
	constructor(props) {
		super(props);
		this.state = this.connectToMetricStoresAndUpdateState(props);
	}
	componentDidMount() {
		this.isUnmounted = false;
	}
	componentWillUnmount() {
		this.isUnmounted = true;
		this.removeListeners(this.state);
	}
	componentWillReceiveProps(nextProps) {
		this.removeListeners(this.state);
		const newState = this.connectToMetricStoresAndUpdateState(nextProps);
		this.setState(newState);
	}
	connectMetricChannels(sourceType, sourceName) {
		AppStreamConnections.connectSourceMetricsChannels(PhoenixConnector, sourceType, sourceName);
	}
	connectToMetricStoresAndUpdateState(props) {
		const { appName, sourceName } = props.params;
		const sourceType = "start-to-end";
		const ingestionSourceType = "pipeline-ingestion";
		const ingestionSourceName = sourceName + " source";
		const sourceMetricChannel = appName + "||" + sourceName;
		const ingestionSourceMetricChannel = appName + "||" + ingestionSourceName;
		this.connectMetricChannels(sourceType, sourceMetricChannel);
		this.connectMetricChannels(ingestionSourceType, ingestionSourceMetricChannel);
		const throughputStats = ThroughputStatsStore.getThroughputStats(appName, sourceType, sourceName);
		const ingestionThroughputStats = ThroughputStatsStore.getThroughputStats(appName, ingestionSourceType, ingestionSourceName);
		const latencyPercentileBinStats = LatencyPercentileBinStatsStore.getLatencyPercentileBinStats(appName, sourceType, sourceName);
		const latencyPercentageBins = LatencyPercentageBinsStore.getLatencyPercentageBins(appName, sourceType, sourceName);
		const throughputs = ThroughputsStore.getThroughputs(appName, sourceType, sourceName);
		let throughputsListener = ThroughputsStore.addListener(function() {
			if (!this.isUnmounted) {
				const throughputs = ThroughputsStore.getThroughputs(appName, sourceType, sourceName);
				this.setState({
					throughputs: throughputs
				});
			}
		}.bind(this));
		let throughputStatsListener = ThroughputStatsStore.addListener(function() {
			if (!this.isUnmounted) {
				const throughputStats = ThroughputStatsStore.getThroughputStats(appName, sourceType, sourceName);
				const ingestionThroughputStats = ThroughputStatsStore.getThroughputStats(appName, ingestionSourceType, ingestionSourceName);
				this.setState({
					throughputStats: throughputStats,
					ingestionThroughputStats: ingestionThroughputStats
				});
			}
		}.bind(this));
		let latencyPercentileBinStatsListener = LatencyPercentileBinStatsStore.addListener(function() {
			if (!this.isUnmounted) {
				const latencyPercentileBinStats = LatencyPercentileBinStatsStore.getLatencyPercentileBinStats(appName, sourceType, sourceName);
				this.setState({
					latencyPercentileBinStats: latencyPercentileBinStats
				});
			}
		}.bind(this));
		let latencyPercentageBinsListener = LatencyPercentageBinsStore.addListener(function() {
			if (!this.isUnmounted) {
				const latencyPercentageBins = LatencyPercentageBinsStore.getLatencyPercentageBins(appName, sourceType, sourceName);
				this.setState({
					latencyPercentageBins: latencyPercentageBins
				});
			}
		}.bind(this));
		let listeners = [throughputsListener, throughputStatsListener, latencyPercentileBinStatsListener, latencyPercentageBinsListener];
		return {
			throughputs: throughputs,
			throughputStats: throughputStats,
			ingestionThroughputStats: ingestionThroughputStats,
			latencyPercentileBinStats: latencyPercentileBinStats,
			latencyPercentageBins: latencyPercentageBins,
			listeners: listeners
		};
	}
	shouldComponentUpdate(nextProps, nextState) {
		return(true);
	}
	removeListeners(state) {
		let listeners = state.listeners;
		listeners.forEach((listener) => {
			listener.remove();
		});
	}
	render() {
		const { throughputs, throughputStats, ingestionThroughputStats, latencyPercentageBins, latencyPercentileBinStats } = this.state;
		const { appName, sourceName } = this.props.params;
		const sourceType = "start-to-end";
		const appConfig = AppConfigStore.getAppConfig(appName);
		return(
			<IngestionSourceDashboard
				appName={appName}
				appConfig={appConfig}
				sourceName={sourceName}
				sourceType={sourceType}
				throughputs={throughputs}
				throughputStats={throughputStats}
				ingestionThroughputStats={ingestionThroughputStats}
				latencyPercentageBins={latencyPercentageBins}
				latencyPercentileBinStats={latencyPercentileBinStats} />
		)

	}
}
