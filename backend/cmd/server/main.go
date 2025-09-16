package main

import (
	"log"
	"context"
	"os"
	"os/signal"
	"syscall"
	"time"

	"desci-backend/internal/api"
	"desci-backend/internal/config"
	"desci-backend/internal/listener"
	"desci-backend/internal/repository"
	"desci-backend/internal/service"
)

func main() {
	// 加载配置
	cfg := config.Load()

	// 初始化数据库
	repo, err := repository.NewRepository(cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	// 初始化服务
	svc := service.NewService(repo)

	// 初始化API路由
	handler := api.NewHandler(svc)
	router := handler.SetupRoutes()

	// 启动事件监听器（如果配置了合约地址）
	if cfg.DeSciRegistryAddress != "" {
		contractAddresses := []string{
			cfg.DeSciRegistryAddress,
			cfg.ResearchNFTAddress,
			cfg.DatasetManagerAddress,
			cfg.InfluenceRankingAddress,
			cfg.DeSciPlatformAddress,
		}

		eventListener, err := listener.NewEventListener(cfg.EthereumRPC, contractAddresses, cfg.StartBlock)
		if err != nil {
			log.Printf("Failed to create event listener: %v", err)
		} else {
			if err := eventListener.Start(); err != nil {
				log.Printf("Failed to start event listener: %v", err)
			} else {
				log.Println("Event listener started")
				// TODO: 处理事件的goroutine
			}
		}
	}

	// 启动HTTP服务器
	log.Printf("Starting server on port %s", cfg.Port)
	if err := router.Run(":" + cfg.Port); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}

	// 优雅关闭
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("Shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	log.Println("Server shutdown complete")
}
