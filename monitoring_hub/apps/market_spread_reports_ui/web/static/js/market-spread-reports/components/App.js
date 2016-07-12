import React from "react"
import GlobalNav from "./GlobalNav"
import Reports from "./Reports"

export default class App extends React.Component {
	render() {
		return(
			<div>
				<GlobalNav />
				<div className="container">
					{this.props.children || <Reports />}
				</div>
			</div>
		)
	}
}