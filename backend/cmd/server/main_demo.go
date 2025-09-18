package main

import (
	"encoding/json"
	"log"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

type ResearchData struct {
	TokenID      string    `json:"tokenId"`
	Title        string    `json:"title"`
	Authors      []string  `json:"authors"`
	ContentHash  string    `json:"contentHash"`
	MetadataHash string    `json:"metadataHash"`
	CreatedAt    time.Time `json:"createdAt"`
}

type DatasetRecord struct {
	DatasetID   string    `json:"datasetId"`
	Title       string    `json:"title"`
	Description string    `json:"description"`
	Owner       string    `json:"owner"`
	DataHash    string    `json:"dataHash"`
	CreatedAt   time.Time `json:"createdAt"`
}

// 模拟数据
var demoResearch = &ResearchData{
	TokenID:      "demo-token-123",
	Title:        "区块链在科学数据管理中的应用研究",
	Authors:      []string{"张三", "李四", "王五"},
	ContentHash:  "0x1234567890abcdef1234567890abcdef12345678",
	MetadataHash: "0xabcdef1234567890abcdef1234567890abcdef12",
	CreatedAt:    time.Now(),
}

var demoDataset = &DatasetRecord{
	DatasetID:   "dataset-456",
	Title:       "区块链交易数据集",
	Description: "包含以太坊主网2023年交易数据的综合数据集",
	Owner:       "0x742d35Cc6634C0532925a3b8D3AC92F3B1a3C",
	DataHash:    "QmX7VmP8K9Z1N2M3B4A5C6D7E8F9G0H1I2J3K4L5M6N7O8P9Q",
	CreatedAt:   time.Now(),
}

func main() {
	r := gin.Default()

	// 健康检查
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "ok",
			"service": "desci-backend",
			"time":    time.Now(),
		})
	})

	// API路由组
	api := r.Group("/api/v1")
	{
		api.GET("/research/:tokenId", getResearch)
		api.GET("/dataset/:datasetId", getDataset)
		api.POST("/verify/research/:tokenId", verifyResearch)
	}

	log.Println("🚀 Server starting on :8080")
	log.Println("📋 Demo Research Token ID: demo-token-123")
	log.Println("📋 Demo Dataset ID: dataset-456")
	log.Println("🌐 Try: curl http://localhost:8080/health")
	log.Println("🌐 Try: curl http://localhost:8080/api/v1/research/demo-token-123")
	log.Println("🌐 Try: curl http://localhost:8080/api/v1/dataset/dataset-456")

	r.Run(":8080")
}

func getResearch(c *gin.Context) {
	tokenID := c.Param("tokenId")
	
	log.Printf("📖 Getting research data for token: %s", tokenID)
	
	if tokenID == "demo-token-123" {
		c.JSON(http.StatusOK, demoResearch)
	} else {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Research not found",
			"tokenId": tokenID,
		})
	}
}

func getDataset(c *gin.Context) {
	datasetID := c.Param("datasetId")
	
	log.Printf("📊 Getting dataset for ID: %s", datasetID)
	
	if datasetID == "dataset-456" {
		c.JSON(http.StatusOK, demoDataset)
	} else {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Dataset not found",
			"datasetId": datasetID,
		})
	}
}

func verifyResearch(c *gin.Context) {
	tokenID := c.Param("tokenId")
	
	var req struct {
		RawContent string `json:"rawContent" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": err.Error(),
		})
		return
	}

	log.Printf("🔍 Verifying research content for token: %s", tokenID)
	
	// 简单的模拟验证逻辑
	isValid := tokenID == "demo-token-123" && len(req.RawContent) > 0
	
	c.JSON(http.StatusOK, gin.H{
		"tokenId": tokenID,
		"isValid": isValid,
		"message": "Demo verification completed",
	})
}