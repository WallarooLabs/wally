import React from 'react'
import PipelineTitle from './PipelineTitle'
import StatusLabel  from '../labels/StatusLabel'
import { Panel, Col } from 'react-bootstrap'

export default class PipeLineHeader extends React.Component {
  render() {
    return (
      <div>
        <PipelineTitle title={this.props.title} description="Market data ingestion to price spread capture" />
        <h4>Status: <StatusLabel status={this.props.status} /></h4>
      </div>
    )
  }
}