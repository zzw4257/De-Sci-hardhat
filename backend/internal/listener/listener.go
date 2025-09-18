package listener

import (
	"context"
	"log"
	"math/big"
	"strings"
	"time"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
	
	"desci-backend/internal/model"
)

type EventListener struct {
	client      *ethclient.Client
	contracts   []common.Address
	startBlock  uint64
	eventChan   chan types.Log
	ctx         context.Context
	cancel      context.CancelFunc
	eventHandler func(*model.ParsedEvent) error
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

func (el *EventListener) SetEventHandler(handler func(*model.ParsedEvent) error) {
	el.eventHandler = handler
}

func (el *EventListener) Start() error {
	log.Printf("Starting event listener for %d contracts...", len(el.contracts))
	
	// 先获取历史事件
	go el.processHistoricalEvents()
	
	// 然后监听新事件
	go el.subscribeToNewEvents()
	
	// 处理事件
	go el.processEvents()
	
	return nil
}

func (el *EventListener) processHistoricalEvents() {
	log.Println("Fetching historical events...")
	
	query := ethereum.FilterQuery{
		FromBlock: big.NewInt(int64(el.startBlock)),
		ToBlock:   nil, // latest
		Addresses: el.contracts,
	}

	logs, err := el.client.FilterLogs(el.ctx, query)
	if err != nil {
		log.Printf("Error fetching historical logs: %v", err)
		return
	}

	log.Printf("Found %d historical events", len(logs))
	for _, vLog := range logs {
		select {
		case el.eventChan <- vLog:
		case <-el.ctx.Done():
			return
		}
	}
}

func (el *EventListener) subscribeToNewEvents() {
	query := ethereum.FilterQuery{
		Addresses: el.contracts,
	}

	logs := make(chan types.Log)
	sub, err := el.client.SubscribeFilterLogs(el.ctx, query, logs)
	if err != nil {
		log.Printf("Error subscribing to logs: %v", err)
		return
	}

	log.Println("Subscribed to new events...")
	defer sub.Unsubscribe()

	for {
		select {
		case err := <-sub.Err():
			log.Printf("Subscription error: %v", err)
			return
		case vLog := <-logs:
			log.Printf("New event received: block %d, tx %s", vLog.BlockNumber, vLog.TxHash.Hex())
			select {
			case el.eventChan <- vLog:
			case <-el.ctx.Done():
				return
			}
		case <-el.ctx.Done():
			return
		}
	}
}

func (el *EventListener) processEvents() {
	log.Println("Event processor started...")
	
	for {
		select {
		case vLog := <-el.eventChan:
			if err := el.parseAndHandleEvent(vLog); err != nil {
				log.Printf("Error processing event: %v", err)
			}
		case <-el.ctx.Done():
			return
		}
	}
}

// 简化的事件解析 - 创建演示数据
func (el *EventListener) parseAndHandleEvent(vLog types.Log) error {
	if el.eventHandler == nil {
		log.Println("No event handler set, skipping event")
		return nil
	}

	// 创建演示的ParsedEvent
	parsedEvent := &model.ParsedEvent{
		TokenID:     vLog.TxHash.Hex()[:10], // 使用交易哈希前10位作为TokenID
		Author:      vLog.Address.Hex(),     // 使用合约地址作为Author
		DataHash:    vLog.TxHash.Hex(),      // 使用交易哈希作为DataHash
		Block:       vLog.BlockNumber,
		TxHash:      vLog.TxHash.Hex(),
		LogIndex:    uint(vLog.Index),
		EventName:   "MockEvent",
		Title:       "Mock Research from Blockchain",
		Description: "This is a demo event from blockchain listener",
	}

	log.Printf("Processing event: TokenID=%s, Block=%d", parsedEvent.TokenID, parsedEvent.Block)
	
	return el.eventHandler(parsedEvent)
}

func (el *EventListener) Stop() {
	log.Println("Stopping event listener...")
	el.cancel()
}

func (el *EventListener) GetEventChannel() <-chan types.Log {
	return el.eventChan
}

func (el *EventListener) Stop() {
	el.cancel()
	close(el.eventChan)
}
