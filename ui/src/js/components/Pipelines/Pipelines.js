import React from 'react'
import Dashboard from "../../buffy-ui/components/Dashboard"

export default class Pipelines extends React.Component {
  render() {
    return(
      <div>
        {this.props.children || <Dashboard />}
      </div>
    )
  }
}