import {ReduceStore} from "flux/utils";
import Actions from "../actions/Actions";
import Dispatcher from "../../dispatcher/Dispatcher";
import { fromJS, List, Map } from "immutable";
import AppConfig from "../config/AppConfig";

class AllTimeLatencyPercentileStore extends ReduceStore {
	constructor(dispatcher) {
		super(dispatcher);
	}
	getInitialState() {
		let state = Map();

		Object.keys(AppConfig.SYSTEM_KEYS).forEach(systemKey => {
		    const key = AppConfig.getSystemKey(systemKey);
		    let pipelineKeys = AppConfig.getSystemPipelineKeys(key);
		    state = state.set(key, Map());

		    Object.keys(pipelineKeys).forEach(pipelineKey => {
		        let systemState = state.get(key);
		        state = state.set(key, systemState.set(AppConfig.getChannelKey(key, pipelineKey),  List()));
		    });
		});
		return state;
	}

	getPipelineLatencyPercentiles(systemKey, pipelineKey) {
		return this.getState().get(systemKey).get(pipelineKey);
	}

	updateAllTimeLatencyPercentiles(state, nextAllTimeLatencyPercentiles, pipelineKey, systemKey) {
		const systemMap = state.get(systemKey);
		return state.set(systemKey, systemMap.set(pipelineKey, 
			fromJS(nextAllTimeLatencyPercentiles["latencyPercentiles"])));
	}

	reduce(state, action) {
		let pipelineChannelKey;
		let systemKey;
		switch (action.actionType) {
			case Actions.RECEIVE_PRICE_SPREAD_ALL_TIME_LATENCY_PERCENTILES.actionType:
				pipelineChannelKey = AppConfig.getChannelKey("MARKET_SPREAD_CHECK", "PRICE_SPREAD");
				systemKey = AppConfig.getSystemKey("MARKET_SPREAD_CHECK");
				return this.updateAllTimeLatencyPercentiles(state, action.latencyPercentiles, pipelineChannelKey, systemKey);
			case Actions.RECEIVE_CLIENT_LIMIT_ALL_TIME_LATENCY_PERCENTILES.actionType:
				pipelineChannelKey = AppConfig.getChannelKey("CLIENT_LIMIT_CHECK", "CLIENT_LIMIT");
				systemKey = AppConfig.getSystemKey("CLIENT_LIMIT_CHECK");
				return this.updateAllTimeLatencyPercentiles(state, action.latencyPercentiles, pipelineChannelKey, systemKey);
			case Actions.RECEIVE_MARKET_DATA_ALL_TIME_LATENCY_PERCENTILES.actionType:
				pipelineChannelKey = AppConfig.getChannelKey("MARKET_SPREAD_CHECK", "NBBO");
				systemKey = AppConfig.getSystemKey("MARKET_SPREAD_CHECK");
				return this.updateAllTimeLatencyPercentiles(state, action.latencyPercentiles, pipelineChannelKey, systemKey);
			// Actionable Pipelines
			// case Actions.RECEIVE_PRICE_SPREAD_ACTIONABLE_ALL_TIME_LATENCY_PERCENTILES.actionType:
			// 	pipelineChannelKey = AppConfig.getChannelKey("INTERNAL_MONITORING", "PRICE_SPREAD_ACTIONABLE");
			// 	systemKey = AppConfig.getSystemKey("INTERNAL_MONITORING");
			// 	return this.updateAllTimeLatencyPercentiles(state, action.latencyPercentiles, pipelineChannelKey, systemKey);
			// case Actions.RECEIVE_CLIENT_LIMIT_ACTIONABLE_ALL_TIME_LATENCY_PERCENTILES.actionType:
			// 	pipelineChannelKey = AppConfig.getChannelKey("INTERNAL_MONITORING", "CLIENT_LIMIT_ACTIONABLE");
			// 	systemKey = AppConfig.getSystemKey("INTERNAL_MONITORING");
			// 	return this.updateAllTimeLatencyPercentiles(state, action.latencyPercentiles, pipelineChannelKey, systemKey);
			// case Actions.RECEIVE_MARKET_DATA_ACTIONABLE_ALL_TIME_LATENCY_PERCENTILES.actionType:
			// 	pipelineChannelKey = AppConfig.getChannelKey("INTERNAL_MONITORING", "NBBO_ACTIONABLE");
			// 	systemKey = AppConfig.getSystemKey("INTERNAL_MONITORING");
			// 	return this.updateAllTimeLatencyPercentiles(state, action.latencyPercentiles, pipelineChannelKey, systemKey);
			default:
				return state;
		}
	}
}

const allTimeLatencyPercentileStore = new AllTimeLatencyPercentileStore(Dispatcher);
export default allTimeLatencyPercentileStore;

