package listener

import (
	"context"
	"log"
	"math/big"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
)

type EventListener struct {
	client      *ethclient.Client
	contracts   []common.Address
	startBlock  uint64
	eventChan   chan types.Log
	ctx         context.Context
	cancel      context.CancelFunc
}

func NewEventListener(rpcURL string, contractAddresses []string, startBlock uint64) (*EventListener, error) {
	client, err := ethclient.Dial(rpcURL)
	if err != nil {
		return nil, err
	}

	var contracts []common.Address
	for _, addr := range contractAddresses {
		contracts = append(contracts, common.HexToAddress(addr))
	}

	ctx, cancel := context.WithCancel(context.Background())

	return &EventListener{
		client:     client,
		contracts:  contracts,
		startBlock: startBlock,
		eventChan:  make(chan types.Log, 100),
		ctx:        ctx,
		cancel:     cancel,
	}, nil
}

func (el *EventListener) Start() error {
	query := ethereum.FilterQuery{
		FromBlock: big.NewInt(int64(el.startBlock)),
		Addresses: el.contracts,
	}

	logs := make(chan types.Log)
	sub, err := el.client.SubscribeFilterLogs(el.ctx, query, logs)
	if err != nil {
		return err
	}

	go func() {
		defer sub.Unsubscribe()
		for {
			select {
			case err := <-sub.Err():
				log.Printf("Subscription error: %v", err)
				return
			case vLog := <-logs:
				el.eventChan <- vLog
			case <-el.ctx.Done():
				return
			}
		}
	}()

	return nil
}

func (el *EventListener) GetEventChannel() <-chan types.Log {
	return el.eventChan
}

func (el *EventListener) Stop() {
	el.cancel()
	close(el.eventChan)
}
