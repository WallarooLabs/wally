import React from "react"
import { is } from "immutable"
import { numberWithCommas, formatTime } from "../../../util/Format"
import { symbolDescriptions } from "../../../util/Symbols"
import { formatMoney, formatNumber } from "accounting"
import Moment from "moment"

window.Moment1 = Moment;

export default class RejectedOrderRow extends React.Component {
	shouldComponentUpdate(nextProps) {
		const { order } = this.props; 
		return !is(order, nextProps.order);
	}
	render() {
		const { order } = this.props;
		const symbol = order.get("symbol");
		const symbolDescription = symbolDescriptions(symbol);
		const stockPrice = formatMoney(order.get("price"));
		const stockQty = formatNumber(order.get("qty"));
		const side = order.get("side");
		const bid = formatMoney(order.get("bid"));
		const offer = formatMoney(order.get("offer"));
		return(
			<tr>
				<td>{order.get("order_id")}</td>
				<td>{order.get("UCID")}</td>
				<td>{formatTime(order.get("timestamp"))}</td>
				<td>{order.get("client_id")}</td>
				<td>{symbol}</td>
				<td>{symbolDescription}</td>
				<td>{stockPrice}</td>
				<td>{stockQty}</td>
				<td>{side}</td>
				<td>{bid}</td>
				<td>{offer}</td>
			</tr>
		)
	}
}