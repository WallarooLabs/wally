import React from "react"
import IngestionSourcePageRow from "./IngestionSourcePageRow"
import ThroughputStatsStore from "../../stores/ThroughputStatsStore"
import LatencyPercentileBinStatsStore from "../../stores/LatencyPercentileBinStatsStore"

export default class IngestionSourcePageTableBody extends React.Component {
	render() {
		const { appName, linked, sourceName, sourceType, throughputStats, ingestionThroughputStats, latencyPercentileBinStats } = this.props;
		return(
			<tbody className="sources">
				<IngestionSourcePageRow
					linked={linked}
					appName={appName}
					sourceName={sourceName}
					sourceType={sourceType}
					latencyPercentileBinStats={latencyPercentileBinStats}
					throughputStats={throughputStats}
					ingestionThroughputStats={ingestionThroughputStats} />
			</tbody>
		)
	}
}
