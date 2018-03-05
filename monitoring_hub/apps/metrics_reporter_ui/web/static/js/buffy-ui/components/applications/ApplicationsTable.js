import React from "react"
import { Table, Alert } from "react-bootstrap"
import ApplicationsTableRow from "./ApplicationsTableRow"
import EmptyAppsRow from "./EmptyAppsRow"
import VersionAlert from "./VersionAlert"
import { List } from "immutable"

export default class ApplicationsTable extends React.Component {
	render() {
		let rows;
		const { appConfigs } = this.props;
		if (appConfigs.isEmpty()) {
			rows = List([<EmptyAppsRow />])
		} else {
			rows =  appConfigs.map(function(appConfig) {
				const appName = appConfig.get("app_name");
				return <ApplicationsTableRow appName={appName} key={appName} />;
			});
		}
		return (
			<div>
			<VersionAlert />
			<Table className="applications">
				<thead>
					<tr>
						<th><h1>Applications</h1></th>
					</tr>
				</thead>
				<tbody className="applications">
					{rows}
				</tbody>
			</Table>
			</div>
		)
	}
}
