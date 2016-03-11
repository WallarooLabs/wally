import React from 'react';
import MonitoringGraphs from "./MonitoringGraphs.js";
import {combineStats, compilePercentiles} from "../../../components/Pipelines/calc/PipelineStatsCalc.js";
import {Map} from "immutable";
import {filterLast5Minutes} from "../../../util/BenchmarksHelpers";
import {throughputInThousands, latencyInMilliseconds} from "../../../util/Format";
import Comparators from "../../../util/Comparators";

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
        const latencyPercentiles = this.props.latencyPercentiles;
        return (
            <MonitoringGraphs
                latencyChartData={this.toChartData(last5MinLatencies, "latency")}
                throughputChartData={this.toChartData(last5MinThroughputs, "throughput")}
                chartInterval={this.props.chartInterval}
                latencyPercData={latencyPercentiles}
                />
        )
    }
}