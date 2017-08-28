import React from "react"
import SourceThroughputStatsCol from "./SourceThroughputStatsCol"
import SourcePageLatencyStatsCol from "./SourcePageLatencyStatsCol"
import { Link } from "react-router"
import { formatThroughput } from "../../../util/Format"
import { titleize } from "../../../util/Format"

export default class SourcePageRow extends React.Component {
	render() {
		const { appName, linked, sourceName, sourceType, latencyPercentileBinStats, throughputStats } = this.props;
		const formattedThroughputStats = throughputStats
			.update("min", (throughput) => formatThroughput(throughput))
			.update("med", (throughput) => formatThroughput(throughput))
			.update("max", (throughput) => formatThroughput(throughput));
		return(
			<tr className="text-info">
				<td><SourcePageLatencyStatsCol latencyPercentileBinStats={latencyPercentileBinStats} /></td>
				<td><SourceThroughputStatsCol throughputStats={formattedThroughputStats} /></td>
			</tr>
		)
	}
}
