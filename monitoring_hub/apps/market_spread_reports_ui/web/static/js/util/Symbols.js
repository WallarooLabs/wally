import {symbolsWithDescriptions} from "./sp500.js"

function symbolDescriptions(symbol) {
	return symbolsWithDescriptions[symbol.trim()];
}

export default {
	symbolDescriptions: symbolDescriptions
}