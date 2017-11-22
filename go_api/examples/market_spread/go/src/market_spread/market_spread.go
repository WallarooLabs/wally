package main

import (
	"C"
	"fmt"
	ms "market_spread/market_spread"
	wa "wallarooapi"
	app "wallarooapi/application"
)

//export ApplicationSetup
func ApplicationSetup() *C.char {
	fmt.Println("wallarooapi.Args=", wa.Args)

	wa.Serialize = ms.Serialize
	wa.Deserialize = ms.Deserialize

	symbols := ms.LoadValidSymbols()

	application := app.MakeApplication("market-spread")
	application.NewPipeline("Orders", app.MakeTCPSourceConfig("127.0.0.1", "7010", &ms.OrderDecoder{})).
		ToStatePartition(&ms.CheckOrder{}, &ms.SymbolDataBuilder{}, "symbol-data", &ms.SymbolPartitionFunction{}, symbols, true).
		ToSink(app.MakeTCPSinkConfig("127.0.0.1", "7002", &ms.OrderResultEncoder{}))

	application.NewPipeline("Market Data", app.MakeTCPSourceConfig("127.0.0.1", "7011", &ms.MarketDataDecoder{})).
		ToStatePartition(&ms.UpdateMarketData{}, &ms.SymbolDataBuilder{}, "symbol-data", &ms.SymbolPartitionFunction{}, symbols, true).
		Done()

	json := application.ToJson()
	fmt.Println(json)

	return C.CString(json)
}

func main() {
}
