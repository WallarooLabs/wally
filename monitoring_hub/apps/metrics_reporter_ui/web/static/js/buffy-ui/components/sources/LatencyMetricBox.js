import React from "react"
import { Col, Panel } from "react-bootstrap"
import { formatLatencyBin } from "../../../util/Format"

export default class LatencyMetricBox extends React.Component {
	render() {
		const { value, title } = this.props;
		return(
			<Panel>
				{title}
				<h3>{formatLatencyBin(value)}</h3>
			</Panel>
		)
	}
}