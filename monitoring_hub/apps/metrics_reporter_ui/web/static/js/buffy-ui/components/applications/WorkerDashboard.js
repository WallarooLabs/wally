import React from "react"
import SourcesTable from "../sources/SourcesTable"
import AppConfigStore from "../../stores/AppConfigStore"
import AppStreamConnections from "../../streaming/AppStreamConnections"
import PhoenixConnector from "../../streaming/PhoenixConnector"
import {Panel} from "react-bootstrap"
import { titleize } from "../../../util/Format"

export default class WorkerDashboard extends React.Component {
	render() {
		const { appName, workerName, sourceSinkKeys, ingressEgressKeys, stepKeys } = this.props;
		return(
			<div>
				<h1>{titleize(appName) + ":" + titleize(workerName)}</h1>
				<Panel header={<h2>Worker Stats</h2>} >
					<SourcesTable
						appName={appName}
						linked={true}
						sourceType="node-ingress-egress"
						sourceKeys={ingressEgressKeys} />
				</Panel>
				<Panel header={<h2>Pipeline On Worker Stats</h2>} >
					<SourcesTable
						appName={appName}
						linked={true}
						sourceType="node-ingress-egress-by-pipeline"
						sourceKeys={sourceSinkKeys} />
				</Panel>
				<Panel header={<h2>Computation Stats</h2>} >
					<SourcesTable
						appName={appName}
						linked={true}
						sourceType="computation-by-worker"
						sourceKeys={stepKeys} />
				</Panel>
			</div>
		)
	}
}
