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
    connector.connectTo("pipeline:market-spread-total")
        .dispatchOn("latency-percentiles:last-5-mins", Splitters.latencies);

    connector.connectTo("pipeline:market-spread-total")
        .dispatchOn("latency-percentiles:last-5-mins", Splitters.allTimeLatencyStats);

    connector.connectTo("pipeline:market-spread-total")
        .dispatchOn("total-throughput:last-1-sec", Splitters.throughputs);
}

function mockStreamToDispatcherWith(streamConnector) {
    streamConnector.connect(new ThroughputGenerator())
        .withTransformer(Splitters.throughputs)
        .onChannel("pipeline:market-spread-total")
        .forMsgType("total-throughput:last-1-sec")
        .start();

    streamConnector.connect(new LatencyPercentilesGenerator())
        .withTransformer(Splitters.allTimeLatencyPercentiles)
        .onChannel("pipeline:market-spread-total")
        .forMsgType("latency-percentiles:last-5-mins")
        .start();
}

export default {
    channelHubToDispatcherWith: channelHubToDispatcherWith,
    mockStreamToDispatcherWith: mockStreamToDispatcherWith
}



