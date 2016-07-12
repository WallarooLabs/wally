import React from "react"
import RejectedClientOrderSummariesReport from "./RejectedClientOrderSummariesReport"
import ClientOrderSummariesStore from "../../stores/ClientOrderSummariesStore"


export default class RejectedClientOrderSummariesReportContainer extends React.Component {
	constructor(props) {
		super(props);
		const clientOrderSummaries = ClientOrderSummariesStore.getClientOrderSummaries();
		const listener = ClientOrderSummariesStore.addListener(function() {
			if (!this.isUnmounted) {
				const clientOrderSummaries = ClientOrderSummariesStore.getClientOrderSummaries();
				this.setState({
					clientOrderSummaries: clientOrderSummaries
				});
			}
		}.bind(this));
		this.state = {
			clientOrderSummaries: clientOrderSummaries,
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
		let { clientOrderSummaries } = this.state;
		return(
			<RejectedClientOrderSummariesReport clientOrderSummaries={clientOrderSummaries} />
		);
	}

}