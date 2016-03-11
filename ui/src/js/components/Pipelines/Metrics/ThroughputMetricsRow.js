import React from "react";
import {Col, Row} from "react-bootstrap";
import { formatThroughput } from "../../../util/Format";

export default class ThroughputMetricsRow extends React.Component {
	shouldComponentUPdate(nextProps, nextState) {
		return this.props.stats !== nextProps.stats;
	}
	render() {
		return(
			<Row className="metrics-row">
				<Col lg={4}><p>{formatThroughput(this.props.stats.get("throughputMinimum"))}</p></Col>
				<Col lg={4}><p>{formatThroughput(this.props.stats.get("throughputMedian"))}</p></Col>
				<Col lg={4}><p>{formatThroughput(this.props.stats.get("throughputMaximum"))}</p></Col>
			</Row>
		)
	}
}