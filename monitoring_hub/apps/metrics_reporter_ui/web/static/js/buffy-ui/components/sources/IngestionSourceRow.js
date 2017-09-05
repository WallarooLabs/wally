import React from "react"
import IngestionSourceThroughputStatsCol from "./IngestionSourceThroughputStatsCol"
import SourceLatencyStatsCol from "./SourceLatencyStatsCol"
import { Link } from "react-router"
import { formatThroughput } from "../../../util/Format"
import { titleize } from "../../../util/Format"

export default class IngestionSourceRow extends React.Component {
	render() {
		const { appName, linked, sourceName, sourceType, latencyPercentileBinStats, throughputStats, ingestionThroughputStats } = this.props;
		let sourceNameElement;
		let formattedSourceName;
		let sourcesNameArray;
		let updatedSourceType = sourceType;
		switch(sourceType) {
			case "computations-for-pipeline-on-worker":
				updatedSourceType = "computation-by-worker";
				let sourcesNameArray = sourceName.split(":", 3);
				if (sourcesNameArray.length == 3) {
					formattedSourceName = sourcesNameArray[1] + ":" + sourcesNameArray[2];
				} else {
					formattedSourceName = sourcesNameArray[1];
				}
				break;
			case "computations-on-worker":
				updatedSourceType = "computation-by-worker";
				sourcesNameArray = sourceName.split(":", 3);
				if (sourcesNameArray.length == 3) {
					formattedSourceName = sourcesNameArray[1] + ":" + sourcesNameArray[2];
				} else {
					formattedSourceName = sourcesNameArray[1];
				}
				break;
			case "computation-by-worker":
				let [pipelineAndWorkerName] = sourceName.split(":", 3)
				formattedSourceName = pipelineAndWorkerName.split("@")[1];
				break;
			case "start-to-end-by-worker":
				formattedSourceName = sourceName.split("@")[1];
				break;
			case "node-ingress-egress-by-pipeline":
				formattedSourceName = sourceName.split("*")[0];
				break;
			case "computations-for-pipeline":
				updatedSourceType = "computation";
			default:
				formattedSourceName = sourceName;
				break;
		}
		if (linked) {
			const linkPath = "/applications/" + appName + "/" + updatedSourceType + "/" + sourceName;
			sourceNameElement = <Link to={linkPath}>
				{titleize(formattedSourceName)}
			</Link>;
		} else {
			sourceNameElement = titleize(formattedSourceName);
		}
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
				<td className="text-primary">{sourceNameElement}</td>
				<td><SourceLatencyStatsCol latencyPercentileBinStats={latencyPercentileBinStats} /></td>
				<td>
					<IngestionSourceThroughputStatsCol
						throughputStats={formattedThroughputStats}
						ingestionThroughputStats={formattedIngestionThroughputStats} />
				</td>
			</tr>
		)
	}
}
