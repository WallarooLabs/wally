import React from "react"
import { Col } from "react-bootstrap"

export default class StatsTableHeader extends React.Component {
	shouldComponentUpdate(nextProps, nextState) {
		return false;
	}
	render() {
		return(
			<tr>
				<th></th>
				<th>
					<Col lg={4}>50% of latencies are:</Col>
					<Col lg={4}>75% of latencies are:</Col>
					<Col lg={4}>90% of latencies are:</Col>
				</th>
				<th>
					<Col lg={4}>Minimum</Col>
					<Col lg={4}>Median</Col>
					<Col lg={4}>Maximum</Col>
				</th>
			</tr>
		)
	}
}