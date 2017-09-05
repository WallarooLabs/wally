import React from "react"
import { Table } from "react-bootstrap"
import SourceTableHeader from "./SourceTableHeader"
import SourceTableBodyContainer from "./SourceTableBodyContainer"
import IngestionSourceTableBodyContainer from "./IngestionSourceTableBodyContainer"
import { toJS } from "immutable"

export default class IngestionSourcesTable extends React.Component {
	render() {
		const { appName, linked, sourceType, sourceKeys, ingestionSourceKeys } = this.props;
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
			const sourceName = sourceKey.replace(updatedSourceType + ":", "");
			const ingestionSourceType = "pipeline-ingestion:"
			const ingestionSourceKey = ingestionSourceType + sourceName + " source";
			if (ingestionSourceKeys.includes(ingestionSourceKey)) {
				const ingestionSourceName = sourceName + " source";
				return <IngestionSourceTableBodyContainer
					linked={linked}
					appName={appName}
					sourceType={sourceType}
					sourceName={sourceName}
					ingestionSourceName={ingestionSourceName}
					key={sourceName} />
			} else {
				return <SourceTableBodyContainer
					linked={linked}
					appName={appName}
					sourceType={sourceType}
					sourceName={sourceName}
					key={sourceName} />
			}
		});
		return(
			<Table>
				<SourceTableHeader />
				{sourceTableBodies.toJS()}
			</Table>
		)
	}
}
