import React from "react";
import {Col} from "react-bootstrap";

export default class MetricsTableHeader extends React.Component {
	shouldComponentUpdate(nextProps, nextState) {
		return false;
	}
	render() {
		return(
			<tr>
			  <th></th>
			  <th></th>
			  <th></th>
			  <th>
			      <Col lg={4}>50th</Col>
			      <Col lg={4}>75th</Col>
			      <Col lg={4}>90th</Col>
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