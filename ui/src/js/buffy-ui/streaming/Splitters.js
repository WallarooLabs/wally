import AppConfig from "../config/AppConfig";
import ActionCreators from "../../buffy-ui/actions/ActionCreators.js";
import Actions from "../../buffy-ui/actions/Actions.js";

export default {
    latencies: function(data) {
        console.log(data);
        switch (data["pipeline_key"]) {
            case AppConfig.getChannelKey("MARKET_SPREAD_CHECK", "PRICE_SPREAD"):
                return ActionCreators[Actions.RECEIVE_PRICE_SPREAD_LATENCY.actionType](data);
            case AppConfig.getChannelKey("CLIENT_LIMIT_CHECK", "CLIENT_LIMIT"):
                return ActionCreators[Actions.RECEIVE_CLIENT_LIMIT_LATENCY.actionType](data);
            case AppConfig.getChannelKey("MARKET_SPREAD_CHECK", "NBBO"):
                return ActionCreators[Actions.RECEIVE_MARKET_DATA_LATENCY.actionType](data);
            // Actionable Pipelines
            case AppConfig.getChannelKey("INTERNAL_MONITORING", "PRICE_SPREAD_ACTIONABLE"):
                return ActionCreators[Actions.RECEIVE_PRICE_SPREAD_ACTIONABLE_LATENCY.actionType](data);
            case AppConfig.getChannelKey("INTERNAL_MONITORING", "CLIENT_LIMIT_ACTIONABLE"):
                return ActionCreators[Actions.RECEIVE_CLIENT_LIMIT_ACTIONABLE_LATENCY.actionType](data);
            case AppConfig.getChannelKey("INTERNAL_MONITORING", "NBBO_ACTIONABLE"):
                return ActionCreators[Actions.RECEIVE_MARKET_DATA_ACTIONABLE_LATENCY.actionType](data);
        }
    },
    latencyStats: function(data) {
        switch (data["pipeline_key"]) {
            case AppConfig.getChannelKey("MARKET_SPREAD_CHECK", "PRICE_SPREAD"):
                return ActionCreators[Actions.RECEIVE_PRICE_SPREAD_LATENCY_STATS.actionType](data);
            case AppConfig.getChannelKey("CLIENT_LIMIT_CHECK", "CLIENT_LIMIT"):
                return ActionCreators[Actions.RECEIVE_CLIENT_LIMIT_LATENCY_STATS.actionType](data);
            case AppConfig.getChannelKey("MARKET_SPREAD_CHECK", "NBBO"):
                return ActionCreators[Actions.RECEIVE_MARKET_DATA_LATENCY_STATS.actionType](data);
            // Actionable Pipelines
            case AppConfig.getChannelKey("INTERNAL_MONITORING", "PRICE_SPREAD_ACTIONABLE"):
                return ActionCreators[Actions.RECEIVE_PRICE_SPREAD_ACTIONABLE_LATENCY_STATS.actionType](data);
            case AppConfig.getChannelKey("INTERNAL_MONITORING", "CLIENT_LIMIT_ACTIONABLE"):
                return ActionCreators[Actions.RECEIVE_CLIENT_LIMIT_ACTIONABLE_LATENCY_STATS.actionType](data);
            case AppConfig.getChannelKey("INTERNAL_MONITORING", "NBBO_ACTIONABLE"):
                return ActionCreators[Actions.RECEIVE_MARKET_DATA_ACTIONABLE_LATENCY_STATS.actionType](data);

        }
    },
    allTimeLatencyStats: function(data) {
        console.log(data);
        switch (data["pipeline_key"]) {
            case AppConfig.getChannelKey("MARKET_SPREAD_CHECK", "PRICE_SPREAD"):
                return ActionCreators[Actions.RECEIVE_PRICE_SPREAD_ALL_TIME_LATENCY_STATS.actionType](data);
            case AppConfig.getChannelKey("CLIENT_LIMIT_CHECK", "CLIENT_LIMIT"):
                return ActionCreators[Actions.RECEIVE_CLIENT_LIMIT_ALL_TIME_LATENCY_STATS.actionType](data);
            case AppConfig.getChannelKey("MARKET_SPREAD_CHECK", "NBBO"):
                return ActionCreators[Actions.RECEIVE_MARKET_DATA_ALL_TIME_LATENCY_STATS.actionType](data);
        }
    },
    allTimeLatencyPercentiles: function(data) {
        switch (data["pipeline_key"]) {
            case AppConfig.getChannelKey("MARKET_SPREAD_CHECK", "PRICE_SPREAD"):
                return ActionCreators[Actions.RECEIVE_PRICE_SPREAD_ALL_TIME_LATENCY_PERCENTILES.actionType](data);
            case AppConfig.getChannelKey("CLIENT_LIMIT_CHECK", "CLIENT_LIMIT"):
                return ActionCreators[Actions.RECEIVE_CLIENT_LIMIT_ALL_TIME_LATENCY_PERCENTILES.actionType](data);
            case AppConfig.getChannelKey("MARKET_SPREAD_CHECK", "NBBO"):
                return ActionCreators[Actions.RECEIVE_MARKET_DATA_ALL_TIME_LATENCY_PERCENTILES.actionType](data);
            // Actionable Pipelines
            case AppConfig.getChannelKey("INTERNAL_MONITORING", "PRICE_SPREAD_ACTIONABLE"):
                return ActionCreators[Actions.RECEIVE_PRICE_SPREAD_ACTIONABLE_ALL_TIME_LATENCY_PERCENTILES.actionType](data);
            case AppConfig.getChannelKey("INTERNAL_MONITORING", "CLIENT_LIMIT_ACTIONABLE"):
                return ActionCreators[Actions.RECEIVE_CLIENT_LIMIT_ACTIONABLE_ALL_TIME_LATENCY_PERCENTILES.actionType](data);
            case AppConfig.getChannelKey("INTERNAL_MONITORING", "NBBO_ACTIONABLE"):
                return ActionCreators[Actions.RECEIVE_MARKET_DATA_ACTIONABLE_ALL_TIME_LATENCY_PERCENTILES.actionType](data);
        }
    },
    throughputs: function(data) {
        switch (data["pipeline_key"]) {
            case AppConfig.getChannelKey("MARKET_SPREAD_CHECK", "PRICE_SPREAD"):
                return ActionCreators[Actions.RECEIVE_PRICE_SPREAD_THROUGHPUT.actionType](data);
            case AppConfig.getChannelKey("CLIENT_LIMIT_CHECK", "CLIENT_LIMIT"):
                return ActionCreators[Actions.RECEIVE_CLIENT_LIMIT_THROUGHPUT.actionType](data);
            case AppConfig.getChannelKey("MARKET_SPREAD_CHECK", "NBBO"):
                return ActionCreators[Actions.RECEIVE_MARKET_DATA_THROUGHPUT.actionType](data);
            // Actionable Pipelines
            case AppConfig.getChannelKey("INTERNAL_MONITORING", "PRICE_SPREAD_ACTIONABLE"):
                return ActionCreators[Actions.RECEIVE_PRICE_SPREAD_ACTIONABLE_THROUGHPUT.actionType](data);
            case AppConfig.getChannelKey("INTERNAL_MONITORING", "CLIENT_LIMIT_ACTIONABLE"):
                return ActionCreators[Actions.RECEIVE_CLIENT_LIMIT_ACTIONABLE_THROUGHPUT.actionType](data);
            case AppConfig.getChannelKey("INTERNAL_MONITORING", "NBBO_ACTIONABLE"):
                return ActionCreators[Actions.RECEIVE_MARKET_DATA_ACTIONABLE_THROUGHPUT.actionType](data);
        }
    },
    throughputStats: function(data) {
        switch (data["pipeline_key"]) {
            case AppConfig.getChannelKey("MARKET_SPREAD_CHECK", "PRICE_SPREAD"):
                return ActionCreators[Actions.RECEIVE_PRICE_SPREAD_THROUGHPUT_STATS.actionType](data);
            case AppConfig.getChannelKey("CLIENT_LIMIT_CHECK", "CLIENT_LIMIT"):
                return ActionCreators[Actions.RECEIVE_CLIENT_LIMIT_THROUGHPUT_STATS.actionType](data);
            case AppConfig.getChannelKey("MARKET_SPREAD_CHECK", "NBBO"):
                return ActionCreators[Actions.RECEIVE_MARKET_DATA_THROUGHPUT_STATS.actionType](data);
            // Actionable Pipelines
            case AppConfig.getChannelKey("INTERNAL_MONITORING", "PRICE_SPREAD_ACTIONABLE"):
                return ActionCreators[Actions.RECEIVE_PRICE_SPREAD_ACTIONABLE_THROUGHPUT_STATS.actionType](data);
            case AppConfig.getChannelKey("INTERNAL_MONITORING", "CLIENT_LIMIT_ACTIONABLE"):
                return ActionCreators[Actions.RECEIVE_CLIENT_LIMIT_ACTIONABLE_THROUGHPUT_STATS.actionType](data);
            case AppConfig.getChannelKey("INTERNAL_MONITORING", "NBBO_ACTIONABLE"):
                return ActionCreators[Actions.RECEIVE_MARKET_DATA_ACTIONABLE_THROUGHPUT_STATS.actionType](data);
        }
    },
    allTimeThroughputStats: function(data) {
        switch (data["pipeline_key"]) {
            case AppConfig.getChannelKey("MARKET_SPREAD_CHECK", "PRICE_SPREAD"):
                return ActionCreators[Actions.RECEIVE_PRICE_SPREAD_ALL_TIME_THROUGHPUT_STATS.actionType](data);
            case AppConfig.getChannelKey("CLIENT_LIMIT_CHECK", "CLIENT_LIMIT"):
                return ActionCreators[Actions.RECEIVE_CLIENT_LIMIT_ALL_TIME_THROUGHPUT_STATS.actionType](data);
            case AppConfig.getChannelKey("MARKET_SPREAD_CHECK", "NBBO"):
                return ActionCreators[Actions.RECEIVE_MARKET_DATA_ALL_TIME_THROUGHPUT_STATS.actionType](data);
        }
    }
}
