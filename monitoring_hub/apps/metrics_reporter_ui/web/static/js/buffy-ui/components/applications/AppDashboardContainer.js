import React from "react"
import AppDashboard from "./AppDashboard"
import AppConfigStore from "../../stores/AppConfigStore"
import AppStreamConnections from "../../streaming/AppStreamConnections"
import PhoenixConnector from "../../streaming/PhoenixConnector"

export default class AppDashboardContainer extends React.Component {
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
	connectMetricsChannels(appConfig) {
		AppStreamConnections.metricsChannelsToDispatcherWith(PhoenixConnector, appConfig);
	}
	connectToAppConfigStoreAndUpdateState(props) {
		const { appName } = props.params;
		const appConfig = AppConfigStore.getAppConfig(appName);
		this.connectMetricsChannels(appConfig);
		const appConfigListener = AppConfigStore.addListener(function() {
			if (!this.isUnmounted) {
				const appConfig = AppConfigStore.getAppConfig(appName);
				this.connectMetricsChannels(appConfig);
				this.setState({
					appConfig: appConfig
				})
			}
		}.bind(this));
		return {
			appConfig: appConfig,
			listener: appConfigListener
		};
	}
	render() {
		const { appName } = this.props.params;
		const { appConfig } = this.state;
		const sourceSinkKeys = appConfig.getIn(["metrics", "start-to-end"]);
		const ingressEgressKeys = appConfig.getIn(["metrics", "node-ingress-egress"]);
		const stepKeys = appConfig.getIn(["metrics", "computation"]);
		return(
			<div>
				{ this.props.children || 
					<AppDashboard
						appName={appName}
						appConfig={appConfig}
						sourceSinkKeys={sourceSinkKeys}
						ingressEgressKeys={ingressEgressKeys}
						stepKeys={stepKeys} />
				}
			</div>
		)
	}
}