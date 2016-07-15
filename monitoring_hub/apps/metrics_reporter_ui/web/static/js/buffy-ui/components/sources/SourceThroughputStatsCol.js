import React from "react"
import { Col } from "react-bootstrap"
import { Link } from "react-router"
import { formatThroughput } from "../../../util/Format"
import { is } from "immutable"

export default class SourceThroughputStatsCol extends React.Component {
	shouldComponentUpdate(nextProps) {
		return !is(this.props.throughputStats, nextProps.throughputStats);
	}
	render() {
		const { throughputStats } = this.props;
		return(
			<div>
				<Col lg={4}><p>{formatThroughput(throughputStats.get("min"))}</p></Col>
				<Col lg={4}><p>{formatThroughput(throughputStats.get("med"))}</p></Col>
				<Col lg={4}><p>{formatThroughput(throughputStats.get("max"))}</p></Col>
			</div>
		)
	}
}
