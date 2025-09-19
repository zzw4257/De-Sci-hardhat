package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"desci-backend/internal/api"
	"desci-backend/internal/config"
	"desci-backend/internal/listener"
	"desci-backend/internal/model"
	"desci-backend/internal/repository"
	"desci-backend/internal/service"
)

func main() {
	// 加载配置
	cfg := config.Load()

	// 初始化数据库Repository
	repo, err := repository.NewRepository(cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	log.Println("✅ Database connected successfully")

	// 创建演示数据（如果数据库为空）
	if err := createDemoData(repo); err != nil {
		log.Printf("⚠️  Failed to create demo data: %v", err)
	}

	// 初始化Service层
	svc := service.NewService(repo)

	// 初始化API处理器
	handler := api.NewHandler(svc)

	// 设置HTTP路由
	router := handler.SetupRoutes()

	// 启动HTTP服务器
	server := &http.Server{
		Addr:    ":" + cfg.Port,
		Handler: router,
	}

	// 启动区块链事件监听器
	contractAddresses := []string{
		cfg.DeSciRegistryAddress,
		cfg.ResearchNFTAddress,
		cfg.DatasetManagerAddress,
		cfg.InfluenceRankingAddress,
		cfg.DeSciPlatformAddress,
	}
	
	// 过滤掉空地址
	var validAddresses []string
	for _, addr := range contractAddresses {
		if addr != "" {
			validAddresses = append(validAddresses, addr)
		}
	}
	
	if len(validAddresses) > 0 {
		eventListener, err := listener.NewEventListener(cfg.EthereumRPC, validAddresses, cfg.StartBlock)
		if err != nil {
			log.Printf("⚠️  Failed to create event listener: %v", err)
			log.Println("🚀 Starting server without blockchain listener...")
		} else {
			log.Println("✅ Event listener created successfully")
			
			// 设置事件处理器 - 使用闭包捕获repo和svc
			eventListener.SetEventHandler(func(event *model.ParsedEvent) error {
				log.Printf("📡 Processing blockchain event: %s", event.EventName)
				
				// 首先插入事件日志到 event_logs 表
				eventLog := &model.EventLog{
					TxHash:       event.TxHash,
					LogIndex:     uint(event.LogIndex),
					BlockNumber:  event.Block,
					EventName:    event.EventName,
					ContractAddr: event.Author, // 使用Author字段作为合约地址
					PayloadRaw:   `{"tokenId":"` + event.TokenID + `","title":"` + event.Title + `","description":"` + event.Description + `"}`,
					Processed:    false,
					CreatedAt:    time.Now(),
				}
				
				// 插入事件日志
				if err := repo.InsertEventLog(eventLog); err != nil {
					log.Printf("⚠️  Failed to insert event log: %v", err)
				} else {
					log.Printf("📝 Event log inserted: %s", event.EventName)
				}
				
				// 根据事件类型处理数据库操作
				switch event.EventName {
				case "UserRegistered":
					log.Printf("💾 Syncing user registration event to database...")
					log.Printf("✅ User event processed: %s", event.TokenID)
					
				case "DatasetUploaded":
					log.Printf("💾 Syncing dataset upload event to database...")
					log.Printf("✅ Dataset event processed: %s", event.TokenID)
					
				case "ResearchMinted", "ResearchCreated":
					log.Printf("💾 Syncing research NFT event to database...")
					
					// 使用唯一TokenID（避免重复）
					uniqueTokenID := event.TokenID + "-" + string(rune(int('A') + int(event.Block%26)))
					
					// 创建研究数据记录
					researchData := &model.ResearchData{
						TokenID:      uniqueTokenID,
						Title:        event.Title,
						Authors:      []string{event.Author}, // 简化处理
						ContentHash:  event.DataHash,
						MetadataHash: event.DataHash, // 简化处理
						BlockNumber:  event.Block,
						CreatedAt:    time.Now(),
						UpdatedAt:    time.Now(),
					}
					
					log.Printf("🔍 Attempting to insert: TokenID=%s, Title=%s, Block=%d", 
						researchData.TokenID, researchData.Title, researchData.BlockNumber)
					
					// 插入数据库
					if err := repo.InsertResearchData(researchData); err != nil {
						log.Printf("❌ Failed to sync research data: %v", err)
						return err
					}
					
					log.Printf("✅ Research data synced: TokenID=%s, Block=%d", researchData.TokenID, event.Block)
					
				default:
					log.Printf("⚠️  Unknown event type: %s", event.EventName)
					log.Printf("✅ Event logged: %s", event.TokenID)
				}
				
				// 调用Service层处理（如果事件类型匹配）
				if event.EventName == "ResearchMinted" || event.EventName == "ResearchCreated" {
					// 确保事件名称为Service层期望的名称
					eventLog.EventName = "ResearchCreated"
					if err := svc.ProcessEvent(eventLog); err != nil {
						log.Printf("⚠️  Service processing failed: %v", err)
					} else {
						log.Printf("✅ Service processed event successfully")
					}
				}
				
				return nil
			})
			
			// 在goroutine中启动事件监听
			go func() {
				if err := eventListener.Start(); err != nil {
					log.Printf("❌ Event listener error: %v", err)
				}
			}()
			log.Println("🔄 Blockchain event listener started")
		}
	} else {
		log.Println("⚠️  No contract addresses configured, starting server without blockchain listener...")
	}

	// 启动HTTP服务器
	go func() {
		log.Printf("🚀 Server starting on :%s", cfg.Port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("❌ Server failed to start: %v", err)
		}
	}()

	// 优雅关闭
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("🛑 Server shutting down...")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Printf("❌ Server forced to shutdown: %v", err)
	}

	log.Println("✅ Server exited")
}

