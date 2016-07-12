import React from "react"
import { Link } from "react-router"
import ApplicationTitle from "./ApplicationTitle"

export default class ApplicationTableRow extends React.Component {
	render() {
		const { appName } = this.props;
		return (
			<tr>
				<td><Link to={"/applications/" + appName + "/dashboard"}>
						<ApplicationTitle appName={appName}/>
					</Link>
				</td>
			</tr>
		)
	}
}