import React from "react"
import { Glyphicon } from "react-bootstrap"
import shallowCompare from "react-addons-shallow-compare"

export default class RejectedClientOrderSummariesTableHeader extends React.Component {
	shouldComponentUpdate(nextProps, nextState) {
		return shallowCompare(this, nextProps, nextState);
	}
	sortSymbol(prop) {
		let sortGlyph;
		let colorClass;
		const { sortedProp, ascending } = this.props;
		if (sortedProp == prop) {
			sortGlyph = ascending ? "sort-by-attributes" : "sort-by-attributes-alt";
			colorClass = "";
		} else {
			sortGlyph = "sort";
			colorClass = "text-muted";
		}
		return <Glyphicon glyph={sortGlyph} className={colorClass} />;
	}
	colToggleSort(prop) {
		this.props.toggleSort(prop);
	}
	render() {
		return(
			<thead>
				<tr>
					<th onClick={this.colToggleSort.bind(this, "client_id")} className="hover-pointer">
						Client {this.sortSymbol("client_id")}
					</th>
					<th onClick={this.colToggleSort.bind(this, "total_orders")} className="hover-pointer">
						Total Orders {this.sortSymbol("total_orders")}
					</th>
					<th onClick={this.colToggleSort.bind(this, "rejected_count")} className="hover-pointer">
						Number of Rejected Orders {this.sortSymbol("rejected_count")}
					</th>
					<th onClick={this.colToggleSort.bind(this, "rejected_pct")} className="hover-pointer">
						% of Orders Rejected {this.sortSymbol("rejected_pct")}
					</th>
				</tr>
			</thead>
		)
	}
}