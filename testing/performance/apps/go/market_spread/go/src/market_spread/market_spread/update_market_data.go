package market_spread

type UpdateMarketData struct{}

func (umd *UpdateMarketData) Name() string {
	return "Update Market Data"
}

func (umd *UpdateMarketData) Compute(data interface{}, state interface{}) (interface{}, bool) {
	marketData := data.(*MarketData)
	symbolData := state.(*SymbolData)

	offerBidDifference := marketData.OfferPrice - marketData.BidPrice

	shouldRejectTrades := ((offerBidDifference >= 0.05) || ((offerBidDifference / marketData.Mid) >= 0.05))

	symbolData.LastBid = marketData.BidPrice
	symbolData.LastOffer = marketData.OfferPrice
	symbolData.ShouldRejectTrades = shouldRejectTrades

	return nil, true
}
