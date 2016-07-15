import React from "react"
import { titleize } from "../../../util/Format"

export default class ApplicationTitle extends React.Component {
	render() {
		const { appName } = this.props;
		return (
			<h1>{titleize(appName)}</h1>
		)
	}
}