import {ReduceStore} from "flux/utils"
import Actions from "../actions/Actions"
import Dispatcher from "../../dispatcher/Dispatcher"
import {Map, fromJS} from "immutable"
import UIDGen from "../../util/UIDGen"

class RejectedOrdersStore extends ReduceStore {
	constructor(dispatcher) {
		super(dispatcher);
		this.UIDGen = new UIDGen(1);
	}
	getInitialState() {
		return Map();
	}
	getRejectedOrders() {
		return this.getState().toList();
	}
	addRejectedOrders(state, rejectedOrders) {
		let orderId;
		rejectedOrders.forEach((rejectedOrder) => {
			orderId = rejectedOrder["order_id"];
			state = state.set(orderId, fromJS(rejectedOrder).set("UCID", this.UIDGen.next()));
		});
		return state;
	}
	reduce(state, action) {
		switch(action.actionType) {
			case Actions.RECEIVE_REJECTED_ORDERS_MSGS.actionType:
				return this.addRejectedOrders(state, action.rejectedOrders["rejected_orders"]);
			default:
				return state;
		}
	}
}

const rejectedOrdersStore = new RejectedOrdersStore(Dispatcher);
export default rejectedOrdersStore;