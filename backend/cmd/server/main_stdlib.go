package main

import (
	"encoding/json"
	"log"
	"net/http"
	"strings"
	"time"
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
	// 设置路由
	http.HandleFunc("/health", healthHandler)
	http.HandleFunc("/api/v1/research/", researchHandler)
	http.HandleFunc("/api/v1/dataset/", datasetHandler)
	http.HandleFunc("/api/v1/verify/research/", verifyHandler)

	log.Println("🚀 Server starting on :8081")
	log.Println("📋 Demo Research Token ID: demo-token-123")
	log.Println("📋 Demo Dataset ID: dataset-456")
	log.Println("🌐 Try: curl http://localhost:8081/health")
	log.Println("🌐 Try: curl http://localhost:8081/api/v1/research/demo-token-123")
	log.Println("🌐 Try: curl http://localhost:8081/api/v1/dataset/dataset-456")

	if err := http.ListenAndServe(":8081", nil); err != nil {
		log.Fatalf("❌ Server failed to start: %v", err)
	}
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	
	response := map[string]interface{}{
		"status":  "ok",
		"service": "desci-backend",
		"time":    time.Now(),
	}
	
	json.NewEncoder(w).Encode(response)
}

func researchHandler(w http.ResponseWriter, r *http.Request) {
	// 提取tokenId
	path := strings.TrimPrefix(r.URL.Path, "/api/v1/research/")
	tokenID := strings.TrimSuffix(path, "/")
	
	log.Printf("📖 Getting research data for token: %s", tokenID)
	
	w.Header().Set("Content-Type", "application/json")
	
	if tokenID == "demo-token-123" {
		json.NewEncoder(w).Encode(demoResearch)
	} else {
		w.WriteHeader(http.StatusNotFound)
		response := map[string]interface{}{
			"error": "Research not found",
			"tokenId": tokenID,
		}
		json.NewEncoder(w).Encode(response)
	}
}

func datasetHandler(w http.ResponseWriter, r *http.Request) {
	// 提取datasetId
	path := strings.TrimPrefix(r.URL.Path, "/api/v1/dataset/")
	datasetID := strings.TrimSuffix(path, "/")
	
	log.Printf("📊 Getting dataset for ID: %s", datasetID)
	
	w.Header().Set("Content-Type", "application/json")
	
	if datasetID == "dataset-456" {
		json.NewEncoder(w).Encode(demoDataset)
	} else {
		w.WriteHeader(http.StatusNotFound)
		response := map[string]interface{}{
			"error": "Dataset not found",
			"datasetId": datasetID,
		}
		json.NewEncoder(w).Encode(response)
	}
}

func verifyHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}
	
	// 提取tokenId
	path := strings.TrimPrefix(r.URL.Path, "/api/v1/verify/research/")
	tokenID := strings.TrimSuffix(path, "/")
	
	var req struct {
		RawContent string `json:"rawContent"`
	}
	
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		response := map[string]interface{}{
			"error": err.Error(),
		}
		json.NewEncoder(w).Encode(response)
		return
	}
	
	log.Printf("🔍 Verifying research content for token: %s", tokenID)
	
	// 简单的模拟验证逻辑
	isValid := tokenID == "demo-token-123" && len(req.RawContent) > 0
	
	w.Header().Set("Content-Type", "application/json")
	response := map[string]interface{}{
		"tokenId": tokenID,
		"isValid": isValid,
		"message": "Demo verification completed",
	}
	json.NewEncoder(w).Encode(response)
}