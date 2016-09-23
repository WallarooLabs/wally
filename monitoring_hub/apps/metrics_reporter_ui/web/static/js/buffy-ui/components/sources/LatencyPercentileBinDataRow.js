import React from "react"
import {Col, Row, Panel} from "react-bootstrap"
import LatencyMetricBox from "./LatencyMetricBox"
import {is} from "immutable"

export default class LatencyPercentileBinDataRow extends React.Component {
	shouldComponentUpdate(nextProps) {
		return !is(this.props.latencyPercentileBinStats, nextProps.latencyPercentileBinStats);
	}
	render() {
		const {latencyPercentileBinStats} = this.props;
		return(
			<Row>
				<Panel>
					<h4>Latency Percent Stats</h4>
					<Col lg={2}>
						<LatencyMetricBox value={latencyPercentileBinStats.get("50.0")} title={<p>50% of latencies<br/>are:</p>} />
					</Col>
					<Col lg={2}>
						<LatencyMetricBox value={latencyPercentileBinStats.get("95.0")} title={<p>95% of latencies<br/>are:</p>} />
					</Col>
					<Col lg={2}>
						<LatencyMetricBox value={latencyPercentileBinStats.get("99.0")} title={<p>99% of latencies<br/>are:</p>} />
					</Col>
					<Col lg={2}>
						<LatencyMetricBox value={latencyPercentileBinStats.get("99.9")} title={<p>99.9% of latencies<br/>are:</p>} />
					</Col>
					<Col lg={2}>
						<LatencyMetricBox value={latencyPercentileBinStats.get("99.99")} title={<p>99.99% of latencies<br/>are:</p>} />
					</Col>
				</Panel>
			</Row>
		)
	}
}