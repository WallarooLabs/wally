import {ReduceStore} from "flux/utils";
import Actions from "../actions/Actions";
import Dispatcher from "../../dispatcher/Dispatcher";
import {fromJS, List, Map} from "immutable";

const emptyAppConfig = Map({
	metrics: Map().set("computation", List())
				  .set("node-ingress-egress", List())
				  .set("start-to-end", List()),
	workers: List()
});

class AppConfigStore extends ReduceStore {
	constructor(dispatcher) {
		super(dispatcher);
	}
	getInitialState() {
		let state = Map();
		return state;
	}
	getAppNames() {
		return [...this.getState().keys()];
	}
	getAppConfigs() {
		return this.getState().toList();
	}
	getAppConfig(appName) {
		if (this.getState().has(appName)) {
			return this.getState().get(appName);
		} else {
			let appConfig = emptyAppConfig.set("app_name", appName);
			return appConfig;
		}
	}
	updateAppConfig(state, appConfig) {
		let appName = appConfig["app_name"];
		return state.set(appName, fromJS(appConfig));
	}
	updateActiveApps(state, appNamesObj) {
		const appNames = appNamesObj["app_names"];
		appNames.forEach((appName) => {
			if (!state.has(appName)) {
				state = state.set(appName, emptyAppConfig.set("app_name", appName));
			}
		});
		return state;
	}
	reduce(state, action) {
		switch (action.actionType) {
			case Actions.RECEIVE_APP_CONFIG.actionType:
				return this.updateAppConfig(state, action["app-config"]);
			case Actions.RECEIVE_APP_NAMES.actionType:
				return this.updateActiveApps(state, action["app-names"]);
			default:
				return state;
		}
	}
}

const appConfigStore = new AppConfigStore(Dispatcher);
export default appConfigStore;
