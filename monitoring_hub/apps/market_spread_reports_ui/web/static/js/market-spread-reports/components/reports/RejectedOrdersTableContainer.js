import React from "react"
import RejectedOrdersTable from "./RejectedOrdersTable"
import { fromJS } from "immutable"
import Comparators from "../../../util/Comparators"

export default class RejectedOrdersTableContainer extends React.Component {
	constructor(props) {
		super(props);
		const { rejectedOrders } = this.props;
		this.state = {
			ascending: false,
			sortByProp: "UCID"
		};
	}
	sortRejectedOrders(rejectedOrders, prop) {
		if(this.state.ascending) {
			return rejectedOrders.sort(Comparators.propFor(prop));
		} else {
			return rejectedOrders.sort(Comparators.reverseOf(Comparators.propFor(prop)));
		}
	}
	toggleSort(prop) {
		const ascendingState = this.state.sortByProp == prop ? !this.state.ascending : this.state.ascending;
		this.setState({
			sortByProp: prop,
			ascending: ascendingState
		});
	}
	render() {
		const { rejectedOrders } = this.props;
		const { ascending, sortByProp } = this.state;
		const sortedRejectedOrders = this.sortRejectedOrders(rejectedOrders, sortByProp);
		return(
			<RejectedOrdersTable
				rejectedOrders={sortedRejectedOrders}
				ascending={this.state.ascending}
				toggleSort={this.toggleSort.bind(this)}
				sortedProp={sortByProp} />
		)
	}
}
