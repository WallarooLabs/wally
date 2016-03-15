import React from "react"
import AppConfig from "../../config/AppConfig"
import MetricsPanel from "./MetricsPanel"

export default class MarketDataPipeline extends React.Component {
    render() {
        const systemKey = AppConfig.getSystemKey("MARKET_SPREAD_CHECK");
        const pipelineKey = AppConfig.getPipelineKey("MARKET_SPREAD_CHECK", "PRICE_SPREAD");
        const pipelineName = AppConfig.getPipelineName("MARKET_SPREAD_CHECK", "PRICE_SPREAD");
        return (
            <MetricsPanel systemKey={systemKey} pipelineKey={pipelineKey} pipelineName={pipelineName}  />
        )
    }
}