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
			fromJS(nextAllTimeLatencyPercentiles["latency_percentiles"])));
	}

	reduce(state, action) {
		let pipelineChannelKey;
		let systemKey;
		switch (action.actionType) {
			case Actions.RECEIVE_PRICE_SPREAD_ALL_TIME_LATENCY_PERCENTILES.actionType:
				pipelineChannelKey = action.latencyPercentiles.pipeline_key;
				systemKey = AppConfig.getSystemKey("MARKET_SPREAD_CHECK");
				return this.updateAllTimeLatencyPercentiles(state, action.latencyPercentiles, pipelineChannelKey, systemKey);
			default:
				return state;
		}
	}
}

const allTimeLatencyPercentileStore = new AllTimeLatencyPercentileStore(Dispatcher);
export default allTimeLatencyPercentileStore;

