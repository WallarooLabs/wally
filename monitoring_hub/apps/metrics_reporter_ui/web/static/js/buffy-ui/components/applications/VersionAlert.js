import React from "react"
import { Alert, Button } from "react-bootstrap"

export default class VersionAlert extends React.Component {
	constructor(props) {
		super(props);
		this.state = {
			alertVisible: true,
		};
	}
	handleAlertDismiss() {
	  this.setState({ alertVisible: false });
	}

	render() {
		if (this.state.alertVisible) {
		     return (
		        <Alert bsStyle="info">
		          <p>You're on version <strong>{{ book.wallaroo_version }}</strong>, click <a href="https://www.wallaroolabs.com/ui/latest?version={{ book.wallaroo_version }}" target="_blank">here</a> to verify you're up to date!</p>
		        </Alert>
		     );
		}
		return(<div></div>);
	}

}
