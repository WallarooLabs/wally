import React from "react"
import { render } from "react-dom"
import { Router, Route } from "react-router"
import Dispatcher from "./dispatcher/Dispatcher"
import AppStreamConnections from "./market-spread-reports/streaming/AppStreamConnections"
import App from "./market-spread-reports/components/App"
import Reports from "./market-spread-reports/components/Reports"
import RejectedOrdersReportContainer from "./market-spread-reports/components/reports/RejectedOrdersReportContainer"
import RejectedClientOrderSummariesReportContainer from "./market-spread-reports/components/reports/RejectedClientOrderSummariesReportContainer"
import Perf from "react-addons-perf"
import PhoenixConnector from "./market-spread-reports/streaming/PhoenixConnector"


window.Perf = Perf;

AppStreamConnections.channelHubToDispatcherWith(PhoenixConnector);

render(
	(<Router>
		<Route path="/" component={App}>
			<Route path="reports" component={Reports}>
				<Route path="rejected-orders-report" component={RejectedOrdersReportContainer} />
				// <Route path="rejected-client-order-summaries-report" component={RejectedClientOrderSummariesReportContainer} />
			</Route>
		</Route>
	</Router>),
	document.getElementById("main")
);