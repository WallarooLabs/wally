import React from "react"
import { is } from "immutable"
import { cleanTrailing } from "../../../util/Precision"


export default class RejectedClientOrderSummaryRow extends React.Component {
	shouldComponentUpdate(nextProps) {
		const { summary } = this.props;
		return !is(summary, nextProps.summary);
	}
	render() {
		let { summary } = this.props;
		let rejectedPct = summary.get("rejected_pct").toFixed(4);
		return(
			<tr>
				<td>{summary.get("client_id")}</td>
				<td>{summary.get("total_orders")}</td>
				<td>{summary.get("rejected_count")}</td>
				<td>{rejectedPct}%</td>
			</tr>
		)
	}
}