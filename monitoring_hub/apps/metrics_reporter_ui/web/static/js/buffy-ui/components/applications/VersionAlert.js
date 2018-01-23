import React from "react"
import { Alert, Button } from "react-bootstrap"

export default class VersionAlert extends React.Component {
	constructor(props) {
		super(props);
		const version = process.env.WALLAROO_VERSION || "dev"
		this.state = {
			version: version,
			alertVisible: true,
		};
	}
	handleAlertDismiss() {
	  this.setState({ alertVisible: false });
	}

	render() {
		const {version} = this.state;
		if (this.state.alertVisible) {
		     return (
		        <Alert bsStyle="info">
		          <p>You're on version <strong>{version}</strong>, click <a href={"https://www.wallaroolabs.com/ui/latest?version=" + version } target="_blank" >here</a> to verify you're up to date!</p>
		        </Alert>
		     );
		}
		return(<div></div>);
	}

}
