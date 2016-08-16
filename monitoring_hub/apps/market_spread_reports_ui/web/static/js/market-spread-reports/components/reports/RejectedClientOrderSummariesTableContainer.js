import React from "react"
import RejectedClientOrderSummariesTable from "./RejectedClientOrderSummariesTable"
import { fromJS } from "immutable"
import Comparators from "../../../util/Comparators"

export default class RejectedCLientOrderSummariesTableContainer extends React.Component {
	constructor(props) {
		super(props);
		const { summaries } = this.props;
		this.state = {
			ascending: false,
			sortByProp: "client_id"
		};
	}
	sortSummaries(summaries, prop) {
		const { ascending } = this.state;
		if (ascending) {
			if(prop == "client_id") {
				return summaries.sort(Comparators.propFor("client_id"));
			} else {
				return summaries.sort(Comparators.propFor(prop));
			} 
		} else {
			if (prop == "client_id") {
				return summaries.sort(Comparators.reverseOf(Comparators.propFor("client_id")));
			} else {
				return summaries.sort(Comparators.reverseOf(Comparators.propFor(prop)));
			}
		}
	}
	toggleSort(prop) {
		const { sortByProp, ascending } = this.state;
		const ascendingState = sortByProp == prop ? !ascending : ascending;
		this.setState({
			sortByProp: prop,
			ascending: ascendingState
		});
	}
	render() {
		const { summaries } = this.props;
		const { ascending, sortByProp } = this.state;
		const sortedSummaries = this.sortSummaries(summaries, sortByProp);
		return(
				<RejectedClientOrderSummariesTable
					summaries={sortedSummaries}
					ascending={ascending}
					toggleSort={this.toggleSort.bind(this)}
					sortedProp={sortByProp} />
		)
	}
}