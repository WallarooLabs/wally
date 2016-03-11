import React from "react";
import PipelinesTable from "./../../components/Pipelines/PipelinesTable";

export default class Dashboard extends React.Component {
  render() {
    return(
      <div>
        <PipelinesTable statuses={this.props.pipelineStatuses} benchmarkStats={this.props.benchmarkStats} systemKey={this.props.systemKey}/>
      </div>
    )
  }
}