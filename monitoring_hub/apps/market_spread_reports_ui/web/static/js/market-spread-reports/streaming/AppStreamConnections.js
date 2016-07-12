import Actions from "../actions/Actions"
import ActionCreators from "../actions/ActionCreators"

function channelHubToDispatcherWith(connector) {
	connector.connectTo("reports:market-spread")
		.dispatchOn("rejected-order-msgs", ActionCreators[Actions.RECEIVE_REJECTED_ORDERS_MSGS.actionType])
		.dispatchOn("client-order-summary-msgs", ActionCreators[Actions.RECEIVE_CLIENT_ORDER_SUMMARIES.actionType]);
}

export default {
	channelHubToDispatcherWith: channelHubToDispatcherWith
}