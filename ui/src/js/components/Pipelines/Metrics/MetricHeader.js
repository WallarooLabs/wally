import React from 'react'

export default class MetricHeader extends React.Component {
  render() {
    return (
      <h3>{this.props.title} <small>{this.props.measurement}</small></h3>
    )
  }
} 