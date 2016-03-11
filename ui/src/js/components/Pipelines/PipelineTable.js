import React from "react";
import PipelinesTableHeader from "./PipelinesTableHeader";
import PipelineRow from "./PipelineRow";
import { Table } from "react-bootstrap";
import {filterLast5Minutes} from "../../util/BenchmarksHelpers";
import {throughputInThousands} from "../../util/Format";
import {compileStats} from "./calc/PipelineStatsCalc";

export default class PipelineTable extends React.Component {
	shouldComponentUpdate(nextProps, nextState) {
		return this.props.status !== nextProps.status || this.props.stats !== nextProps.stats;
	}
	render() {
		const row = <PipelineRow status={this.props.status} stats={this.props.stats}/>;
		return(
			<Table className="statuses">
				<PipelinesTableHeader />
				<tbody>
					{row}
				</tbody>
			</Table>
		)
	}
}
