import React from 'react'
import { Label } from 'react-bootstrap'

export default class StatusLabel extends React.Component {
  shouldComponentUpdate(nextProps, nextState) {
    return this.props.status !== nextProps.status;
  }
  render() {
  	const status = this.props.status;
  	let buttonStyle;
  	switch (status) {
  		case "Good":
  			buttonStyle = "success"
  			break
  		case "loading":
  			buttonStyle = "warning"
  			break
  		default:
  			buttonStyle = "danger"
  	} 
    return (
      <Label bsStyle={buttonStyle}>{this.props.status}</Label>
    )
  }
}