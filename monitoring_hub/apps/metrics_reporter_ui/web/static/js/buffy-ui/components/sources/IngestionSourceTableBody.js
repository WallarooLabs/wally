import React from "react"
import IngestionSourceRow from "./IngestionSourceRow"
import ThroughputStatsStore from "../../stores/ThroughputStatsStore"
import LatencyPercentileBinStatsStore from "../../stores/LatencyPercentileBinStatsStore"

export default class IngestionSourceTableBody extends React.Component {
	render() {
		const { appName, linked, sourceName, sourceType, throughputStats, latencyPercentileBinStats, ingestionThroughputStats } = this.props;
		return(
			<tbody className="sources">
				<IngestionSourceRow
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
