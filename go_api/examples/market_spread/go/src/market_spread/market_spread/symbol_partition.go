package market_spread

import (
	"bufio"
	"encoding/binary"
	"fmt"
	"os"
)

func symbolToKey(symbol string) uint64 {
	x := uint64(binary.BigEndian.Uint32([]byte(fmt.Sprintf("%4s", symbol))))
	fmt.Println("Key is ", x)
	return x
}

func LoadValidSymbols() []uint64 {
	symbols := make([]uint64, 0)
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

func (spf *SymbolPartitionFunction) Partition(data interface{}) uint64 {
	symbol := data.(SymbolMessage).GetSymbol()
	return symbolToKey(symbol)
}
