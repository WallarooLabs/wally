package market_spread

type SymbolData struct {
	LastBid            float64
	LastOffer          float64
	ShouldRejectTrades bool
}

func NewSymbolData() *SymbolData {
	return &SymbolData{0.0, 0.0, false}
}

type SymbolDataBuilder struct{}

func (sdb *SymbolDataBuilder) Name() string {
	return "symbol data builder"
}

func (sdb *SymbolDataBuilder) Build() interface{} {
	return NewSymbolData()
}