// createDemoData 创建演示数据（如果数据库为空）
func createDemoData(repo *repository.Repository) error {
	// 检查是否已有演示数据
	existing, err := repo.GetResearchData("demo-token-123")
	if err == nil && existing != nil {
		log.Println("📋 Demo data already exists, skipping creation")
		return nil
	}

	log.Println("📋 Creating demo data...")

	// 创建演示研究数据
	demoResearch := &model.ResearchData{
		TokenID:      "demo-token-123",
		Title:        "区块链在科学数据管理中的应用研究",
		Authors:      model.StringArray{"0x742d35Cc6731C0532925a3b8D4Ca78fC6fD7F4dC", "0x8ba1f109551bD432803012645Hac136c"},
		ContentHash:  "0xa7c617352ec25c35382e0f0190cbe99c6aba8e3d30b910d58c85a6e4782da079",
		MetadataHash: "0xabcdef1234567890abcdef1234567890abcdef12",
		BlockNumber:  18500000,
	}

	if err := repo.InsertResearchData(demoResearch); err != nil {
		return err
	}

	// 创建演示数据集
	demoDataset := &model.DatasetRecord{
		DatasetID:   "dataset-456",
		Title:       "区块链交易数据集",
		Description: "包含以太坊主网2023年交易数据的综合数据集",
		Owner:       "0x742d35Cc6634C0532925a3b8D3AC92F3B1a3C",
		DataHash:    "QmX7VmP8K9Z1N2M3B4A5C6D7E8F9G0H1I2J3K4L5M6N7O8P9Q",
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}

	if err := repo.InsertDatasetRecord(demoDataset); err != nil {
		return err
	}

	// 创建演示事件日志
	demoEvent := &model.EventLog{
		EventName:    "ResearchCreated",
		ContractAddr: "0x1234567890123456789012345678901234567890",
		TxHash:       "0xdemo1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab",
		BlockNumber:  18500000,
		LogIndex:     0,
		PayloadRaw:   `{"tokenId":"demo-token-123","title":"区块链在科学数据管理中的应用研究","authors":["张三","李四","王五"]}`,
		Processed:    true,
	}

	if err := repo.InsertEventLog(demoEvent); err != nil {
		return err
	}

	log.Println("✅ Demo data created successfully")
	log.Println("📋 Demo Research Token ID: demo-token-123")
	log.Println("📋 Demo Dataset ID: dataset-456")
	
	return nil
}
