import React from "react";
import Auth from "../../util/Auth";


export default class Logout extends React.Component {
	constructor(props) {
		super(props);
		Auth.logout();
	}
	render() {
		return(
			<p>You are now logged out</p>
		)
	}
}