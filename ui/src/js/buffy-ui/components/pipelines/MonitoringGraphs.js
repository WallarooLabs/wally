import React from "react"
import LineChart from "../../../components/charts/LineChart"
import {Grid, Row, Col, Panel } from "react-bootstrap"
import {cleanTrailing} from "../../../util/Precision.js";
import {toMinutes, toSeconds} from "../../../util/Duration.js";
import {displayInterval, formatThroughput} from "../../../util/Format.js";
import HistogramContainer from "./HistogramContainer";

export default class MonitoringGraphs extends React.Component {
    render() {
        return (
            <div>
                <Row>
                    <Panel>
                        <Col md={4}>
                            <Col md={10}>
                                <h5 className="text-center">Last {displayInterval(this.props.chartInterval)} - Median
                                    Latency</h5>
                            </Col>
                            <LineChart
                                data={this.props.latencyChartData}
                                h="300"
                                w="400"
                                yLeftLabel="Latency (ms)"
                                interval={this.props.chartInterval}
                                />
                        </Col>
                        <Col md={4}>
                            <Col md={10}>
                                <h5 className="text-center">Last {displayInterval(this.props.chartInterval)} -
                                    Throughput</h5>
                            </Col>
                            <LineChart
                                data={this.props.throughputChartData}
                                h="300"
                                w="400"
                                yLeftLabel="Throughput (msg/sec)"
                                colorForLine1="red"
                                interval={this.props.chartInterval}
                                />
                        </Col>
                        <HistogramContainer
                            latencyPercData={this.props.latencyPercData}
                            throughputChartData={this.props.throughputChartData}
                        />
                    </Panel>
                </Row>
            </div>
        )
    }
}