import React from 'react'

export default class PipelineTitle extends React.Component {
  render() {
    return (
      <div>
        <h2>{this.props.title}<br /><small>{this.props.description}</small></h2>
      </div>
    )
  }
}