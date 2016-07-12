import React from "react";
import {Link} from "react-router";


export default class Breadcrumbs extends React.Component {
	absolutePath(routes, index) {
		const currentRoute = routes.slice(0, index + 1);
		const joinedRoutes = currentRoute.reduce((prev, next, j) =>{
			if (j == 1) {
				return {path: prev.path + next.path};
			} else {
				return {path: prev.path + "/" + next.path};
			};
		});
		return joinedRoutes.path;
	}
	render() {
		return(
			<ol className="breadcrumb">
				{this.props.routes.map((item, index) =>
					<li 
						className={this.props.routes.length == index + 1 ? "active" : ""}
						key={index}>
						{
							this.props.routes.length == index + 1 ? 
									<span>{item.title}</span> : <Link to={
										this.absolutePath(this.props.routes, index)
									}>{item.title}</Link>
						}
					</li>
				)}
			</ol>
		)
	}
}