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

	// TODO: 区块链事件监听器暂时关闭，等待Go版本升级
	log.Println("⚠️  Blockchain listener disabled due to Go version compatibility")

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
		Authors:      []string{"张三", "李四", "王五"},
		ContentHash:  "0x1234567890abcdef1234567890abcdef12345678",
		MetadataHash: "0xabcdef1234567890abcdef1234567890abcdef12",
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
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
		EventName:   "ResearchCreated",
		ContractAddress: "0x1234567890123456789012345678901234567890",
		TxHash:      "0xdemo1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab",
		BlockNumber: 18500000,
		LogIndex:    0,
		PayloadRaw:  `{"tokenId":"demo-token-123","title":"区块链在科学数据管理中的应用研究","authors":["张三","李四","王五"]}`,
		Processed:   true,
		CreatedAt:   time.Now(),
	}

	if err := repo.InsertEventLog(demoEvent); err != nil {
		return err
	}

	log.Println("✅ Demo data created successfully")
	log.Println("📋 Demo Research Token ID: demo-token-123")
	log.Println("📋 Demo Dataset ID: dataset-456")
	
	return nil
}