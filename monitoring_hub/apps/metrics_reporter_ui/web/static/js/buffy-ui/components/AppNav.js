import React from "react"
import { Nav, NavDropdown, NavItem, MenuItem } from "react-bootstrap"
import { LinkContainer } from "react-router-bootstrap"
import { toJS, is } from "immutable"
import { titleize } from "../../util/Format"

export default class AppNav extends React.Component {
	generateSourceLinks(appPath, sourceType, sourceKeys) {
		return sourceKeys.map((sourceKey) => {
			const sourceName = sourceKey.replace(sourceType + ":", "");
			return(
				<LinkContainer to={appPath + "/" + sourceType + "/" + sourceName} key={sourceKey}>
					<MenuItem>{titleize(sourceName)}</MenuItem>
				</LinkContainer>
			);
		});
	}
	shouldComponentUpdate(nextProps) {
		return !is(this.props.appConfig, nextProps.appConfig);
	}
	render() {
		const { appConfig } = this.props;
		const appName = appConfig.get("app_name");
		const appPath = "/applications/" + appName;
		const stepKeys = appConfig.getIn(["metrics", "step"]);
		const sourceSinkKeys = appConfig.getIn(["metrics", "source-sink"]);
		const ingressEgressKeys = appConfig.getIn(["metrics", "ingress-egress"]);
		const stepLinks = this.generateSourceLinks(appPath, "step", stepKeys);
		const sourceSinkLinks = this.generateSourceLinks(appPath, "source-sink", sourceSinkKeys);
		const ingressEgressLinks = this.generateSourceLinks(appPath, "ingress-egress", ingressEgressKeys);
		return(
			<NavDropdown title={"App: "+ titleize(appName)}>
				<LinkContainer to={appPath  + "/dashboard"}>
					<MenuItem>Dashboard</MenuItem>
				</LinkContainer>
				<MenuItem divider />
				<MenuItem header>Overall (Source -> Sink)</MenuItem>
				<MenuItem divider />
				{sourceSinkLinks}
				<MenuItem divider />
				<MenuItem header>Boundary (Ingress -> Egress)</MenuItem>
				<MenuItem divider />
				{ingressEgressLinks}
				<MenuItem divider />
				<MenuItem header>Step</MenuItem>
				<MenuItem divider />
				{stepLinks}
				<MenuItem divider />
			</NavDropdown>
		)
	}
}