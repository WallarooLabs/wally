import React from "react"
import { Nav, Navbar, NavBrand, NavDropdown, NavItem, MenuItem } from "react-bootstrap"
import AppNav from "./AppNav"
import { IndexLinkContainer } from "react-router-bootstrap"
import CurrentTime from "../../components/CurrentTime" 

export default class GlobalNav extends React.Component {
	render() {
		const { appConfigs } = this.props;
		const appLinks = appConfigs.map((appConfig) => {
			return(
				<AppNav appConfig={appConfig} key={appConfig.get("app_name")} />
			);
		});
		return(
			<Navbar>
				<Nav>
					<IndexLinkContainer to="/">
						<NavItem>Monitoring Hub</NavItem>
					</IndexLinkContainer>
				</Nav>
				<Nav>
					{appLinks}
				</Nav>
				<Nav right>
					<CurrentTime />
				</Nav>
			</Navbar>
		)
	}
}