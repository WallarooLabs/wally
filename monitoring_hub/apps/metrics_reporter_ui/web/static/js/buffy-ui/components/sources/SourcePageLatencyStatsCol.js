import React from "react"
import { Col} from "react-bootstrap"
import { Link } from "react-router"
import { formatLatencyBin } from "../../../util/Format"
import { is } from "immutable"

export default class SourcePageLatencyStatsCol extends React.Component {
	shouldComponentUpdate(nextProps) {
		return !is(this.props.latencyPercentileBinStats, nextProps.latencyPercentileBinStats);
	}
	render() {
		const { latencyPercentileBinStats } = this.props;
		const fiftiethBin = latencyPercentileBinStats.get("50.0");
		const ninetyFifthBin = latencyPercentileBinStats.get("95.0");
		const ninetyNinthBin = latencyPercentileBinStats.get("99.0");
		const threeNinesBin = latencyPercentileBinStats.get("99.9");
		const fourNinesBin = latencyPercentileBinStats.get("99.99");
		return(
			<div>
				<Col lg={2}><p>{formatLatencyBin(fiftiethBin)}</p></Col>
				<Col lg={2}><p>{formatLatencyBin(ninetyFifthBin)}</p></Col>
				<Col lg={2}><p>{formatLatencyBin(ninetyNinthBin)}</p></Col>
				<Col lg={2}><p>{formatLatencyBin(threeNinesBin)}</p></Col>
				<Col lg={2}><p>{formatLatencyBin(fourNinesBin)}</p></Col>
			</div>
		)
	}
}
