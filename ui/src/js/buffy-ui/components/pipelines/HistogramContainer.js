import React from "react";
import {Col, Row, Tabs, Tab} from "react-bootstrap";
import LineChart from "../../../components/charts/LineChart";
import {Map, List} from "immutable";
import Comparators from "../../../util/Comparators";
import LatencyPercentileDataRow from "../../../components/Pipelines/Metrics/LatencyPercentileDataRow";
import {minutes} from "../../../util/Duration";

export default class HistogramContainer extends React.Component {
    latenciesToPercChartData(data) {
        let chartData = List();
        data.forEach((value,percentile) => {
            chartData = chartData.push(new Map({
                x: 1 / (1 - (parseFloat(percentile)/100)),
                y: value / 1000
            }));
        });
        chartData = chartData.sort(Comparators.propFor("x"));
        return new Map({
            line: chartData
        });
    }
    latenciesToLinearPercChartData(data) {
        let chartData = List();
        data.forEach((value, percentile) => {
            if (parseFloat(percentile) > 99.9) {
                chartData;
            } else {
                chartData = chartData.push(new Map({
                    x: percentile,
                    y: value / 1000
                }));
            }
        });
        chartData = chartData.sort(Comparators.propFor("x"));
        return new Map({
            line: chartData
        });
    }
    percentileChartXTickFormatter(d) {
        return parseFloat((((d - 1 )/ d) * 100).toFixed(5)) + "%"
    }
    percentileLinearChartXTickFormatter(d) {
        return parseFloat(d) + "%"
    }
    render() {
        return(
                <Col md={4}>
                    <Col md={10}>
                        <h5 className="text-center">Latency Tail: Last 5 Minutes</h5>
                    </Col>
                    <LineChart
                        data={this.latenciesToLinearPercChartData(this.props.latencyPercData)}
                        h="300"
                        w="400"
                        yLeftLabel="Latency (ms)"
                        xLogScale={false}
                        xPowScale={true}
                        xPowScaleExponent={4}
                        xTicks={[0,50,75, 90, 99, 99.9]}
                        xTickFormatter={this.percentileLinearChartXTickFormatter}
                        />
                </Col>
        )
    }
}

//                     <LatencyPercentileDataRow data={this.props.latencyPercData}/>
