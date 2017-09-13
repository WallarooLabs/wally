import Actions from "../actions/Actions.js";
import ActionCreators from "../actions/ActionCreators.js";


function channelHubToDispatcherWith(connector) {
    connector.connectTo("applications")
        .dispatchOn("app-names", ActionCreators[Actions.RECEIVE_APP_NAMES.actionType]);
}

function connectSourceMetricsChannel(connector, sourceType, channelName) {
    dispatchMetricsForSource(connector, sourceType, channelName);
}
function connectSourceMetricsChannels(connector, sourceType, sourceName) {
    const channelName = sourceType + ":" + sourceName;
    dispatchMetricsForSource(connector, sourceType, channelName);
}

function appConfigsToDispatcherWith(connector, appConfigs) {
    let appName;
    appConfigs.forEach((appConfig) => {
        appName = appConfig.get("app_name");
        connector.connectTo("app-config:" + appName)
            .dispatchOn("app-config", ActionCreators[Actions.RECEIVE_APP_CONFIG.actionType]);
    });
}

function metricsChannelsToDispatcherWith(connector, appConfig) {
    let metrics = appConfig.get("metrics");
    let stepChannels = metrics.get("computation");
    stepMetricsChannelToDispatcherWith(connector, stepChannels);
    let ingressEgressChannels = metrics.get("node-ingress-egress");
    ingressEgressMetricsChannelToDispatcherWith(connector, ingressEgressChannels);
    let sourceSinkChannels = metrics.get("start-to-end");
    sourceSinkMetricsChannelToDispatcherWith(connector, sourceSinkChannels)
    let pipelineChannels = metrics.get("pipeline")
    pipelineMetricsChannelToDispatcherWith(connector, pipelineChannels);
    let pipelineIngestionChannels = metrics.get("pipeline-ingestion")
    pipelineIngestionMetricsChannelToDispatcherWith(connector, pipelineIngestionChannels);
}

function workerMetricsChannelsToDispatcherWith(connector, appConfig, workerName) {
    let metrics = appConfig.get("metrics");
    let stepByWorkerChannels = metrics.getIn(["computation-by-worker", workerName]);
    stepMetricsByWorkerToDispatcherWith(connector, stepByWorkerChannels);
    let ingressEgressChannels = metrics.get("node-ingress-egress");
    ingressEgressMetricsChannelToDispatcherWith(connector, ingressEgressChannels);
    let ingressEgressByPipelineChannels = metrics.getIn(["node-ingress-egress-by-pipeline", workerName]);
    ingressEgressMetricsByPipelineToDispatcherWith(connector, ingressEgressByPipelineChannels);
}

function stepMetricsChannelToDispatcherWith(connector, channels) {
    channels.forEach((channel) => {
        dispatchMetricsForSource(connector, "computation", channel);
    });
}

function stepMetricsByWorkerToDispatcherWith(connector, channels) {
    channels.forEach((channel) => {
        dispatchMetricsForSource(connector, "computation-by-worker", channel);
    });
}

function ingressEgressMetricsChannelToDispatcherWith(connector, channels) {
    channels.forEach((channel) => {
        dispatchMetricsForSource(connector, "node-ingress-egress", channel);
    });
}

function ingressEgressMetricsByPipelineToDispatcherWith(connector, channels) {
    channels.forEach((channel) => {
        dispatchMetricsForSource(connector, "node-ingress-egress-by-pipeline", channel);
    });
}

function sourceSinkMetricsChannelToDispatcherWith(connector, channels) {
    channels.forEach((channel) => {
        dispatchMetricsForSource(connector, "start-to-end", channel);
    });
}

function sourceSinkMetricsByWorkerChannelToDispatcherWith(connector, channels) {
    channels.forEach((channel) => {
        dispatchMetricsForSource(connector, "start-to-end-by-worker", channel);
    });
}

function pipelineMetricsChannelToDispatcherWith(connector, channels) {
    channels.forEach((channel) => {
        dispatchMetricsForSource(connector, "pipeline", channel);
    });
}

function pipelineIngestionMetricsChannelToDispatcherWith(connector, channels) {
    channels.forEach((channel) => {
        dispatchMetricsForSource(connector, "pipeline-ingestion", channel);
    });
}

function wordCountReportChannelToDispatcherWith(connector) {
    connector.connectTo("reports:word-count")
        .dispatchOn("word-count-msgs", ActionCreators[Actions.RECEIVE_WORD_COUNT_REPORT_MSGS.actionType])
}

