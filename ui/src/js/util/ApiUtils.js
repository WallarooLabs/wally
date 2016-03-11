import Actions from "../gridgain-poc/actions/Actions";
import ActionCreators from "../gridgain-poc/actions/ActionCreators";
import Dispatcher from "../dispatcher/Dispatcher";
import Rand from "./Rand";

function getClientLimitsData() {
	// simulate API call
	const clients = ["Jim", "Mary", "Fred", "Betsy", "Barnabus", "Collette"];
	let data = [];
	clients.forEach(client => {
		const limit = Rand.rollFromZero(15000);
		data.push({
			client: client,
			limit: limit
		});
	});

	// simulate success callback
	const transformer = ActionCreators[Actions.RECEIVE_CLIENT_LIMITS];
	Dispatcher.dispatch(transformer(data));
}

module.exports = {
	getClientLimitsData: getClientLimitsData
}