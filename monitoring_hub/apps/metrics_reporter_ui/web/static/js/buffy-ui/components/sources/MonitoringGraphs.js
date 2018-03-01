import React from "react"
import LineChart from "../../../components/charts/LineChart"
import BarChart from "../../../components/charts/BarChart"
import { formatLatencyBin } from "../../../util/Format"
import {Row, Col, Panel} from "react-bootstrap"
import {toSeconds} from "../../../util/Duration"
import ChartHeader from "./ChartHeader"
import Immutable from "immutable"

export default class MonitoringGraphs extends React.Component {
	shouldComponentUpdate(nextProps) {
		return !Immutable.is(this.props.latencyPercentageBinData, nextProps.latencyPercentageBinData) || !Immutable.is(this.props.throughputChartData, nextProps.throughputChartData);
	}
	render() {
		const {chartInterval, latencyPercentageBinData, throughputChartData} = this.props;
		return(
			<div>
				<Row>
					<Panel>
						<Col md={6}>
							<ChartHeader chartInterval={chartInterval} title="Percent by Latency Bin"/>
							<BarChart
								data={this.props.latencyPercentageBinData}
								h="400"
								w="600"
								yLeftLabel="Percent by Bin"
								xTickFormatter={formatLatencyBin}
								yLeftDomain={[0,100]} />
						</Col>
						<Col md={6}>
							<ChartHeader chartInterval={chartInterval} title="Throughput"/>
							<LineChart
								data={throughputChartData}
								h="400"
								w="600"
								yLeftLabel="Throughput (msgs/sec)"
								colorForLine1="teal"
								interpolation="linear"
								interval={toSeconds(chartInterval)} />
						</Col>
					</Panel>
				</Row>
			</div>
		)
	}
}
