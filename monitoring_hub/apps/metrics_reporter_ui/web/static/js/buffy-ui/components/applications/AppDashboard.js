import React from "react"
import SourcesTable from "../sources/SourcesTable"
import AppConfigStore from "../../stores/AppConfigStore"
import AppStreamConnections from "../../streaming/AppStreamConnections"
import PhoenixConnector from "../../streaming/PhoenixConnector"
import {Panel} from "react-bootstrap"
import { titleize } from "../../../util/Format"

export default class AppDashboard extends React.Component {
	render() {
		const { appName, sourceSinkKeys, ingressEgressKeys, stepKeys } = this.props;
		return(
			<div>
				<h1>{titleize(appName)}</h1>
				<Panel header={<h2>Overall (Start -> End) Stats</h2>} >
					<SourcesTable
						appName={appName}
						linked={true}
						sourceType="start-to-end" 
						sourceKeys={sourceSinkKeys} />
				</Panel>
				<Panel header={<h2>Node Stats</h2>} >
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