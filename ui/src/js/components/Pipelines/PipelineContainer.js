import React from "react"
import PipelineHeader from "./PipelineHeader"
import LineChart from "../charts/LineChart"
import {Grid, Row, Col, Panel } from "react-bootstrap"
import MetricHeader from "./Metrics/MetricHeader"
import MetricBox from "./Metrics/MetricBox"
import {cleanTrailing} from "../../util/Precision.js";
import {toMinutes, toSeconds} from "../../util/Duration.js";
import {displayInterval, formatThroughput} from "../../util/Format.js";
import PipelineTable from "./PipelineTable";
import PipelineDataContainer from "./PipelineDataContainer";

export default class PipelineContainer extends React.Component {
  render() {
    return(
      <div>
        <Row>
          <PipelineTable 
          title={this.props.title}
          status={this.props.status}
          stats={this.props.stats}
          pipelineKey={this.props.pipelineKey} />
        </Row>
        <Row>
          <Panel>
            <Col md={6}>
            <Col md={16}>
              <h5 className="text-center">Last {displayInterval(this.props.chartInterval)} - Median Latency</h5>
            </Col>
            <LineChart
                data={this.props.latencyChartData}
                h="400"
                w="600"
                yLeftLabel="Latency (ms)"
                interval={this.props.chartInterval}
            />
            </Col>
            <Col md={6}>
              <Col md={16}>
                <h5 className="text-center">Last {displayInterval(this.props.chartInterval)} - Throughput</h5>
              </Col>
              <LineChart
                  data={this.props.throughputChartData}
                  h="400"
                  w="600"
                  yLeftLabel="Throughput (msg/sec)"
                  colorForLine1="red"
                  interval={this.props.chartInterval}
              />
            </Col>
          </Panel>
        </Row>
        <Row>
          <Panel>
            <PipelineDataContainer
              latencyPercData={this.props.latencyPercData}
              throughputChartData={this.props.throughputChartData}
            />
          </Panel>
        </Row>
      </div>
    )
  }
}