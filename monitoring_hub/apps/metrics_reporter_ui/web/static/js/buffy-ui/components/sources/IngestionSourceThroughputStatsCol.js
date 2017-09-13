import React from "react"
import { Col } from "react-bootstrap"
import { Link } from "react-router"
import { is } from "immutable"

export default class IngestionSourceThroughputStatsCol extends React.Component {
	shouldComponentUpdate(nextProps) {
		return (
			!is(this.props.throughputStats, nextProps.throughputStats) ||
			!is(this.props.ingestionThroughputStats, nextProps.ingestionThroughputStats)
		);
	}
	render() {
		const { throughputStats, ingestionThroughputStats } = this.props;
		const chickenfoot = " -|< ";
		return(
			<div>
				<Col lg={4}><p>{ingestionThroughputStats.get("min") + chickenfoot + throughputStats.get("min")}</p></Col>
				<Col lg={4}><p>{ingestionThroughputStats.get("med") + chickenfoot + throughputStats.get("med")}</p></Col>
				<Col lg={4}><p>{ingestionThroughputStats.get("max") + chickenfoot + throughputStats.get("max")}</p></Col>
			</div>
		)
	}
}
