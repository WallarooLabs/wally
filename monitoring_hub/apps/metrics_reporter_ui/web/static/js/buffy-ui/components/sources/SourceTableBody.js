import React from "react"
import SourceRow from "./SourceRow"
import ThroughputStatsStore from "../../stores/ThroughputStatsStore"
import LatencyPercentileBinStatsStore from "../../stores/LatencyPercentileBinStatsStore"

export default class SourceTableBody extends React.Component {
	render() {
		const { appName, linked, sourceName, sourceType, throughputStats, latencyPercentileBinStats } = this.props;
		return(
			<tbody className="sources">
				<SourceRow
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