package market_spread

import (
	"bufio"
	"fmt"
	"os"
)

func symbolToKey(symbol string) []byte {
	return []byte(fmt.Sprintf("%4s", symbol))
}

func LoadValidSymbols() [][]byte {
	symbols := make([][]byte, 0)
	file, _ := os.Open("symbols.txt")
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		symbols = append(symbols, symbolToKey(scanner.Text()))
	}
	return symbols
}

type SymbolPartitionFunction struct {
}

func (spf *SymbolPartitionFunction) Partition(data interface{}) []byte {
	symbol := data.(SymbolMessage).GetSymbol()
	return symbolToKey(symbol)
}
