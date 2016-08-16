import React from "react"
import SourceThroughputStatsCol from "./SourceThroughputStatsCol"
import SourceLatencyStatsCol from "./SourceLatencyStatsCol"
import { Link } from "react-router"
import { titleize } from "../../../util/Format"

export default class SourceRow extends React.Component {
	render() {
		const { appName, linked, sourceName, sourceType, latencyPercentileBinStats, throughputStats } = this.props;
		let sourceNameElement;	
		if (linked) {
			const linkPath = "/applications/" + appName + "/" + sourceType + "/" + sourceName;
			sourceNameElement = <Link to={linkPath}>
				{titleize(sourceName)}
			</Link>;
		} else {
			sourceNameElement = titleize(sourceName);
		}
		return(
			<tr className="text-info">
				<td className="text-primary">{sourceNameElement}</td>
				<td><SourceLatencyStatsCol latencyPercentileBinStats={latencyPercentileBinStats} /></td>
				<td><SourceThroughputStatsCol throughputStats={throughputStats} /></td>
			</tr>
		)
	}
}
