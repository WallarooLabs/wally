package market_spread

type OrderResult struct {
	Order     *Order
	Bid       float64
	Offer     float64
	Timestamp uint64
}

func NewOrderResult(order *Order, bid float64, offer float64, timestamp uint64) *OrderResult {
	return &OrderResult{order, bid, offer, timestamp}
}
