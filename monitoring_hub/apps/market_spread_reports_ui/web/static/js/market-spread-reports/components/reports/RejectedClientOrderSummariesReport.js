import React from "react"
import RejectedClientOrderSummariesTableContainer from "./RejectedClientOrderSummariesTableContainer"

export default class RejectedClientOrderSummariesReport extends React.Component {
	render() {
		const { clientOrderSummaries } = this.props;
		return(
			<div>
				<h1>Rejected Client Order Summary Log</h1>
				<RejectedClientOrderSummariesTableContainer summaries={clientOrderSummaries} />
			</div>
		)
	}
}