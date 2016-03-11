import React from "react"
import Uptime from "../Uptime"
import StatusLabel from "../labels/StatusLabel"
import MetricsTable from "./Metrics/MetricsTable"
import { Link } from "react-router"
import Moment from "moment"
import { numberWithCommas } from "../../util/Format.js";

export default class PipelineRow extends React.Component {
  shouldComponentUpdate(nextProps, nextState) {
    return this.props.status !== nextProps.status || this.props.stats !== nextProps.stats;
  }
  render() {
    return(
      <tr>
        <td>
          {
            this.props.link ? 
            <Link to={this.props.link}>{this.props.status.get("pipelineName")}</Link> :
            this.props.status.get("pipelineName")
          }
        </td>
        <td><StatusLabel status={this.props.status.get("status")} /></td>
        <td><p><Uptime  uptime={this.props.status.get("uptime")}/></p></td>
        <td><MetricsTable stats={this.props.stats} metric="latency" /></td>
        <td><MetricsTable stats={this.props.stats} metric="throughput" /></td>
      </tr>
    )
  }
}