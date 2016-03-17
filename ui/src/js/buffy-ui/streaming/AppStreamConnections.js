import Actions from "../actions/Actions.js";
import ActionCreators from "../actions/ActionCreators.js";
import LatencyPercentilesGenerator from "../../stream-data/generators/LatencyPercentilesGenerator.js";
import ThroughputGenerator from "../../stream-data/generators/ThroughputGenerator.js";
import {seconds, minutes} from "../../util/Duration.js";
import Splitters from "./Splitters.js";
import PipelineKeys from "../constants/PipelineKeys";

function channelHubToDispatcherWith(connector) {
    connector.connectTo("pipeline:market-spread-total")
        .dispatchOn("latency-percentiles:last-5-mins", Splitters.latencies);

    connector.connectTo("pipeline:market-spread-total")
        .dispatchOn("latency-percentiles:last-5-mins", Splitters.allTimeLatencyPercentiles);

    connector.connectTo("pipeline:market-spread-total")
        .dispatchOn("total-throughput:last-1-sec", Splitters.throughputs);

    connector.connectTo("pipeline:market-spread-node-1")
        .dispatchOn("latency-percentiles:last-5-mins", Splitters.latencies);

    connector.connectTo("pipeline:market-spread-node-1")
        .dispatchOn("latency-percentiles:last-5-mins", Splitters.allTimeLatencyPercentiles);

    connector.connectTo("pipeline:market-spread-node-1")
        .dispatchOn("total-throughput:last-1-sec", Splitters.throughputs);

    connector.connectTo("pipeline:market-spread-node-2")
        .dispatchOn("latency-percentiles:last-5-mins", Splitters.latencies);

    connector.connectTo("pipeline:market-spread-node-2")
        .dispatchOn("latency-percentiles:last-5-mins", Splitters.allTimeLatencyPercentiles);

    connector.connectTo("pipeline:market-spread-node-2")
        .dispatchOn("total-throughput:last-1-sec", Splitters.throughputs);
}

function mockStreamToDispatcherWith(streamConnector) {
    streamConnector.connect(new ThroughputGenerator(PipelineKeys.PRICE_SPREAD))
        .withTransformer(Splitters.throughputs)
        .onChannel("pipeline:market-spread-total")
        .forMsgType("total-throughput:last-1-sec")
        .start();

    streamConnector.connect(new LatencyPercentilesGenerator(PipelineKeys.PRICE_SPREAD))
        .withTransformer(Splitters.allTimeLatencyPercentiles)
        .onChannel("pipeline:market-spread-total")
        .forMsgType("latency-percentiles:last-5-mins")
        .start();

    streamConnector.connect(new ThroughputGenerator(PipelineKeys.NODE_1))
        .withTransformer(Splitters.throughputs)
        .onChannel("pipeline:market-spread-node-1")
        .forMsgType("total-throughput:last-1-sec")
        .start();

    streamConnector.connect(new LatencyPercentilesGenerator(PipelineKeys.NODE_1))
        .withTransformer(Splitters.allTimeLatencyPercentiles)
        .onChannel("pipeline:market-spread-node-1")
        .forMsgType("latency-percentiles:last-5-mins")
        .start();

    streamConnector.connect(new ThroughputGenerator(PipelineKeys.NODE_2))
        .withTransformer(Splitters.throughputs)
        .onChannel("pipeline:market-spread-node-2")
        .forMsgType("total-throughput:last-1-sec")
        .start();

    streamConnector.connect(new LatencyPercentilesGenerator(PipelineKeys.NODE_2))
        .withTransformer(Splitters.allTimeLatencyPercentiles)
        .onChannel("pipeline:market-spread-node-2")
        .forMsgType("latency-percentiles:last-5-mins")
        .start();
}

export default {
    channelHubToDispatcherWith: channelHubToDispatcherWith,
    mockStreamToDispatcherWith: mockStreamToDispatcherWith
}



