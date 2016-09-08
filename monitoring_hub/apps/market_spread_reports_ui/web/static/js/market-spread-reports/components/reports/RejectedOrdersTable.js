import React from "react"
import { Table } from "react-bootstrap"
import RejectedOrdersTableHeader from "./RejectedOrdersTableHeader"
import RejectedOrderRow from "./RejectedOrderRow"
import ReactCSSTransitionGroup from "react-addons-css-transition-group"

export default class RejectedOrdersTable extends React.Component {
	render() {
		const transitionClasses = {
			enter: "list-group-item-success",
			enterActive: "enterActive",
			leave: "leave",
			leaveActive: "leaveActive"
		}
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
				<ReactCSSTransitionGroup transitionName={transitionClasses}
					transitionEnterTimeout={1750}
					transitionLeaveTimeout={300}
					component="tbody">
					{rows}
				</ReactCSSTransitionGroup>
			</Table>
		)
	}
}