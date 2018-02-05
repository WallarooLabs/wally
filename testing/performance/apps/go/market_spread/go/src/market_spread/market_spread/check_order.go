package market_spread

import (
	"fmt"
	"time"
)

type CheckOrder struct {}

func (co *CheckOrder) Name() string {
	return "Check Order"
}

func (co *CheckOrder) Compute(data interface{}, state interface{}) (interface{}, bool) {
	order := data.(*Order)
	symbolData := state.(*SymbolData)

	if symbolData.ShouldRejectTrades {
		fmt.Println("Rejected trade")
		var orderCopy Order = *order
		ts := uint64(time.Now().UnixNano())
		return NewOrderResult(&orderCopy, symbolData.LastBid, symbolData.LastOffer, ts), false
	}
	return nil, false
}
