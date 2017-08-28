import React from "react"
import { Link } from "react-router"
import ApplicationTitle from "./ApplicationTitle"

export default class WorkersTableRow extends React.Component {
	render() {
		const { workerName, appName } = this.props;
		return (
			<tr>
				<td><Link to={"/applications/" + appName + "/node-ingress-egress/" + workerName}>
					<ApplicationTitle appName={workerName}/>
				</Link>
				</td>
			</tr>
		)
	}
}
