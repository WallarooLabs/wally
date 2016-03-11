import React from 'react'

export default class Metric extends React.Component {
  render() {
    return(
      <p>{this.props.value} {this.props.metric}</p>
    )
  }
}