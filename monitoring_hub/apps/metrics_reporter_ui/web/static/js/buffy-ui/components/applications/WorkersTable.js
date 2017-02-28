import React from "react"
import { Table } from "react-bootstrap"
import WorkersTableRow from "./WorkersTableRow"

export default class WorkersTable extends React.Component {
	render() {
		const { workers, appName } = this.props;
		const rows =  workers.map(function(worker) {
			return <WorkersTableRow workerName={worker} key={worker} />;
		});
		return (
			<Table className="applications">
				<thead>
					<tr>
						<th><h1>{appName}: Workers</h1></th>
					</tr>
				</thead>
				<tbody className="applications">
					{rows}
				</tbody>
			</Table>
		)
	}
}
