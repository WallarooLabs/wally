import React from "react"
import { Table } from "react-bootstrap"
import RejectedOrdersTableHeader from "./RejectedOrdersTableHeader"
import RejectedOrderRow from "./RejectedOrderRow"

export default class RejectedOrdersTable extends React.Component {
	render() {
		const rows = [];
		const { rejectedOrders, sortedProp, ascending, toggleSort } = this.props;
		rejectedOrders.forEach((rejectedOrder) => {
			rows.push(<RejectedOrderRow order={rejectedOrder} key={rejectedOrder.get("order_id")} />);
		});
		return(
			<Table striped>
				<RejectedOrdersTableHeader
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