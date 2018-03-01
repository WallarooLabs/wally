import React from "react"
import { Nav, NavDropdown, NavItem, MenuItem } from "react-bootstrap"
import { LinkContainer } from "react-router-bootstrap"
import { toJS, is } from "immutable"
import { titleize } from "../../util/Format"

export default class AppNav extends React.Component {
	generateSourceLinks(appPath, sourceType, sourceKeys) {
		return sourceKeys.map((sourceKey) => {
			const sourceName = sourceKey.split("||")[1];
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
		const stepKeys = appConfig.getIn(["metrics", "computation"]);
		const sourceSinkKeys = appConfig.getIn(["metrics", "start-to-end"]);
		const ingressEgressKeys = appConfig.getIn(["metrics", "node-ingress-egress"]);
		const pipelineKeys = appConfig.getIn(["metrics", "pipeline"]);
		const stepLinks = this.generateSourceLinks(appPath, "computation", stepKeys);
		const sourceSinkLinks = this.generateSourceLinks(appPath, "start-to-end", sourceSinkKeys);
		const ingressEgressLinks = this.generateSourceLinks(appPath, "node-ingress-egress", ingressEgressKeys);
		const pipelineLinks = this.generateSourceLinks(appPath, "pipeline", pipelineKeys);
		return(
			<NavDropdown title={"App: "+ titleize(appName)}>
				<LinkContainer to={appPath  + "/dashboard"}>
					<MenuItem>Dashboard</MenuItem>
				</LinkContainer>
				<LinkContainer to={appPath  + "/workers-dashboard"}>
					<MenuItem>Workers Dashboard</MenuItem>
				</LinkContainer>
				<MenuItem divider />
				<MenuItem header>Pipeline</MenuItem>
				<MenuItem divider />
				{sourceSinkLinks}
				<MenuItem divider />
				<MenuItem header>Worker</MenuItem>
				<MenuItem divider />
				{ingressEgressLinks}
				<MenuItem divider />
				<MenuItem header>Computation</MenuItem>
				<MenuItem divider />
				{stepLinks}
				<MenuItem divider />
			</NavDropdown>
		)
	}
}
