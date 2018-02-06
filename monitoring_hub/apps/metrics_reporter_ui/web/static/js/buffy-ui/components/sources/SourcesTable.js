import React from "react"
import { Table } from "react-bootstrap"
import SourceTableHeader from "./SourceTableHeader"
import SourceTableBodyContainer from "./SourceTableBodyContainer"
import { toJS } from "immutable"

export default class SourcesTable extends React.Component {
	render() {
		const { appName, linked, sourceType, sourceKeys } = this.props;
		const sourceTableBodies = sourceKeys.map((sourceKey) => {
			let updatedSourceType = sourceType;
			switch(sourceType) {
				case "computations-on-worker":
					updatedSourceType = "computation-by-worker";
					break;
				case "computations-for-pipeline-on-worker":
					updatedSourceType = "computation-by-worker";
					break;
				case "computations-for-pipeline":
					updatedSourceType = "computation";
			}
			const sourceName = sourceKey.split("||")[1];
			return <SourceTableBodyContainer
						linked={linked}
						appName={appName}
						sourceType={sourceType}
						sourceName={sourceName}
						key={sourceName} />
		});
		return(
			<Table>
				<SourceTableHeader />
				{sourceTableBodies.toJS()}
			</Table>
		)
	}
}
