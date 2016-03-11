import React from "react";
import {Row, Col} from "react-bootstrap";
import { formatLatency } from "../../../util/Format";

export default class LatencyMetricsRow extends React.Component {
	shouldComponentUpdate(nextProps, nextState) {
		return this.props.stats !== nextProps.stats;
	}
	render() { 
		const {stats} = this.props;
		const pctl50 = stats.get("latency50pctl") == "-" ? stats.get("latency50pctl") : stats.get("latency50pctl") / 1000;
		const pctl75 = stats.get("latency75pctl") == "-" ? stats.get("latency75pctl") : stats.get("latency75pctl") / 1000;
		const pctl90 = stats.get("latency90pctl") == "-" ? stats.get("latency90pctl") : stats.get("latency90pctl") / 1000;
		return(
			<Row className="metrics-row">
				<Col lg={4}><p>{formatLatency(pctl50)}</p></Col>
				<Col lg={4}><p>{formatLatency(pctl75)}</p></Col>
				<Col lg={4}><p>{formatLatency(pctl90)}</p></Col>
			</Row>
		)
	}
}