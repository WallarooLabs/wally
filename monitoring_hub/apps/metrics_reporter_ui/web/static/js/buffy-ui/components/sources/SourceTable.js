import React from "react"
import { Table } from "react-bootstrap"
import SourcePageTableHeader from "./SourcePageTableHeader"
import SourcePageTableBody from "./SourcePageTableBody"
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
				<SourcePageTableHeader />
				<SourcePageTableBody
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
