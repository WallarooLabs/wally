import AppConfig from "../config/AppConfig";
import ActionCreators from "../../buffy-ui/actions/ActionCreators.js";
import Actions from "../../buffy-ui/actions/Actions.js";

export default {
    latencies: function(data) {
        switch (data["pipeline_key"]) {
            case AppConfig.getChannelKey("MARKET_SPREAD_CHECK", "PRICE_SPREAD"):
                return ActionCreators[Actions.RECEIVE_PRICE_SPREAD_LATENCY.actionType](data);
            case AppConfig.getChannelKey("MARKET_SPREAD_CHECK", "NODE_1"):
                return ActionCreators[Actions.RECEIVE_PRICE_SPREAD_LATENCY.actionType](data);
            case AppConfig.getChannelKey("MARKET_SPREAD_CHECK", "NODE_2"):
                return ActionCreators[Actions.RECEIVE_PRICE_SPREAD_LATENCY.actionType](data);
        }
    },
    allTimeLatencyPercentiles: function(data) {
        switch (data["pipeline_key"]) {
            case AppConfig.getChannelKey("MARKET_SPREAD_CHECK", "PRICE_SPREAD"):
                return ActionCreators[Actions.RECEIVE_PRICE_SPREAD_ALL_TIME_LATENCY_PERCENTILES.actionType](data);
            case AppConfig.getChannelKey("MARKET_SPREAD_CHECK", "NODE_1"):
                return ActionCreators[Actions.RECEIVE_PRICE_SPREAD_ALL_TIME_LATENCY_PERCENTILES.actionType](data);
            case AppConfig.getChannelKey("MARKET_SPREAD_CHECK", "NODE_2"):
                return ActionCreators[Actions.RECEIVE_PRICE_SPREAD_ALL_TIME_LATENCY_PERCENTILES.actionType](data);
        }
    },
    throughputs: function(data) {
        switch (data["pipeline_key"]) {
            case AppConfig.getChannelKey("MARKET_SPREAD_CHECK", "PRICE_SPREAD"):
                return ActionCreators[Actions.RECEIVE_PRICE_SPREAD_THROUGHPUT.actionType](data);
            case AppConfig.getChannelKey("MARKET_SPREAD_CHECK", "NODE_1"):
                return ActionCreators[Actions.RECEIVE_PRICE_SPREAD_THROUGHPUT.actionType](data);
            case AppConfig.getChannelKey("MARKET_SPREAD_CHECK", "NODE_2"):
                return ActionCreators[Actions.RECEIVE_PRICE_SPREAD_THROUGHPUT.actionType](data);
        }
    }
}
