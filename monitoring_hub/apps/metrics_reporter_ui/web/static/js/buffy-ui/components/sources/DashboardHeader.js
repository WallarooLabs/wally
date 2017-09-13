import React from "react"
import shallowCompare from "react-addons-shallow-compare"
import { titleize } from "../../../util/Format"
import {Link} from "react-router"

export default class DashboardHeader extends React.Component {
	shouldComponentUpdate(nextProps, nextState) {
		return shallowCompare(this, nextProps, nextState);
	}
	render() {
		const {sourceType, sourceName, appName} = this.props;
		let sourceHeader;
		let sourceNameElement;
		let workerLinkPath;
		let pipelineLinkPath;
		let compLinkPath;
		switch(sourceType) {
			case "computation":
				sourceHeader = "Computation";
				sourceNameElement = titleize(sourceName);
				break;
			case "node-ingress-egress":
				sourceHeader = "Node";
				sourceNameElement = titleize(sourceName);
				break;
			case "start-to-end":
				sourceHeader = "Pipeline";
				sourceNameElement = titleize(sourceName);
				break;
			case "computation-by-worker":
				sourceHeader = "Computation by Worker";
				let compNamesArray = sourceName.split(":", 3);
				let compName, workerName, pipelineName;
				if (compNamesArray.length == 3) {
					compName = compNamesArray[1] + ":" + compNamesArray[2];
				} else {
					compName = compNamesArray[1];
				}
				[pipelineName, workerName] = compNamesArray[0].split("@");
				compLinkPath = "/applications/" + appName + "/computation/" + compName;
				workerLinkPath = "/applications/" + appName + "/" + "node-ingress-egress/" + workerName;
				sourceNameElement = <span>
					<Link to={compLinkPath}>
						{titleize(compName)}
					</Link>
					<span> on </span>
					<Link to={workerLinkPath}>
						{titleize(workerName)}
					</Link>
				</span>
				break;
			case "node-ingress-egress-by-pipeline":
				let workerNamesArray = sourceName.split("*");
				pipelineLinkPath = "/applications/" + appName + "/start-to-end/" + workerNamesArray[0];
				workerLinkPath = "/applications/" + appName + "/" + "node-ingress-egress/" + workerNamesArray[1];
				sourceNameElement = <span>
					<Link to={pipelineLinkPath}>
						{titleize(workerNamesArray[0])}
					</Link>
					<span> on </span>
					<Link to={workerLinkPath}>
						{titleize(workerNamesArray[1])}
					</Link>
				</span>
				sourceHeader = "Worker by Pipeline";
				break;
			case "start-to-end-by-worker":
				let pipelineNamesArray = sourceName.split("@");
				pipelineLinkPath = "/applications/" + appName + "/start-to-end/" + pipelineNamesArray[0];
				workerLinkPath = "/applications/" + appName + "/" + "node-ingress-egress/" + pipelineNamesArray[1];
				sourceNameElement = <span>
					<Link to={pipelineLinkPath}>
						{titleize(pipelineNamesArray[0])}
					</Link>
					<span> on </span>
					<Link to={workerLinkPath}>
						{titleize(pipelineNamesArray[1])}
					</Link>
				</span>
				sourceHeader = "Pipeline by Worker";
				break;
		}
		return(
			<div>
				<h1>{sourceHeader + ": "}</h1>
				<div className="text-info">
					<h1>{sourceNameElement}</h1>
				</div>
			</div>
		)
	}
}
