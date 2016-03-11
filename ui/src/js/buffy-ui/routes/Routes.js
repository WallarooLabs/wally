import Auth from "../../util/Auth"
import AppConfig from "../config/AppConfig"

function requireAuth(nextState, replaceState) {
    if (!Auth.loggedIn() && nextState.location.pathname != "/login") {
        replaceState({ nextPathname: nextState.location.pathname }, "/login");
    }
}

const rootRoute = {
    component: require("../components/App"),
    path: "/",
    title: "Sendence",
    onEnter: requireAuth,
    childRoutes:[ {
        path: AppConfig.getSystemPath("MARKET_SPREAD_CHECK"),
        component: require("../components/pipelines/MarketDataPipeline"),
        title: AppConfig.getSystemName("MARKET_SPREAD_CHECK"),
        onEnter: requireAuth,
        childRoutes: [ {
            path: "dashboard",
            title: "Dashboard",
            component: require("../components/pipelines/MarketDataPipeline")
        },
        {
            path: "pipelines",
            title: "Pipelines",
            component: require("../components/pipelines/MarketDataPipeline"),
            childRoutes: [
                {
                    path: AppConfig.getPipelinePath("MARKET_SPREAD_CHECK", "NBBO"),
                    title: AppConfig.getPipelineName("MARKET_SPREAD_CHECK", "NBBO"),
                    component: require("../components/pipelines/MarketDataPipeline")
                }
            ]
        }]
        }]

    };


export default {

    getRoot: function() {
        return rootRoute;
    }
}
