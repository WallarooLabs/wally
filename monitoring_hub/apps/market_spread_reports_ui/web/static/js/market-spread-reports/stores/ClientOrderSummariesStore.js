import {ReduceStore} from "flux/utils"
import Actions from "../actions/Actions"
import Dispatcher from "../../dispatcher/Dispatcher"
import {Map, fromJS} from "immutable"

class ClientOrderSummariesStore extends ReduceStore {
	constructor(dispatcher) {
		super(dispatcher);
	}
	getInitialState() {
		return Map();
	}
	getClientOrderSummaries() {
		return this.getState().toList();
	}
	addClientOrderSummaries(state, clientOrderSummaries) {
		let clientId;
		clientOrderSummaries.forEach((clientOrderSummary) => {
			clientId = clientOrderSummary["client_id"];
			state = state.set(clientId, fromJS(clientOrderSummary));
		});
		return state;
	}
	reduce(state, action) {
		switch(action.actionType) {
			case Actions.RECEIVE_CLIENT_ORDER_SUMMARIES.actionType:
				return this.addClientOrderSummaries(state, action.summaries["client_order_summary_msgs"]);
			default:
				return state;
		}
	}
}

const clientOrderSummariesStore = new ClientOrderSummariesStore(Dispatcher);
export default clientOrderSummariesStore;