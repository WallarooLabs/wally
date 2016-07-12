import React from "react"
import { Table } from "react-bootstrap"
import RejectedClientOrderSummaryRow from "./RejectedClientOrderSummaryRow"
import RejectedClientOrderSummariesTableHeader from "./RejectedClientOrderSummariesTableHeader"

export default class RejectedClientOrderSummariesTable extends React.Component {
	render() {
		const rows = [];
		const { summaries, sortedProp, ascending, toggleSort } = this.props;
		summaries.forEach((summary) => {
			rows.push(<RejectedClientOrderSummaryRow summary={summary} key={summary.get("client_id")} />);
		});
		return(
			<Table striped>
				<RejectedClientOrderSummariesTableHeader
					ascending={ascending}
					sortedProp={sortedProp}
					toggleSort={toggleSort} />
				<tbody>
					{rows}
				</tbody>
			</Table>
		)
	}
}