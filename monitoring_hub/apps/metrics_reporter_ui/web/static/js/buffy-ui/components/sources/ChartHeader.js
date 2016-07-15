import React from "react"
import {Col} from "react-bootstrap"
import {displayInterval} from "../../../util/Format"
import shallowCompare from "react-addons-shallow-compare"

export default class ChartHeader extends React.Component {
	shouldComponentUpdate(nextProps, nextState) {
		return shallowCompare(this, nextProps, nextState);
	}
	render() {
		const {chartInterval, title} = this.props;
		return(
			<Col md={10}>
				<h5 className="text-center">Last {displayInterval(chartInterval)} - {this.props.title}</h5>
			</Col>
		)
	}
}