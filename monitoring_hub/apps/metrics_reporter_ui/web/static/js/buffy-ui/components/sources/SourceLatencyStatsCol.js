import React from "react"
import { Col} from "react-bootstrap"
import { Link } from "react-router"
import { formatLatencyBin } from "../../../util/Format"
import { is } from "immutable"

export default class SourceLatencyStatsCol extends React.Component {
	shouldComponentUpdate(nextProps) {
		return !is(this.props.latencyPercentileBinStats, nextProps.latencyPercentileBinStats);
	}
	render() {
		const { latencyPercentileBinStats } = this.props;
		const fiftiethBin = latencyPercentileBinStats.get("50.0");
		const seventyFifthBin = latencyPercentileBinStats.get("75.0");
		const ninetiethBin = latencyPercentileBinStats.get("90.0");
		return(
			<div>
				<Col lg={4}><p>{formatLatencyBin(fiftiethBin)}</p></Col>
				<Col lg={4}><p>{formatLatencyBin(seventyFifthBin)}</p></Col>
				<Col lg={4}><p>{formatLatencyBin(ninetiethBin)}</p></Col>
			</div>
		)
	}
}
