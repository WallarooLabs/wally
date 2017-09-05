import React from "react"
import IngestionSourceThroughputStatsCol from "./IngestionSourceThroughputStatsCol"
import SourcePageLatencyStatsCol from "./SourcePageLatencyStatsCol"
import { Link } from "react-router"
import { formatThroughput } from "../../../util/Format"
import { titleize } from "../../../util/Format"

export default class IngestionSourcePageRow extends React.Component {
	render() {
		const { appName, linked, sourceName, sourceType, latencyPercentileBinStats, throughputStats, ingestionThroughputStats } = this.props;
		const formattedThroughputStats = throughputStats
			.update("min", (throughput) => formatThroughput(throughput))
			.update("med", (throughput) => formatThroughput(throughput))
			.update("max", (throughput) => formatThroughput(throughput));
			const formattedIngestionThroughputStats = ingestionThroughputStats
			.update("min", (throughput) => formatThroughput(throughput))
			.update("med", (throughput) => formatThroughput(throughput))
			.update("max", (throughput) => formatThroughput(throughput));
		return(
			<tr className="text-info">
				<td><SourcePageLatencyStatsCol latencyPercentileBinStats={latencyPercentileBinStats} /></td>
				<td>
					<IngestionSourceThroughputStatsCol
						throughputStats={formattedThroughputStats}
						ingestionThroughputStats={formattedIngestionThroughputStats} />
					</td>
			</tr>
		)
	}
}
