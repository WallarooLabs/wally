import React from "react"
import { Table } from "react-bootstrap"
import SourcePageTableHeader from "./SourcePageTableHeader"
import IngestionSourcePageTableBody from "./IngestionSourcePageTableBody"
import ThroughputStatsStore from "../../stores/ThroughputStatsStore"
import LatencyPercentileBinStatsStore from "../../stores/LatencyPercentileBinStatsStore"
import {is} from "immutable"

export default class IngestionSourceTable extends React.Component {
	shouldComponentUpdate(nextProps) {
		return (!is(this.props.throughputStats, nextProps.throughputStats) ||
			!is(this.props.ingestionThroughputStats, nextProps.ingestionThroughputStats) ||
			!is(this.props.latencyPercentileBinStats, nextProps.latencyPercentileBinStats));
	}
	render() {
		const { appName, sourceName, sourceType, throughputStats, ingestionThroughputStats, latencyPercentileBinStats } = this.props;
		return(
			<Table>
				<SourcePageTableHeader />
				<IngestionSourcePageTableBody
					linked={false}
					appName={appName}
					sourceType={sourceType}
					sourceName={sourceName}
					throughputStats={throughputStats}
					ingestionThroughputStats={ingestionThroughputStats}
					latencyPercentileBinStats={latencyPercentileBinStats} />
			</Table>
		)
	}
}
