import React from "react"
import RejectedOrdersReport from "./RejectedOrdersReport"
import RejectedOrdersStore from "../../stores/RejectedOrdersStore"


export default class RejectedOrdersReportContainer extends React.Component {
	constructor(props) {
		super(props);
		const rejectedOrders = RejectedOrdersStore.getRejectedOrders();
		const listener = RejectedOrdersStore.addListener(function() {
			if (!this.isUnmounted) {
				const rejectedOrders = RejectedOrdersStore.getRejectedOrders();
				this.setState({
					rejectedOrders: rejectedOrders
				});
			}
		}.bind(this));
		this.state = {
			rejectedOrders: rejectedOrders,
			listener: listener
		};
	}
	componentDidMount() {
		this.isUnmounted = false;
	}
	componentWillUnmount() {
		this.isunmounted = true;
		let { listener } = this.state;
		this.removeListener(listener);
	}
	removeListener(listener) {
		listener.remove();
	}
	render() {
		let { rejectedOrders } = this.state;
		return(
			<RejectedOrdersReport rejectedOrders={rejectedOrders} />
		);
	}

}