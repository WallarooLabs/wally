import Actions from "../actions/Actions.js";
import ActionCreators from "../actions/ActionCreators.js";
import LatencyGenerator from "../../stream-data/generators/LatencyGenerator.js";
import LatencyStatsGenerator from "../../stream-data/generators/LatencyStatsGenerator.js";
import LatencyPercentilesGenerator from "../../stream-data/generators/LatencyPercentilesGenerator.js";
import ThroughputGenerator from "../../stream-data/generators/ThroughputGenerator.js";
import ThroughputStatsGenerator from "../../stream-data/generators/ThroughputStatsGenerator.js";
import {seconds, minutes} from "../../util/Duration.js";
import Splitters from "./Splitters.js";

function channelHubToDispatcherWith(connector) {
    connector.connectTo("system")
        .dispatchOn("msc-status", ActionCreators[Actions.RECEIVE_MSC_SYSTEM_STATUS.actionType]);

    connector.connectTo("system")
        .dispatchOn("clc-status", ActionCreators[Actions.RECEIVE_CLC_SYSTEM_STATUS.actionType]);

    connector.connectTo("pipelines")
        .dispatchOn("latency", Splitters.latencies);

    connector.connectTo("pipelines")
        .dispatchOn("latency-stats", Splitters.latencyStats);

    connector.connectTo("pipelines")
        .dispatchOn("latency-stats-all-time", Splitters.allTimeLatencyStats);

    connector.connectTo("pipelines")
        .dispatchOn("throughput", Splitters.throughputs);

    connector.connectTo("pipelines")
        .dispatchOn("throughput-stats", Splitters.throughputStats);

    connector.connectTo("pipelines")
        .dispatchOn("throughput-stats-all-time", Splitters.allTimeThroughputStats);

    connector.connectTo("pipelines")
        .dispatchOn("client-limit-status", ActionCreators[Actions.RECEIVE_CLIENT_LIMIT_STATUS.actionType]);

    connector.connectTo("pipelines")
        .dispatchOn("price-spread-status", ActionCreators[Actions.RECEIVE_PRICE_SPREAD_STATUS.actionType]);

    connector.connectTo("pipelines")
        .dispatchOn("market-data-status", ActionCreators[Actions.RECEIVE_MARKET_DATA_STATUS.actionType]);

    connector.connectTo("rejected-orders")
        .dispatchOn("client-order", ActionCreators[Actions.RECEIVE_CLIENT_ORDER.actionType]);

    connector.connectTo("rejected-orders")
        .dispatchOn("client-order-summaries", ActionCreators[Actions.RECEIVE_CLIENT_ORDER_SUMMARIES.actionType]);

    connector.connectTo("rejected-orders")
        .dispatchOn("gross-notional", ActionCreators[Actions.RECEIVE_GROSS_NOTIONAL.actionType]);

    connector.connectTo("rejected-orders")
        .dispatchOn("client-limit", ActionCreators[Actions.RECEIVE_CLIENT_LIMIT.actionType]);

    connector.connectTo("pipelines")
        .dispatchOn("latency-all-time", Splitters.allTimeLatencyPercentiles);
}

function mockStreamToDispatcherWith(streamConnector) {
    streamConnector.connect(new LatencyGenerator())
        .withTransformer(Splitters.latencies)
        .onChannel("pipelines")
        .forMsgType("latency")
        .start();

    streamConnector.connect(new ThroughputGenerator())
        .withTransformer(Splitters.throughputs)
        .onChannel("pipelines")
        .forMsgType("throughput")
        .start();

    streamConnector.connect(new LatencyPercentilesGenerator())
        .withTransformer(Splitters.allTimeLatencyPercentiles)
        .onChannel("pipelines")
        .forMsgType("latency-all-time")
        .start();
}

export default {
    channelHubToDispatcherWith: channelHubToDispatcherWith,
    mockStreamToDispatcherWith: mockStreamToDispatcherWith
}



