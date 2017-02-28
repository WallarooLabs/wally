import React from "react"
import WorkersDashboard from "./WorkersDashboard"
import AppConfigStore from "../../stores/AppConfigStore"

export default class WorkersDashboardContainer extends React.Component {
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
	connectToAppConfigStoreAndUpdateState(props) {
		const { appName } = props.params;
		const appConfig = AppConfigStore.getAppConfig(appName);
		const appConfigListener = AppConfigStore.addListener(function() {
			if (!this.isUnmounted) {
				const appConfig = AppConfigStore.getAppConfig(appName);
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
		const workers = appConfig.getIn(["workers"]);
		return(
			<div>
				{
					<WorkersDashboard
						appName={appName}
						appConfig={appConfig}
						workers={workers} />
				}
			</div>
		)
	}
}
