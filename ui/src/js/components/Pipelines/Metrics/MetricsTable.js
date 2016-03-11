import React from "react";
import { Table, Grid, Row, Col } from "react-bootstrap";
import LatencyMetricsRow from "./LatencyMetricsRow";
import ThroughputMetricsRow from "./ThroughputMetricsRow";


export default class MetricsTable extends React.Component {
	shouldComponentUpdate(nextProps, nextState) {
		if (this.props.metric == "latency") {
			return this.props.stats.get("latency") !== nextProps.stats.get("latency");
		} else {
			return this.props.stats.get("throughput") !== nextProps.stats.get("throughput");
		}
	}
	render() {
		return(
			<div>
				{ this.props.metric == "latency" ? 
						<LatencyMetricsRow stats={this.props.stats.get("latency")} /> :
						<ThroughputMetricsRow stats={this.props.stats.get("throughput")} />
				}
			</div>
		)
	}
}