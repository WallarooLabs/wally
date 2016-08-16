import React from "react"
import SourceTable from "./SourceTable"
import DashboardHeader from "./DashboardHeader"
import MonitoringGraphsContainer from "./MonitoringGraphsContainer"
import LatencyPercentileBinDataRow from "./LatencyPercentileBinDataRow"
import {minutes} from "../../../util/Duration"
import {Panel, Row} from "react-bootstrap"

export default class SourceDashboard extends React.Component {
	render() {
		const {appName, sourceType, sourceName, throughputs, throughputStats, latencyPercentageBins, latencyPercentileBinStats} = this.props;
		return(
			<div>
				<Row>
					<Panel>
						<DashboardHeader sourceType={sourceType} sourceName={sourceName} />
						<SourceTable
							appName={appName}
							sourceName={sourceName}
							sourceType={sourceType}
							throughputStats={throughputStats}
							latencyPercentileBinStats={latencyPercentileBinStats} />
					</Panel>
				</Row>
				<MonitoringGraphsContainer
					throughputs={throughputs}
					chartInterval={minutes(5)}
					latencyPercentageBins={latencyPercentageBins} />
				<LatencyPercentileBinDataRow latencyPercentileBinStats={latencyPercentileBinStats} />
			</div>
		);
	}
}