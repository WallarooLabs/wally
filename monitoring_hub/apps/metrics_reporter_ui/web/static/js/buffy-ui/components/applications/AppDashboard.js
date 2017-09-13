import React from "react"
import SourcesTable from "../sources/SourcesTable"
import IngestionSourcesTable from "../sources/IngestionSourcesTable"
import AppConfigStore from "../../stores/AppConfigStore"
import AppStreamConnections from "../../streaming/AppStreamConnections"
import PhoenixConnector from "../../streaming/PhoenixConnector"
import {Panel} from "react-bootstrap"
import { titleize } from "../../../util/Format"

export default class AppDashboard extends React.Component {
	render() {
		const { appName, sourceSinkKeys, ingressEgressKeys, stepKeys, pipelineIngestionKeys } = this.props;
		return(
			<div>
				<h1>{titleize(appName)}</h1>
				<Panel header={<h2>Pipeline Stats</h2>} >
					<IngestionSourcesTable
						appName={appName}
						linked={true}
						sourceType="start-to-end"
						sourceKeys={sourceSinkKeys}
						ingestionSourceKeys={pipelineIngestionKeys} />
				</Panel>
				<Panel header={<h2>Worker Stats</h2>} >
					<SourcesTable
						appName={appName}
						linked={true}
						sourceType="node-ingress-egress"
						sourceKeys={ingressEgressKeys} />
				</Panel>
				<Panel header={<h2>Computation Stats</h2>} >
					<SourcesTable
						appName={appName}
						linked={true}
						sourceType="computation"
						sourceKeys={stepKeys} />
				</Panel>
			</div>
		)
	}
}
