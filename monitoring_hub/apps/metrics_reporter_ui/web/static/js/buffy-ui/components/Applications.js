import React from "react"
import ApplicationsTable from "./applications/ApplicationsTable"
import AppConfigStore from "../stores/AppConfigStore"
import GlobalNav from "./GlobalNav"

export default class Applications extends React.Component {
	render() {
		const { appConfigs } = this.props;
		return(
			<div>
				{this.props.children ||
						<ApplicationsTable appConfigs={appConfigs} />
				}
			</div>
		)
	}
}
