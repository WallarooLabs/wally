import React from "react"
import { Table } from "react-bootstrap"
import SourceTableHeader from "./SourceTableHeader"
import SourceTableBody from "./SourceTableBody"
import ThroughputStatsStore from "../../stores/ThroughputStatsStore"
import LatencyPercentileBinStatsStore from "../../stores/LatencyPercentileBinStatsStore"
import {is} from "immutable"

export default class SourceTable extends React.Component {
	shouldComponentUpdate(nextProps) {
		return (!is(this.props.throughputStats, nextProps.throughputStats) || !is(this.props.latencyPercentileBinStats, nextProps.latencyPercentileBinStats));
	}
	render() {
		const { appName, sourceName, sourceType, throughputStats, latencyPercentileBinStats } = this.props;
		return(
			<Table>
				<SourceTableHeader />
				<SourceTableBody
					linked={false}
					appName={appName}
					sourceType={sourceType}
					sourceName={sourceName}
					throughputStats={throughputStats}
					latencyPercentileBinStats={latencyPercentileBinStats} />
			</Table>
		)
	}
}