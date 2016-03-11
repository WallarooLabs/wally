import React from "react"
import { Col, Panel } from "react-bootstrap"
import {formatLatency} from "../../../util/Format"

export default class LatencyMetricBox extends React.Component {
  render() {
  	let val = formatLatency(this.props.value) + " ms";
    return(
      <Panel>
        <h3>{val}</h3>
        <p>{this.props.title}</p>
      </Panel>
    )
  }
}