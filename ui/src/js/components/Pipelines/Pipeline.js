import React from 'react';
import PipelineContainer from "./PipelineContainer.js";
import {combineStats, compilePercentiles} from "./calc/PipelineStatsCalc.js";
import {Map} from "immutable";
import {filterLast5Minutes} from "../../util/BenchmarksHelpers";
import {throughputInThousands, latencyInMilliseconds} from "../../util/Format";
import Comparators from "../../util/Comparators";

export default class Pipeline extends React.Component {
    toChartData(data, metric) {
        const chartData = data.map(d => new Map({
            x: d.get("time"),
            y: d.get(metric)
        }));

        return new Map({
            line: chartData
        });
    }
    render() {
        const last5MinLatencies = latencyInMilliseconds(filterLast5Minutes(this.props.latencies));
        const last5MinThroughputs = throughputInThousands(filterLast5Minutes(this.props.throughputs));
        const sortedLatencies = this.props.latencies.sort(Comparators.propFor("latency"));
        const latencyStats = this.props.stats.get("latencyStats");
        const throughputStats = this.props.stats.get("throughputStats");
        const stats = combineStats(latencyStats, throughputStats);
        const latencyPercentiles = this.props.latencyPercentiles;
        return (
            <PipelineContainer
                title={this.props.title}
                description={this.props.title}
                status={this.props.status}
                latencyChartData={this.toChartData(last5MinLatencies, "latency")}
                throughputChartData={this.toChartData(last5MinThroughputs, "throughput")}
                chartInterval={this.props.chartInterval}
                stats={stats}
                latencyPercData={latencyPercentiles}
                pipelineKey={this.props.pipelineKey}
            />
        )
    }
}