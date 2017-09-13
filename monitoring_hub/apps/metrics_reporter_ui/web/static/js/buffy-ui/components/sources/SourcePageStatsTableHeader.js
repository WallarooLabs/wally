import React from "react"
import { Col } from "react-bootstrap"

export default class SourcePageStatsTableHeader extends React.Component {
	shouldComponentUpdate(nextProps, nextState) {
		return false;
	}
	render() {
		return(
			<tr>
				<th lg={6}>
					<Col lg={2}>50% are:</Col>
					<Col lg={2}>95% are:</Col>
					<Col lg={2}>99% are:</Col>
					<Col lg={2}>99.9% are:</Col>
					<Col lg={3}>99.99% are:</Col>
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
