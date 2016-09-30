import {ReduceStore} from "flux/utils"
import Actions from "../actions/Actions"
import Dispatcher from "../../dispatcher/Dispatcher"
import {List, fromJS} from "immutable"
import UIDGen from "../../util/UIDGen"

class RejectedOrdersStore extends ReduceStore {
	constructor(dispatcher) {
		super(dispatcher);
		this.UIDGen = new UIDGen(1);
	}
	getInitialState() {
		return List();
	}
	getRejectedOrders() {
		return this.getState();
	}
	addRejectedOrders(state, rejectedOrders) {
		let orderId;
		rejectedOrders.forEach((rejectedOrder) => {
			orderId = rejectedOrder["order_id"];
			state = state.unshift(fromJS(rejectedOrder).set("UCID", this.UIDGen.next()));
		});
		return state.slice(0,100);
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