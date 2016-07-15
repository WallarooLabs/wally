import {symbolsWithDescriptions} from "./sp500.js"

function symbolDescriptions(symbol) {
	return symbolsWithDescriptions[symbol];
}

export default {
	symbolDescriptions: symbolDescriptions
}