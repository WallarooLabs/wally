import React from 'react'
import PipelinesTableHeader from  './PipelinesTableHeader'
import PipelineRow from './PipelineRow'
import { Table } from 'react-bootstrap'
import {combineStats} from "./calc/PipelineStatsCalc";
import AppConfig from "../../buffy-ui/config/AppConfig"


export default class PipelinesTable extends React.Component {
  render() {
    const rows = [];
    this.props.statuses.forEach((status, pipelineKey) => {
      const pipelineStats = this.props.benchmarkStats.get(pipelineKey);
      const latencyStats = pipelineStats.get("latencyStats");
      const throughputStats = pipelineStats.get("throughputStats");
      const stats = combineStats(latencyStats, throughputStats);
      const systemPath = AppConfig.getSystemPath(this.props.systemKey);
      const pipelinePath = AppConfig.getPipelinePath(this.props.systemKey, pipelineKey);
      rows.push(<PipelineRow 
        status={status} 
        key={pipelineKey}
        stats={stats}
        link={"/" + systemPath + "/pipelines/" + pipelinePath} />)
    });
    return (
      <Table className="statuses">
        <PipelinesTableHeader />
        <tbody>
          {rows}
        </tbody>
      </Table>
    )
  }
}