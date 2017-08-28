import React from "react"
import SourcePageStatsTableHeader from "./SourcePageStatsTableHeader"

export default class SourcePageTableHeader extends React.Component {
	shouldComponentUpdate(nextProps, nextState) {
		return false;
	}
	render() {
		return(
			<thead>
				<tr>
					<th>Latency Percent Stats: Last 5 mins</th>
					<th>Throughput Stats: Last 5 mins (msgs/sec)</th>
				</tr>
				<SourcePageStatsTableHeader />
			</thead>
		)
	}
}
