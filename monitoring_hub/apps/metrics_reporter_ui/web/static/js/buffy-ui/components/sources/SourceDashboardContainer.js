import React from "react"
import ThroughputsStore from "../../stores/ThroughputsStore"
import ThroughputStatsStore from "../../stores/ThroughputStatsStore"
import LatencyPercentileBinStatsStore from "../../stores/LatencyPercentileBinStatsStore"
import LatencyPercentageBinsStore from "../../stores/LatencyPercentageBinsStore"
import AppConfigStore from "../../stores/AppConfigStore"
import SourceDashboard from "./SourceDashboard"
import { is } from "immutable"
import shallowCompare from "react-addons-shallow-compare"
import AppStreamConnections from "../../streaming/AppStreamConnections"
import PhoenixConnector from "../../streaming/PhoenixConnector"


export default class SourceDashboardContainer extends React.Component {
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
		const { appName, sourceType, sourceName } = props.params;
		const metricChannel = appName + "||" + sourceName;
		this.connectMetricChannels(sourceType, metricChannel);
		const throughputStats = ThroughputStatsStore.getThroughputStats(appName, sourceType, sourceName);
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
				this.setState({
					throughputStats: throughputStats
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
			latencyPercentileBinStats: latencyPercentileBinStats,
			latencyPercentageBins: latencyPercentageBins,
			listeners: listeners
		};
	}
	shouldComponentUpdate(nextProps, nextState) {
		return((
			this.props.params !== nextProps.params ||
			!is(this.state.throughputs, nextState.throughputs) ||
			!is(this.state.throughputStats, nextState.throughputStats) ||
			!is(this.state.latencyPercentageBins, nextState.latencyPercentageBins) ||
			!is(this.state.latencyPercentileBinStats, nextState.latencyPercentileBinStats)
		));
	}
	removeListeners(state) {
		let listeners = state.listeners;
		listeners.forEach((listener) => {
			listener.remove();
		});
	}
	render() {
		const { throughputs, throughputStats, latencyPercentageBins, latencyPercentileBinStats } = this.state;
		const { appName, sourceName, sourceType } = this.props.params;
		const appConfig = AppConfigStore.getAppConfig(appName);
		return(
			<SourceDashboard
				appName={appName}
				appConfig={appConfig}
				sourceName={sourceName}
				sourceType={sourceType}
				throughputs={throughputs}
				throughputStats={throughputStats}
				latencyPercentageBins={latencyPercentageBins}
				latencyPercentileBinStats={latencyPercentileBinStats} />
		)

	}
}
