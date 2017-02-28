import React from "react"
import { Link } from "react-router"
import ApplicationTitle from "./ApplicationTitle"

export default class WorkersTableRow extends React.Component {
	render() {
		const { workerName } = this.props;
		return (
			<tr>
				<td>
					<ApplicationTitle appName={workerName}/>
				</td>
			</tr>
		)
	}
}
