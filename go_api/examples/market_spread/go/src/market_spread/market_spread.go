package main

import (
	"C"
	"flag"
	"fmt"
	ms "market_spread/market_spread"
	"strings"
	wa "wallarooapi"
	app "wallarooapi/application"
)

//export ApplicationSetup
func ApplicationSetup() *C.char {
	fs := flag.NewFlagSet("wallaroo", flag.ExitOnError)
	inHostsPortsArg := fs.String("in", "", "input host:port list")
	outHostsPortsArg := fs.String("out", "", "output host:port list")

	fs.Parse(wa.Args[1:])

	inHostsPorts := hostsPortsToList(*inHostsPortsArg)

	orderHost := inHostsPorts[0][0]
	orderPort := inHostsPorts[0][1]

	marketDataHost := inHostsPorts[1][0]
	marketDataPort := inHostsPorts[1][1]

	outHostsPorts := hostsPortsToList(*outHostsPortsArg)
	outHost := outHostsPorts[0][0]
	outPort := outHostsPorts[0][1]

	wa.Serialize = ms.Serialize
	wa.Deserialize = ms.Deserialize

	symbols := ms.LoadValidSymbols()

	application := app.MakeApplication("market-spread")
	application.NewPipeline("Orders", app.MakeTCPSourceConfig(orderHost, orderPort, &ms.OrderDecoder{})).
		ToStatePartition(&ms.CheckOrder{}, &ms.SymbolDataBuilder{}, "symbol-data", &ms.SymbolPartitionFunction{}, symbols, true).
		ToSink(app.MakeTCPSinkConfig(outHost, outPort, &ms.OrderResultEncoder{}))

	application.NewPipeline("Market Data", app.MakeTCPSourceConfig(marketDataHost, marketDataPort, &ms.MarketDataDecoder{})).
		ToStatePartition(&ms.UpdateMarketData{}, &ms.SymbolDataBuilder{}, "symbol-data", &ms.SymbolPartitionFunction{}, symbols, true).
		Done()

	json := application.ToJson()
	fmt.Println(json)

	return C.CString(json)
}

func hostsPortsToList(hostsPorts string) [][]string {
	hostsPortsList := make([][]string, 0)
	for _, hp := range strings.Split(hostsPorts, ",") {
		hostsPortsList = append(hostsPortsList, strings.Split(hp, ":"))
	}
	return hostsPortsList
}

func main() {
}
