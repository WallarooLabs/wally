import React from "react"
import RejectedOrdersTableContainer from "./RejectedOrdersTableContainer"


export default class RejectedOrdersReport extends React.Component {
	render() {
		const { rejectedOrders } = this.props;
		return(
			<div>
				<h1>Rejected Orders Log</h1>
				<RejectedOrdersTableContainer rejectedOrders={rejectedOrders} />
			</div>
		)
	}

}