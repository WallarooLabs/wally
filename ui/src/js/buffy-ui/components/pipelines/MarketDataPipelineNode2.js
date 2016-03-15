import React from "react"
import AppConfig from "../../config/AppConfig"
import MetricsPanel from "./MetricsPanel"

export default class MarketDataPipelineNode2 extends React.Component {
    render() {
        const systemKey = AppConfig.getSystemKey("MARKET_SPREAD_CHECK");
        const pipelineKey = AppConfig.getPipelineKey("MARKET_SPREAD_CHECK", "NODE_2");
        const pipelineName = AppConfig.getPipelineName("MARKET_SPREAD_CHECK", "NODE_2");
        return (
            <div>
                <h3>Node 2</h3>
                <MetricsPanel systemKey={systemKey} pipelineKey={pipelineKey} pipelineName={pipelineName}  />
            </div>
        )
    }
}