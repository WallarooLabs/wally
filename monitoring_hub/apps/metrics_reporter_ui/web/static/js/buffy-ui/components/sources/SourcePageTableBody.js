import React from "react"
import SourcePageRow from "./SourcePageRow"
import ThroughputStatsStore from "../../stores/ThroughputStatsStore"
import LatencyPercentileBinStatsStore from "../../stores/LatencyPercentileBinStatsStore"

export default class SourcePageTableBody extends React.Component {
	render() {
		const { appName, linked, sourceName, sourceType, throughputStats, latencyPercentileBinStats } = this.props;
		return(
			<tbody className="sources">
				<SourcePageRow
					linked={linked}
					appName={appName}
					sourceName={sourceName}
					sourceType={sourceType}
					latencyPercentileBinStats={latencyPercentileBinStats}
					throughputStats={throughputStats} />
			</tbody>
		)
	}
}
