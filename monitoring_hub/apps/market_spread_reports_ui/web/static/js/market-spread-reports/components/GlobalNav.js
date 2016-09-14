import React from "react"
import { Nav, Navbar, NavBrand, NavDropdown, NavItem, MenuItem } from "react-bootstrap"
import { IndexLinkContainer, LinkContainer } from "react-router-bootstrap"
import CurrentTime from "../../components/CurrentTime"

export default class GlobalNav extends React.Component {
	render() {
		return(
			<Navbar>
        <Nav>
          <IndexLinkContainer to="/">
            <NavItem>Buffy: Market Spread Reports</NavItem>
          </IndexLinkContainer>
        </Nav>
        <Nav>
          <LinkContainer to="/reports/rejected-orders-report">
            <NavItem>Rejected Orders Report</NavItem>
          </LinkContainer>
        </Nav>
        <Nav right>
          <CurrentTime />
        </Nav>
      </Navbar>
		)
	}
}