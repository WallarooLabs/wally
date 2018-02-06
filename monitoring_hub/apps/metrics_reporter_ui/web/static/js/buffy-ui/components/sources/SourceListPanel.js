import React from "react"
import { Link } from "react-router"
import {ListGroupItem, Panel} from "react-bootstrap"
import {is, fromJS} from "immutable"
import { titleize } from "../../../util/Format"
import SourcesTable from "./SourcesTable"
import AppStreamConnections from "../../streaming/AppStreamConnections"
import PhoenixConnector from "../../streaming/PhoenixConnector"


export default class SourceListPanel extends React.Component {
	constructor(props) {
		super(props);
		this.updateSourceTypeAndConnectoToMetricsChannels(props)
	}
	updateSourceTypeAndConnectoToMetricsChannels(props) {
		const {sourceType, sourcesList} = props;
		switch(sourceType) {
			case "computations-on-worker":
				this.connectMetricChannels("computation-by-worker", sourcesList);
				break;
			case "computations-for-pipeline-on-worker":
				this.connectMetricChannels("computation-by-worker", sourcesList);
				break;
			case "computations-for-pipeline":
				this.connectMetricChannels("computation", sourcesList);
				break;
			default:
				this.connectMetricChannels(sourceType, sourcesList);
				break;
		}
	}
	componentWillReceiveProps(nextProps) {
		if (!is(fromJS(this.props.sourcesList), fromJS(nextProps.sourcesList))) {
			this.updateSourceTypeAndConnectoToMetricsChannels(nextProps)
		}
	}
	connectMetricChannels(sourceType, sourcesList) {
		sourcesList.forEach(sourceName => {
			AppStreamConnections.connectSourceMetricsChannel(PhoenixConnector, sourceType, sourceName);
		});
	}
	render() {
		const {sourceType, sourcesList, appName, sourceName} = this.props;
		let panelHeader;
		switch(sourceType) {
			case "node-ingress-egress-by-pipeline":
				panelHeader = "Pipelines on " + titleize(sourceName);
				break;
			case "start-to-end-by-worker":
				panelHeader = sourceName + " by Worker";
				break;
			case "computation-by-worker":
				panelHeader = sourceName + " on Worker";
				break;
			case "computations-on-worker":
				panelHeader = "Computations on " + titleize(sourceName);
				break;
			case "computation":
				panelHeader = "Computations for " + titleize(sourceName);
				break;
			case "computations-for-pipeline-on-worker":
				let [pipelineName, symbol, workerName] = sourceName.split(/(\*|@)/);
				panelHeader = "Computations for " + titleize(pipelineName) + " on " + titleize(workerName);
				break;
			case "computations-for-pipeline":
				panelHeader = "Computations for " + titleize(sourceName);
				break;
			default:
				panelHeader = sourceType;
				break;
		}
		return(
			<Panel header={panelHeader}>
				<SourcesTable
						appName={appName}
						linked={true}
						sourceType={sourceType}
						 sourceKeys={sourcesList} />
			</Panel>
		);
	}
}
