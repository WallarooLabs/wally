import React from "react"
import BenchmarksStore from "../../stores/BenchmarksStore"
import AllTimeLatencyPercentileStore from "../../stores/AllTimeLatencyPercentileStore"
import Pipeline from "../../../components/Pipelines/Pipeline"
import {filterLast5Minutes} from "../../../util/BenchmarksHelpers"
import {minutes} from "../../../util/Duration"
import {throughputInThousands} from "../../../util/Format"
import MonitoringGraphsContainer from "./MonitoringGraphsContainer"

export default class PipelineBox extends React.Component {
    constructor(props) {
        super(props);
        const systemKey = this.props.systemKey;
        const pipelineKey = this.props.pipelineKey;
        const latencyPercentiles = AllTimeLatencyPercentileStore.getPipelineLatencyPercentiles(systemKey, pipelineKey);
        const pipelineLatencies = BenchmarksStore.getPipelineLatencies(systemKey, pipelineKey);
        const pipelineThroughputs = BenchmarksStore.getPipelineThroughputs(systemKey, pipelineKey);
        const latencies = filterLast5Minutes(pipelineLatencies);
        const throughputs = filterLast5Minutes(pipelineThroughputs);
        this.state = {
            latencies: latencies,
            throughputs: throughputs,
            latencyPercentiles: latencyPercentiles
        };
        AllTimeLatencyPercentileStore.addListener(function() {
            if (!this.isUnmounted) {
                const latencyPercentiles = AllTimeLatencyPercentileStore.getPipelineLatencyPercentiles(systemKey, pipelineKey);
                this.setState({
                    latencyPercentiles: latencyPercentiles
                });
            }
        }.bind(this));
        BenchmarksStore.addListener(function() {
            if (!this.isUnmounted) {
                const pipelineLatencies = BenchmarksStore.getPipelineLatencies(systemKey, pipelineKey);
                const pipelineThroughputs = BenchmarksStore.getPipelineThroughputs(systemKey, pipelineKey);
                const latencies = filterLast5Minutes(pipelineLatencies);
                const throughputs = filterLast5Minutes(pipelineThroughputs);
                this.setState({
                    latencies: latencies,
                    throughputs: throughputs
                });
            }
        }.bind(this));
    }
    componentDidMount() {
        this.isUnmounted = false;
    }
    componentWillUnmount() {
        this.isUnmounted = true;
    }
    render() {
        return(
            <MonitoringGraphsContainer
                latencies={this.state.latencies}
                throughputs={this.state.throughputs}
                chartInterval={minutes(5)}
                pipelineKey={this.props.pipelineKey}
                latencyPercentiles={this.state.latencyPercentiles}
                />
        )
    }
}
