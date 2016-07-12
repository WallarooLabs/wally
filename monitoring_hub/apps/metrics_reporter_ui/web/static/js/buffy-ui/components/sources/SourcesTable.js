import React from "react"
import { Table } from "react-bootstrap"
import SourceTableHeader from "./SourceTableHeader"
import SourceTableBodyContainer from "./SourceTableBodyContainer"
import { toJS } from "immutable"

export default class SourcesTable extends React.Component {
	render() {
		const { appName, linked, sourceType, sourceKeys } = this.props;
		const sourceTableBodies = sourceKeys.map((sourceKey) => {
			const sourceName = sourceKey.replace(sourceType + ":", "");
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