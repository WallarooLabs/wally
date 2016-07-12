import React from "react"
import shallowCompare from "react-addons-shallow-compare"
import { titleize } from "../../../util/Format"

export default class DashboardHeader extends React.Component {
	shouldComponentUpdate(nextProps, nextState) {
		return shallowCompare(this, nextProps, nextState);
	}
	render() {
		const {sourceType, sourceName} = this.props;
		let sourceHeader;
		switch(sourceType) {
			case "step":
				sourceHeader = "Step";
				break;
			case "ingress-egress":
				sourceHeader = "Boundary";
				break;
			case "source-sink":
				sourceHeader = "Overall";
				break;
		}
		return(
			<h1>{sourceHeader + ": " + titleize(sourceName)}</h1>
		)
	}
}