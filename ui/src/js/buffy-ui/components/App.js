import React from 'react'
//import GlobalNav from './GlobalNav'
//import System from "../../components/system/System";
import Breadcrumbs from "../../components/Breadcrumbs";
import MarketDataPipeline from "./pipelines/MarketDataPipeline";
import MarketDataPipelineNode1 from "./pipelines/MarketDataPipelineNode1";


//            <GlobalNav />

export default class App extends React.Component {
    render() {
		return (
          <div>
            <div className="container">
                <MarketDataPipeline />
                <MarketDataPipelineNode1 />
            </div>
          </div>
        )
	}
}

//<Breadcrumbs routes={this.props.routes}/>
//{this.props.children || <System />}
