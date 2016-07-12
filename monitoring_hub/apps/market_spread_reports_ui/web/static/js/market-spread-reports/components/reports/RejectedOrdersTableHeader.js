import React from "react"
import { Glyphicon } from "react-bootstrap"
import shallowCompare from "react-addons-shallow-compare"

export default class RejectedOrdersTableHeader extends React.Component {
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
					<th>ID</th>
					<th onClick={this.colToggleSort.bind(this, "UCID")} className="hover-pointer">
						UCID {this.sortSymbol("UCID")}
					</th>
					<th onClick={this.colToggleSort.bind(this, "timestamp")} className="hover-pointer">
						Time {this.sortSymbol("timestamp")}
					</th>
					<th>Client</th>
					<th>Symbol</th>
					<th>Symbol Description</th>
					<th>Price</th>
					<th>QTY</th>
					<th>Side</th>
					<th>Bid</th>
					<th>Offer</th>
				</tr>
			</thead>
		)
	}
}