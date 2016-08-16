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
				<Panel header={<h2>Overall (Source -> Sink) Stats</h2>} >
					<SourcesTable
						appName={appName}
						linked={true}
						sourceType="source-sink" 
						sourceKeys={sourceSinkKeys} />
				</Panel>
				<Panel header={<h2>Node Stats</h2>} >
					<SourcesTable
						appName={appName}
						linked={true}
						sourceType="ingress-egress" 
						sourceKeys={ingressEgressKeys} />
				</Panel>
				<Panel header={<h2>Step Stats</h2>} >
					<SourcesTable
						appName={appName}
						linked={true}
						sourceType="step"
						sourceKeys={stepKeys} />
				</Panel>
			</div>
		)
	}
}