import Actions from "./Actions"

function produceAction(type, prop) {
	return function(data) {
		const action = {};
		action.actionType = type;
		action[prop] = data;

		return action;
	}
}

const actionCreators = {};

Object.keys(Actions).forEach(actionKey => {
	const actionType = Actions[actionKey].actionType;
	const actionProp = Actions[actionKey].actionProp;
	actionCreators[actionType] = produceAction(actionType, actionProp);
});

export default actionCreators;