function dispatchMetricsForSource(connector, sourceType, channel) {
    switch(sourceType) {
        case "start-to-end":
            connector.connectTo(channel)
                .dispatchOn("initial-total-throughputs:last-1-sec", ActionCreators[Actions.RECEIVE_SOURCE_SINK_INITIAL_TOTAL_THROUGHPUTS.actionType])
                .dispatchOn("latency-percentage-bins:last-5-mins", ActionCreators[Actions.RECEIVE_SOURCE_SINK_LATENCY_PERCENTAGE_BINS.actionType])
                .dispatchOn("total-throughput:last-1-sec", ActionCreators[Actions.RECEIVE_SOURCE_SINK_TOTAL_THROUGHPUT.actionType])
                .dispatchOn("throughput-stats:last-5-mins", ActionCreators[Actions.RECEIVE_SOURCE_SINK_THROUGHPUT_STATS.actionType])
                .dispatchOn("latency-percentile-bin-stats:last-5-mins", ActionCreators[Actions.RECEIVE_SOURCE_SINK_LATENCY_PERCENTILE_BIN_STATS.actionType]);
            break;
        case "start-to-end-by-worker":
            connector.connectTo(channel)
                .dispatchOn("initial-total-throughputs:last-1-sec", ActionCreators[Actions.RECEIVE_SOURCE_SINK_BY_WORKER_INITIAL_TOTAL_THROUGHPUTS.actionType])
                .dispatchOn("latency-percentage-bins:last-5-mins", ActionCreators[Actions.RECEIVE_SOURCE_SINK_BY_WORKER_LATENCY_PERCENTAGE_BINS.actionType])
                .dispatchOn("total-throughput:last-1-sec", ActionCreators[Actions.RECEIVE_SOURCE_SINK_BY_WORKER_TOTAL_THROUGHPUT.actionType])
                .dispatchOn("throughput-stats:last-5-mins", ActionCreators[Actions.RECEIVE_SOURCE_SINK_BY_WORKER_THROUGHPUT_STATS.actionType])
                .dispatchOn("latency-percentile-bin-stats:last-5-mins", ActionCreators[Actions.RECEIVE_SOURCE_SINK_BY_WORKER_LATENCY_PERCENTILE_BIN_STATS.actionType]);
            break;
        case "computation":
            connector.connectTo(channel)
                .dispatchOn("initial-total-throughputs:last-1-sec", ActionCreators[Actions.RECEIVE_STEP_INITIAL_TOTAL_THROUGHPUTS.actionType])
                .dispatchOn("latency-percentage-bins:last-5-mins", ActionCreators[Actions.RECEIVE_STEP_LATENCY_PERCENTAGE_BINS.actionType])
                .dispatchOn("total-throughput:last-1-sec", ActionCreators[Actions.RECEIVE_STEP_TOTAL_THROUGHPUT.actionType])
                .dispatchOn("throughput-stats:last-5-mins", ActionCreators[Actions.RECEIVE_STEP_THROUGHPUT_STATS.actionType])
                .dispatchOn("latency-percentile-bin-stats:last-5-mins", ActionCreators[Actions.RECEIVE_STEP_LATENCY_PERCENTILE_BIN_STATS.actionType]);
            break;
        case "computation-by-worker":
            connector.connectTo(channel)
                .dispatchOn("initial-total-throughputs:last-1-sec", ActionCreators[Actions.RECEIVE_STEP_BY_WORKER_INITIAL_TOTAL_THROUGHPUTS.actionType])
                .dispatchOn("latency-percentage-bins:last-5-mins", ActionCreators[Actions.RECEIVE_STEP_BY_WORKER_LATENCY_PERCENTAGE_BINS.actionType])
                .dispatchOn("total-throughput:last-1-sec", ActionCreators[Actions.RECEIVE_STEP_BY_WORKER_TOTAL_THROUGHPUT.actionType])
                .dispatchOn("throughput-stats:last-5-mins", ActionCreators[Actions.RECEIVE_STEP_BY_WORKER_THROUGHPUT_STATS.actionType])
                .dispatchOn("latency-percentile-bin-stats:last-5-mins", ActionCreators[Actions.RECEIVE_STEP_BY_WORKER_LATENCY_PERCENTILE_BIN_STATS.actionType]);
            break;
        case "node-ingress-egress":
            connector.connectTo(channel)
                .dispatchOn("initial-total-throughputs:last-1-sec", ActionCreators[Actions.RECEIVE_INGRESS_EGRESS_INITIAL_TOTAL_THROUGHPUTS.actionType])
                .dispatchOn("latency-percentage-bins:last-5-mins", ActionCreators[Actions.RECEIVE_INGRESS_EGRESS_LATENCY_PERCENTAGE_BINS.actionType])
                .dispatchOn("total-throughput:last-1-sec", ActionCreators[Actions.RECEIVE_INGRESS_EGRESS_TOTAL_THROUGHPUT.actionType])
                .dispatchOn("throughput-stats:last-5-mins", ActionCreators[Actions.RECEIVE_INGRESS_EGRESS_THROUGHPUT_STATS.actionType])
                .dispatchOn("latency-percentile-bin-stats:last-5-mins", ActionCreators[Actions.RECEIVE_INGRESS_EGRESS_LATENCY_PERCENTILE_BIN_STATS.actionType]);
            break;
        case "node-ingress-egress-by-pipeline":
            connector.connectTo(channel)
                .dispatchOn("initial-total-throughputs:last-1-sec", ActionCreators[Actions.RECEIVE_INGRESS_EGRESS_BY_PIPELINE_INITIAL_TOTAL_THROUGHPUTS.actionType])
                .dispatchOn("latency-percentage-bins:last-5-mins", ActionCreators[Actions.RECEIVE_INGRESS_EGRESS_BY_PIPELINE_LATENCY_PERCENTAGE_BINS.actionType])
                .dispatchOn("total-throughput:last-1-sec", ActionCreators[Actions.RECEIVE_INGRESS_EGRESS_BY_PIPELINE_TOTAL_THROUGHPUT.actionType])
                .dispatchOn("throughput-stats:last-5-mins", ActionCreators[Actions.RECEIVE_INGRESS_EGRESS_BY_PIPELINE_THROUGHPUT_STATS.actionType])
                .dispatchOn("latency-percentile-bin-stats:last-5-mins", ActionCreators[Actions.RECEIVE_INGRESS_EGRESS_BY_PIPELINE_LATENCY_PERCENTILE_BIN_STATS.actionType]);
            break;
        case "pipeline":
            connector.connectTo(channel)
                .dispatchOn("initial-total-throughputs:last-1-sec", ActionCreators[Actions.RECEIVE_PIPELINE_INITIAL_TOTAL_THROUGHPUTS.actionType])
                .dispatchOn("latency-percentage-bins:last-5-mins", ActionCreators[Actions.RECEIVE_PIPELINE_LATENCY_PERCENTAGE_BINS.actionType])
                .dispatchOn("total-throughput:last-1-sec", ActionCreators[Actions.RECEIVE_PIPELINE_TOTAL_THROUGHPUT.actionType])
                .dispatchOn("throughput-stats:last-5-mins", ActionCreators[Actions.RECEIVE_PIPELINE_THROUGHPUT_STATS.actionType])
                .dispatchOn("latency-percentile-bin-stats:last-5-mins", ActionCreators[Actions.RECEIVE_PIPELINE_LATENCY_PERCENTILE_BIN_STATS.actionType]);
            break;
        case "pipeline-ingestion":
            connector.connectTo(channel)
                .dispatchOn("initial-total-throughputs:last-1-sec", ActionCreators[Actions.RECEIVE_PIPELINE_INGESTION_INITIAL_TOTAL_THROUGHPUTS.actionType])
                .dispatchOn("total-throughput:last-1-sec", ActionCreators[Actions.RECEIVE_PIPELINE_INGESTION_TOTAL_THROUGHPUT.actionType])
                .dispatchOn("throughput-stats:last-5-mins", ActionCreators[Actions.RECEIVE_PIPELINE_INGESTION_THROUGHPUT_STATS.actionType])
            break;
    }
}

export default {
    channelHubToDispatcherWith: channelHubToDispatcherWith,
    appConfigsToDispatcherWith: appConfigsToDispatcherWith,
    metricsChannelsToDispatcherWith: metricsChannelsToDispatcherWith,
    stepMetricsChannelToDispatcherWith: stepMetricsChannelToDispatcherWith,
    ingressEgressMetricsChannelToDispatcherWith: ingressEgressMetricsChannelToDispatcherWith,
    sourceSinkMetricsChannelToDispatcherWith: sourceSinkMetricsChannelToDispatcherWith,
    pipelineMetricsChannelToDispatcherWith: pipelineMetricsChannelToDispatcherWith,
    pipelineIngestionMetricsChannelToDispatcherWith: pipelineIngestionMetricsChannelToDispatcherWith,
    wordCountReportChannelToDispatcherWith: wordCountReportChannelToDispatcherWith,
    connectSourceMetricsChannels: connectSourceMetricsChannels,
    workerMetricsChannelsToDispatcherWith: workerMetricsChannelsToDispatcherWith,
    connectSourceMetricsChannel: connectSourceMetricsChannel
}
