import React from "react"
import StatsTableHeader from "./StatsTableHeader"

export default class SourceTableHeader extends React.Component {
	shouldComponentUpdate(nextProps, nextState) {
		return false;
	}
	render() {
		return(
			<thead>
				<tr>
					<th>ID</th>
					<th>Latency Percent Stats: Last 5 mins</th>
					<th>Throughput Stats: Last 5 mins (msgs/sec)</th>
				</tr>
				<StatsTableHeader />
			</thead>
		)
	}
}