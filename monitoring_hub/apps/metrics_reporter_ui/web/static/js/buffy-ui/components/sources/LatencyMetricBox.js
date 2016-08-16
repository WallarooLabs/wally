import React from "react"
import { Col, Panel } from "react-bootstrap"
import { formatLatencyBin } from "../../../util/Format"

export default class LatencyMetricBox extends React.Component {
	render() {
		const { value, title } = this.props;
		return(
			<Panel header={title} className="metrics-box">
				<h3 className="text-info">{formatLatencyBin(value)}</h3>
			</Panel>
		)
	}
}