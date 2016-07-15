import React from 'react'
import humanizeDuration from "humanize-duration";

export default class Uptime extends React.Component {
 	shouldComponentUpdate(nextProps, nextState) {
		return this.formatUptime(this.props.uptime) !== this.formatUptime(nextProps.uptime);
  	}
  	formatUptime(uptime) {
		return humanizeDuration(uptime, {
			delimiter: " ", 
			round: true, 
			units:["h", "m"]});
  	}
  	render() {
		const formattedUptime = this.formatUptime(this.props.uptime)
		return (
			<span>{this.props.uptime ? formattedUptime : ""}</span>
		)
	}
}