import React from "react"
import { Link } from "react-router"

export default class Reports extends React.Component {
	render() {
		return(
			<div>
				{ this.props.children ||
					<div>
						<Link to="/reports/rejected-orders-report">
							<h1>Rejected Orders Report</h1>
						</Link>
						<Link to="/reports/rejected-client-order-summaries-report">
							<h1>Rejected Client Order Summaries Report</h1>
						</Link>
					</div>
				}
			</div>
		)
	}
}