import React from "react"
import { render } from "react-dom"
import { Router, Route } from "react-router"
import Dispatcher from "./dispatcher/Dispatcher"
import ChannelDispatchConnector from "./stream-data/ChannelDispatchConnector"
import AppStreamConnections from "./buffy-ui/streaming/AppStreamConnections"
import App from "./buffy-ui/components/App"
import Applications from "./buffy-ui/components/Applications"
import AppDashboardContainer from "./buffy-ui/components/applications/AppDashboardContainer"
import SourceDashboardContainer from "./buffy-ui/components/sources/SourceDashboardContainer"
import IngestionSourceDashboardContainer from "./buffy-ui/components/sources/IngestionSourceDashboardContainer"
import Perf from "react-addons-perf"
import PhoenixConnector from "./buffy-ui/streaming/PhoenixConnector"
import WorkersDashboardContainer from "./buffy-ui/components/applications/WorkersDashboardContainer"
import WorkerDashboardContainer from "./buffy-ui/components/applications/WorkerDashboardContainer"

window.Perf = Perf;

AppStreamConnections.channelHubToDispatcherWith(PhoenixConnector);

render(
	(<Router>
		<Route path="/" component={App}>
			<Route path="applications" component={Applications}>
				<Route path=":appName">
					<Route path="dashboard"component={AppDashboardContainer}/>
					<Route path="workers-dashboard" component={WorkersDashboardContainer}/>
					<Route path="start-to-end/:sourceName" component={IngestionSourceDashboardContainer}/>
					<Route path=":sourceType/:sourceName" component={SourceDashboardContainer}/>
				</Route>
			</Route>
		</Route>
	</Router>),
	document.getElementById("main")
);
