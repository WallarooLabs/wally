import {ReduceStore} from "flux/utils";
import Actions from "../actions/Actions.js";
import Comparators from "../../util/Comparators.js";
import Dispatcher from "../../dispatcher/Dispatcher.js";
import { fromJS, List, Map } from "immutable";
import {minutes} from "../../util/Duration.js";
import AppConfig from "../config/AppConfig"

const emptyBenchmarks = Map()
                    .set("latencies", List())
                    .set("throughputs", List());

class BenchmarksStore extends ReduceStore {
    constructor(dispatcher) {
        super(dispatcher);
    }
    getInitialState() {
        let state = Map();

        Object.keys(AppConfig.SYSTEM_KEYS).forEach(systemKey => {
            const key = AppConfig.getSystemKey(systemKey);
            let pipelineKeys = AppConfig.getSystemPipelineKeys(systemKey);
            state = state.set(key, Map());

            Object.keys(pipelineKeys).forEach(pipelineKey => {
                let systemState = state.get(key);
                state = state.set(key, systemState.set(AppConfig.getChannelKey(key, pipelineKey), emptyBenchmarks));
            });
        });
        return state;

    }
    getPipelineLatencies(systemKey, pipelineKey) {
        return this.getState().get(systemKey).get(pipelineKey).get("latencies");
    }
    getPipelineThroughputs(systemKey, pipelineKey) {
        return this.getState().get(systemKey).get(pipelineKey).get("throughputs");
    }
    filterLatencyData(state, nextLatencyPercentiles, pipelineKey, systemKey) {
        const now = Date.now();
        const systemMap = state.get(systemKey);
        const benchmarksMap = systemMap.get(pipelineKey);
        const latenciesList = benchmarksMap.get("latencies");
        console.log(nextLatencyPercentiles);
        const nextLatency = {
            time: nextLatencyPercentiles.time,
            latency: nextLatencyPercentiles.latency_percentiles["50.0"],
            pipeline_key: nextLatencyPercentiles.pipeline_key
        };
        console.log(nextLatency);
        const updatedLatenciesList = latenciesList.push(fromJS(nextLatency)).sort(Comparators.propFor("time")).filter(d => {
            return now - d.get("time") < minutes(15)
        });
        return state.set(systemKey, systemMap.set(pipelineKey, benchmarksMap.set("latencies", updatedLatenciesList)));
    }
    filterThroughputData(state, nextThroughput, pipelineKey, systemKey) {
        const now = Date.now();
        const systemMap = state.get(systemKey);
        const benchmarksMap = systemMap.get(pipelineKey);
        const throughputsList = benchmarksMap.get("throughputs");
        const updatedThroughputsList = throughputsList.push(fromJS(nextThroughput)).sort(Comparators.propFor("time")).filter(d => {
            return now - d.get("time") < minutes(15)
        });
        return state.set(systemKey, systemMap.set(pipelineKey, benchmarksMap.set("throughputs", updatedThroughputsList)));
    }
    reduce(state, action) {
        if (!action) return state;
        let pipelineChannelKey;
        let systemKey;
        switch (action.actionType) {
            case Actions.RECEIVE_CLIENT_LIMIT_LATENCY.actionType:
                pipelineChannelKey = AppConfig.getChannelKey("CLIENT_LIMIT_CHECK", "CLIENT_LIMIT");
                systemKey = AppConfig.getSystemKey("CLIENT_LIMIT_CHECK");
                return this.filterLatencyData(state, action.latency, pipelineChannelKey, systemKey);
            case Actions.RECEIVE_CLIENT_LIMIT_THROUGHPUT.actionType:
                pipelineChannelKey = AppConfig.getChannelKey("CLIENT_LIMIT_CHECK", "CLIENT_LIMIT");
                systemKey = AppConfig.getSystemKey("CLIENT_LIMIT_CHECK");
                return this.filterThroughputData(state, action.throughput, pipelineChannelKey, systemKey);
            case Actions.RECEIVE_PRICE_SPREAD_LATENCY.actionType:
                pipelineChannelKey = AppConfig.getChannelKey("MARKET_SPREAD_CHECK", "PRICE_SPREAD");
                systemKey = AppConfig.getSystemKey("MARKET_SPREAD_CHECK");
                return this.filterLatencyData(state, action.latency, pipelineChannelKey, systemKey);
            case Actions.RECEIVE_PRICE_SPREAD_THROUGHPUT.actionType:
                pipelineChannelKey = AppConfig.getChannelKey("MARKET_SPREAD_CHECK", "PRICE_SPREAD");
                systemKey = AppConfig.getSystemKey("MARKET_SPREAD_CHECK");
                return this.filterThroughputData(state, action.throughput, pipelineChannelKey, systemKey);
            case Actions.RECEIVE_MARKET_DATA_LATENCY.actionType:
                pipelineChannelKey = AppConfig.getChannelKey("MARKET_SPREAD_CHECK", "NBBO");
                systemKey = AppConfig.getSystemKey("MARKET_SPREAD_CHECK");
                return this.filterLatencyData(state, action.latency, pipelineChannelKey, systemKey);
            case Actions.RECEIVE_MARKET_DATA_THROUGHPUT.actionType:
                pipelineChannelKey = AppConfig.getChannelKey("MARKET_SPREAD_CHECK", "NBBO");
                systemKey = AppConfig.getSystemKey("MARKET_SPREAD_CHECK");
                return this.filterThroughputData(state, action.throughput, pipelineChannelKey, systemKey);
            // Actionable Pipelines
            // case Actions.RECEIVE_CLIENT_LIMIT_ACTIONABLE_LATENCY.actionType:
            //     pipelineChannelKey = AppConfig.getChannelKey("INTERNAL_MONITORING", "CLIENT_LIMIT_ACTIONABLE");
            //     systemKey = AppConfig.getSystemKey("INTERNAL_MONITORING");
            //     return this.filterLatencyData(state, action.latency, pipelineChannelKey, systemKey);
            // case Actions.RECEIVE_CLIENT_LIMIT_ACTIONABLE_THROUGHPUT.actionType:
            //     pipelineChannelKey = AppConfig.getChannelKey("INTERNAL_MONITORING", "CLIENT_LIMIT_ACTIONABLE");
            //     systemKey = AppConfig.getSystemKey("INTERNAL_MONITORING");
            //     return this.filterThroughputData(state, action.throughput, pipelineChannelKey, systemKey);
            // case Actions.RECEIVE_PRICE_SPREAD_ACTIONABLE_LATENCY.actionType:
            //     pipelineChannelKey = AppConfig.getChannelKey("INTERNAL_MONITORING", "PRICE_SPREAD_ACTIONABLE");
            //     systemKey = AppConfig.getSystemKey("INTERNAL_MONITORING");
            //     return this.filterLatencyData(state, action.latency, pipelineChannelKey, systemKey);
            // case Actions.RECEIVE_PRICE_SPREAD_ACTIONABLE_THROUGHPUT.actionType:
            //     pipelineChannelKey = AppConfig.getChannelKey("INTERNAL_MONITORING", "PRICE_SPREAD_ACTIONABLE");
            //     systemKey = AppConfig.getSystemKey("INTERNAL_MONITORING");
            //     return this.filterThroughputData(state, action.throughput, pipelineChannelKey, systemKey);
            // case Actions.RECEIVE_MARKET_DATA_ACTIONABLE_LATENCY.actionType:
            //     pipelineChannelKey = AppConfig.getChannelKey("INTERNAL_MONITORING", "NBBO_ACTIONABLE");
            //     systemKey = AppConfig.getSystemKey("INTERNAL_MONITORING");
            //     return this.filterLatencyData(state, action.latency, pipelineChannelKey, systemKey);
            // case Actions.RECEIVE_MARKET_DATA_ACTIONABLE_THROUGHPUT.actionType:
            //     pipelineChannelKey = AppConfig.getChannelKey("INTERNAL_MONITORING", "NBBO_ACTIONABLE");
            //     systemKey = AppConfig.getSystemKey("INTERNAL_MONITORING");
            //     return this.filterThroughputData(state, action.throughput, pipelineChannelKey, systemKey);
            default:
                return state;
        }
    }
}

const benchmarksStore = new BenchmarksStore(Dispatcher);
export default benchmarksStore;
