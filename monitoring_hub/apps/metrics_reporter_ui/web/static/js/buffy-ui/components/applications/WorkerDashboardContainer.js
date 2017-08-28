import React from "react"
import WorkerDashboard from "./WorkerDashboard"
import AppConfigStore from "../../stores/AppConfigStore"
import AppStreamConnections from "../../streaming/AppStreamConnections"
import PhoenixConnector from "../../streaming/PhoenixConnector"
import {List} from "immutable";

export default class WorkerDashboardContainer extends React.Component {
	constructor(props) {
		super(props);
		this.state = this.connectToAppConfigStoreAndUpdateState(props);
	}
	componentDidMount() {
		this.isUnmounted = false;
	}
	componentWillUnmount() {
		this.isUnmounted = true;
		this.state.listener.remove();
	}
	componentWillReceiveProps(nextProps) {
		this.state.listener.remove();
		const newState = this.connectToAppConfigStoreAndUpdateState(nextProps);
		this.setState(newState);
	}
	connectMetricsChannels(appConfig, workerName) {
		AppStreamConnections.workerMetricsChannelsToDispatcherWith(PhoenixConnector, appConfig, workerName);
	}
	filterAppConfigByWorker(appConfig, workerName) {
		return appConfig.updateIn(["metrics", "node-ingress-egress"], workersList => {
			return workersList.filter(d => {
				return d.includes(workerName);
			})
		}).updateIn(["metrics", "computation-by-worker", workerName], (computationsList = List()) => {
			return computationsList.filter(d => {
				return d.includes(workerName);
			})
		}).updateIn(["metrics", "node-ingress-egress-by-pipeline", workerName], (pipelinesList = List()) => {
			return pipelinesList.filter(d => {
				return d.includes(workerName)
			})
		}).delete("computation").delete("start-to-end");
	}
	connectToAppConfigStoreAndUpdateState(props) {
		const { appName, workerName } = props.params;
		const appConfig = AppConfigStore.getAppConfig(appName);
		const workerAppConfig = this.filterAppConfigByWorker(appConfig, workerName);
		this.connectMetricsChannels(workerAppConfig, workerName);
		const appConfigListener = AppConfigStore.addListener(function() {
			if (!this.isUnmounted) {
				const appConfig = AppConfigStore.getAppConfig(appName);
				const workerAppConfig = this.filterAppConfigByWorker(appConfig, workerName);
				this.connectMetricsChannels(workerAppConfig, workerName);
				this.setState({
					appConfig: workerAppConfig
				})
			}
		}.bind(this));
		return {
			appConfig: workerAppConfig,
			listener: appConfigListener
		};
	}
	render() {
		const { appName, workerName } = this.props.params;
		const { appConfig } = this.state;
		const sourceSinkKeys = appConfig.getIn(["metrics", "node-ingress-egress-by-pipeline", workerName]);
		const ingressEgressKeys = appConfig.getIn(["metrics", "node-ingress-egress"]);
		const stepKeys = appConfig.getIn(["metrics", "computation-by-worker", workerName]);
		return(
			<div>
				{ this.props.children ||
					<WorkerDashboard
						appName={appName}
						workerName={workerName}
						appConfig={appConfig}
						sourceSinkKeys={sourceSinkKeys}
						ingressEgressKeys={ingressEgressKeys}
						stepKeys={stepKeys} />
				}
			</div>
		)
	}
}
