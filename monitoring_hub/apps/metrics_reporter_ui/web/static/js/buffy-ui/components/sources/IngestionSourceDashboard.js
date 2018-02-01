import React from "react"
import IngestionSourceTable from "./IngestionSourceTable"
import SourceTable from "./SourceTable"
import SourcesTable from "./SourcesTable"
import SourceListPanel from "./SourceListPanel"
import DashboardHeader from "./DashboardHeader"
import MonitoringGraphsContainer from "./MonitoringGraphsContainer"
import LatencyPercentileBinDataRow from "./LatencyPercentileBinDataRow"
import {minutes} from "../../../util/Duration"
import {Panel, Row, ListGroupItem} from "react-bootstrap"
import {Link} from "react-router"
import {List} from "immutable"

export default class IngestionSourceDashboard extends React.Component {
	render() {
		const {appName, appConfig, sourceType, sourceName, throughputs, throughputStats, ingestionThroughputStats, latencyPercentageBins, latencyPercentileBinStats} = this.props;
		var sourcesList;
		var sourcesListType;
		var compsList;
		var pipelineName;
		var workerName;
		switch(sourceType) {
			case "node-ingress-egress":
				sourcesListType = "node-ingress-egress-by-pipeline"
				sourcesList = appConfig.getIn(["metrics", sourcesListType, sourceName], List());
				compsList = appConfig.getIn(["metrics", "computation-by-worker", sourceName], List());
				break;
			case "computation":
				sourcesListType = "computation-by-worker"
				sourcesList = appConfig.getIn(["metrics", sourcesListType, sourceName], List());
				break;
			case "start-to-end":
				sourcesListType = "start-to-end-by-worker"
				sourcesList = appConfig.getIn(["metrics", sourcesListType, sourceName], List());
				compsList = appConfig.getIn(["metrics", "pipeline-computations", sourceName], List());
				break;
			case "node-ingress-egress-by-pipeline":
				let updatedSourceName = sourceName.replace("*", "@");
				[pipelineName, workerName] = updatedSourceName.split("@");
				sourcesListType = "computation-by-worker"
				sourcesList = appConfig.getIn(["metrics", "pipeline-computations", updatedSourceName], List());
				break;
			case "start-to-end-by-worker":
				[pipelineName, workerName] = sourceName.split("@");
				sourcesListType = "computation-by-worker"
				sourcesList = appConfig.getIn(["metrics", "pipeline-computations", sourceName], List());
				break;
			default:
				sourcesList = List();
				break;
		}
		if (sourcesList.isEmpty()) {
			return(
				<div>
					<Row>
						<Panel>
							<DashboardHeader sourceType={sourceType} sourceName={sourceName} appName={appName} />
							<IngestionSourceTable
								appName={appName}
								sourceName={sourceName}
								sourceType={sourceType}
								throughputStats={throughputStats}
								ingestionThroughputStats={ingestionThroughputStats}
								latencyPercentileBinStats={latencyPercentileBinStats} />
						</Panel>
					</Row>
					<MonitoringGraphsContainer
						throughputs={throughputs}
						chartInterval={minutes(5)}
						latencyPercentageBins={latencyPercentageBins} />
				</div>
			);
		} else {
			switch(sourceType) {
				case "node-ingress-egress":
					return(
						<div>
							<Row>
								<Panel>
									<DashboardHeader sourceType={sourceType} sourceName={sourceName} appName={appName} />
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
							<SourceListPanel
								sourceName={sourceName}
								sourceType={sourcesListType}
								sourcesList={sourcesList}
								appName={appName} />
							<SourceListPanel
								sourceName={sourceName}
								sourceType="computations-on-worker"
								sourcesList={compsList}
								appName={appName} />
						</div>
					);
				case "start-to-end":
					return(
						<div>
							<Row>
								<Panel>
									<DashboardHeader sourceType={sourceType} sourceName={sourceName} appName={appName} />
									<IngestionSourceTable
										appName={appName}
										sourceName={sourceName}
										sourceType={sourceType}
										throughputStats={throughputStats}
										ingestionThroughputStats={ingestionThroughputStats}
										latencyPercentileBinStats={latencyPercentileBinStats} />
								</Panel>
							</Row>
							<MonitoringGraphsContainer
								throughputs={throughputs}
								chartInterval={minutes(5)}
								latencyPercentageBins={latencyPercentageBins} />
							<SourceListPanel
								sourceName={sourceName}
								sourceType={sourcesListType}
								sourcesList={sourcesList}
								appName={appName} />
							<SourceListPanel
								sourceName={sourceName}
								sourceType="computations-for-pipeline"
								sourcesList={compsList}
								appName={appName} />
						</div>
					);
				case "start-to-end-by-worker":
					return(
						<div>
							<Row>
								<Panel>
									<DashboardHeader sourceType={sourceType} sourceName={sourceName} appName={appName} />
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
							<SourceListPanel
								sourceName={sourceName}
								sourceType="computations-for-pipeline-on-worker"
								sourcesList={sourcesList}
								appName={appName} />
						</div>
					);
				case "node-ingress-egress-by-pipeline":
					return(
						<div>
							<Row>
								<Panel>
									<DashboardHeader sourceType={sourceType} sourceName={sourceName} appName={appName} />
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
							<SourceListPanel
								sourceName={sourceName}
								sourceType="computations-for-pipeline-on-worker"
								sourcesList={sourcesList}
								appName={appName} />
						</div>
					);
				default:
					return(
						<div>
							<Row>
								<Panel>
									<DashboardHeader sourceType={sourceType} sourceName={sourceName} appName={appName} />
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
							<SourceListPanel
								sourceName={sourceName}
								sourceType={sourcesListType}
								sourcesList={sourcesList}
								appName={appName} />
						</div>
					);
					break;
			}
		}
	}
}
