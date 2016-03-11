import React from "react"
import Auth from "../../util/Auth";
import {LinkContainer} from "react-router-bootstrap";
import {Input, Button} from "react-bootstrap";

export default class Login extends React.Component {
	constructor(props) {
		super(props);
		this.state = {
			error: false
		}
	}
	handleSubmit(event) {
		event.preventDefault();
		const email = this.refs.email.refs.input.value;
		const password = this.refs.password.refs.input.value;
		Auth.login(email, password, (loggedIn) => {
		  if (!loggedIn) {
		    return this.setState({ error: true })
		  }

		  const { location, history } = this.props;
		  if (location.state && location.state.nextPathname) {
		    history.replaceState(null, location.state.nextPathname)
		  } else {
		    history.replaceState(null, '/system')
		  }
		})
	}
	render() {
		return(
			<form>
				<Input ref="email" type="email" placeholder="email" defaultValue="user@sendence.com" />
				<Input ref="password" type="password" placeholder="Password" label="Password" />
					<LinkContainer to="/" onClick={this.handleSubmit.bind(this)} >
						<Button type="submit" bsStyle="primary" block >Login</Button>
					</LinkContainer>
					{this.state.error && (
						<p>Bad login information</p>
					)}
			</form>
		)
	}
}