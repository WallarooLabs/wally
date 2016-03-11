import React from "react"
import {Col, Row} from "react-bootstrap"
import LatencyMetricBox from "./LatencyMetricBox"

export default class LatencyPercentileDataRow extends React.Component {
	constructor(props) {
		super(props);
		this.state = {
			minimum: "-",
			median: "-",
			seventyFifthPerc: "-",
			twoNinesPerc: "-",
			threeNinesPerc: "-"
		};
	}
	componentWillReceiveProps(props) {
		this.setState({
			minimum: props.data.has("0.001") ? props.data.get("0.001") : this.state.minimum,
			median: props.data.has("50.0") ?  props.data.get("50.0") : this.state.median,
			seventyFifthPerc: props.data.has("75.0") ?  props.data.get("75.0") : this.state.seventyFifthPerc,
			twoNinesPerc: props.data.has("99.0") ?  props.data.get("99.0") : this.state.twoNinesPerc,
			threeNinesPerc: props.data.has("99.9") ? props.data.get("99.9") : this.state.threeNinesPerc
		});
	}
	shouldComponentUpdate(nextProps, nextState) {
		return this.props.data !== nextProps.data;
	}
	render() {
		return(
			<Row>
				<Col lg={2}>
					<LatencyMetricBox value={this.state.minimum} title="minimum"/>
				</Col>
				<Col lg={2}>
					<LatencyMetricBox value={this.state.median} title="median"/>
				</Col>
				<Col lg={2}>
					<LatencyMetricBox value={this.state.seventyFifthPerc} title="75%"/>
				</Col>
				<Col lg={2}>
					<LatencyMetricBox value={this.state.twoNinesPerc} title="99%"/>
				</Col>
				<Col lg={2}>
					<LatencyMetricBox value={this.state.threeNinesPerc} title="99.9%"/>
				</Col>
			</Row>
		)
	}
}