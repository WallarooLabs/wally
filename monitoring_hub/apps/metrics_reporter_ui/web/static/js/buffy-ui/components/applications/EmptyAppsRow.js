import React from "react"
import { Link } from "react-router"
import ApplicationTitle from "./ApplicationTitle"

export default class EmptyAppsRow extends React.Component {
	render() {
		const noApps = "No applications connected"
		return (
			<tr>
				<td>
					<ApplicationTitle appName={noApps}/>
				</td>
			</tr>
		)
	}
}
