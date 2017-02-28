import React from "react"
import {Panel} from "react-bootstrap"
import { titleize } from "../../../util/Format"
import WorkersTable from "./WorkersTable"

export default class WorkersDashboard extends React.Component {
	render() {
		const { appName, workers } = this.props;
		return(
			<div>
				<WorkersTable appName={appName}
					workers={workers}	/>
			</div>
		)
	}
}
