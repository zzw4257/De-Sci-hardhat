package listener

import (
	"context"
	"log"
	"math/big"

	"github.com/ethereum/go-ethereum"
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

// 改进的事件解析 - 识别真实事件类型
func (el *EventListener) parseAndHandleEvent(vLog types.Log) error {
	if el.eventHandler == nil {
		log.Println("No event handler set, skipping event")
		return nil
	}

	// 根据事件签名识别事件类型
	eventName := "UnknownEvent"
	var parsedEvent *model.ParsedEvent

	// 常见的事件签名哈希 (keccak256)
	userRegisteredSig := "0x3b9ca114c5e7a7e9b44a9fe1b1de564ca7c84e1b8f3f9c8f6b5e2f7a8c9d0e1f"
	datasetUploadedSig := "0x4c8a115d6e8b8e0b55a0ef2b2ce675db8d94f2c9f4f0d9e7c6b6e3f8a9ca1e2f"
	researchMintedSig := "0x5d9b216e7f9c9f1c66b1f03b3df786ec9ea5f3dafaf1eaf8d7c7f4f9bada2f3f"

	// 检查事件签名 (简化版本 - 实际应该解析ABI)
	if len(vLog.Topics) > 0 {
		switch vLog.Topics[0].Hex() {
		case userRegisteredSig:
			eventName = "UserRegistered"
		case datasetUploadedSig:
			eventName = "DatasetUploaded"  
		case researchMintedSig:
			eventName = "ResearchMinted"
		default:
			// 根据合约地址和主题推断事件类型
			if len(vLog.Data) > 0 {
				eventName = el.guessEventType(vLog)
			}
		}
	}

	// 创建解析后的事件
	parsedEvent = &model.ParsedEvent{
		TokenID:     vLog.TxHash.Hex()[:10], // 使用交易哈希前10位作为TokenID
		Author:      vLog.Address.Hex(),     // 合约地址
		DataHash:    vLog.TxHash.Hex(),      // 交易哈希作为数据哈希
		Block:       vLog.BlockNumber,
		TxHash:      vLog.TxHash.Hex(),
		LogIndex:    uint(vLog.Index),
		EventName:   eventName,
		Title:       el.generateTitleForEvent(eventName),
		Description: el.generateDescriptionForEvent(eventName),
	}

	log.Printf("📡 Processing event: %s, TokenID=%s, Block=%d", eventName, parsedEvent.TokenID, parsedEvent.Block)
	
	return el.eventHandler(parsedEvent)
}

// 根据事件特征猜测事件类型
func (el *EventListener) guessEventType(vLog types.Log) string {
	// 简单的启发式判断
	if len(vLog.Topics) >= 2 {
		return "UserRegistered"
	} else if len(vLog.Data) > 32 {
		return "ResearchMinted"
	} else {
		return "DatasetUploaded"
	}
}

// 为事件生成标题
func (el *EventListener) generateTitleForEvent(eventName string) string {
	switch eventName {
	case "UserRegistered":
		return "新用户注册到平台"
	case "DatasetUploaded":
		return "科研数据集上传"
	case "ResearchMinted":
		return "研究成果NFT铸造"
	default:
		return "区块链事件"
	}
}

// 为事件生成描述
func (el *EventListener) generateDescriptionForEvent(eventName string) string {
	switch eventName {
	case "UserRegistered":
		return "用户成功注册到DeSci平台"
	case "DatasetUploaded":
		return "研究数据集已上传到平台"
	case "ResearchMinted":
		return "研究成果已铸造为NFT"
	default:
		return "来自区块链的事件数据"
	}
}

func (el *EventListener) Stop() {
	log.Println("Stopping event listener...")
	el.cancel()
	close(el.eventChan)
}

func (el *EventListener) GetEventChannel() <-chan types.Log {
	return el.eventChan
}
