package market_spread

import (
	"bufio"
	"fmt"
	"os"
)

func symbolToKey(symbol string) string {
	return fmt.Sprintf("%4s", symbol)
}

func LoadValidSymbols() []string {
	symbols := make([]string, 0)
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

func (spf *SymbolPartitionFunction) Partition(data interface{}) string {
	symbol := data.(SymbolMessage).GetSymbol()
	return symbolToKey(symbol)
}
