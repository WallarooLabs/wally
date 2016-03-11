import React from 'react'
import { Col, Panel } from 'react-bootstrap'

export default class MetricBox extends React.Component {
  render() {
    return(
      <Panel>
        <h3>{this.props.value}</h3>
        <p>{this.props.title}</p>
      </Panel>
    )
  }
}