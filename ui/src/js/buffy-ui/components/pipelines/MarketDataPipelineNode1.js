import React from "react"
import AppConfig from "../../config/AppConfig"
import MetricsPanel from "./MetricsPanel"

export default class MarketDataPipelineNode1 extends React.Component {
    render() {
        const systemKey = AppConfig.getSystemKey("MARKET_SPREAD_CHECK");
        const pipelineKey = AppConfig.getPipelineKey("MARKET_SPREAD_CHECK", "NODE_1");
        const pipelineName = AppConfig.getPipelineName("MARKET_SPREAD_CHECK", "NODE_1");
        return (
            <div>
                <h3>Node 1</h3>
                <MetricsPanel systemKey={systemKey} pipelineKey={pipelineKey} pipelineName={pipelineName}  />
            </div>
        )
    }
}