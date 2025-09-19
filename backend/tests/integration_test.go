package tests

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"desci-backend/internal/api"
	"desci-backend/internal/model"
	"desci-backend/internal/repository"
	"desci-backend/internal/service"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

// setupTestAPI 创建测试API环境
func setupTestAPI(t *testing.T) (*gin.Engine, repository.IRepository) {
	// 创建测试数据库
	gormDB, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	require.NoError(t, err)

	// 自动迁移所有模型
	err = gormDB.AutoMigrate(
		&model.ResearchData{}, 
		&model.DatasetRecord{}, 
		&model.EventLog{},
	)
	require.NoError(t, err)

	repo := repository.NewTestRepository(gormDB)
	svc := service.NewService(repo)

	// 创建API handler
	handler := api.NewHandler(svc)
	
	// 设置gin为测试模式
	gin.SetMode(gin.TestMode)
	router := handler.SetupRoutes()

	return router, repo
}

func TestHealthCheck(t *testing.T) {
	router, _ := setupTestAPI(t)

	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/health", nil)
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)

	var response map[string]interface{}
	err := json.Unmarshal(w.Body.Bytes(), &response)
	assert.NoError(t, err)
	assert.Equal(t, "ok", response["status"])
	assert.Equal(t, "desci-backend", response["service"])
}

func TestGetResearch_Success(t *testing.T) {
	router, repo := setupTestAPI(t)

	// 插入测试数据
	testData := &model.ResearchData{
		TokenID:      "123",
		Title:        "Test Research",
		Authors:      model.StringArray{"Alice", "Bob"},
		ContentHash:  "0xabcd1234",
		MetadataHash: "0xefgh5678",
	}
	err := repo.InsertResearchData(testData)
	require.NoError(t, err)

	// 测试API
	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/api/research/123", nil)
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)

	var response model.ResearchData
	err = json.Unmarshal(w.Body.Bytes(), &response)
	assert.NoError(t, err)
	assert.Equal(t, "Test Research", response.Title)
	assert.Equal(t, model.StringArray{"Alice", "Bob"}, response.Authors)
	assert.Equal(t, "0xabcd1234", response.ContentHash)
}

func TestGetResearch_NotFound(t *testing.T) {
	router, _ := setupTestAPI(t)

	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/api/research/nonexistent", nil)
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusNotFound, w.Code)

	var response map[string]interface{}
	err := json.Unmarshal(w.Body.Bytes(), &response)
	assert.NoError(t, err)
	assert.Equal(t, "Research not found", response["error"])
}

func TestGetDataset_Success(t *testing.T) {
	router, repo := setupTestAPI(t)

	// 插入测试数据
	testRecord := &model.DatasetRecord{
		DatasetID:   "dataset-456",
		Title:       "Test Dataset",
		Description: "A test dataset",
		Owner:       "0x1234567890abcdef",
		DataHash:    "QmTest123",
	}
	err := repo.InsertDatasetRecord(testRecord)
	require.NoError(t, err)

	// 测试API
	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/api/dataset/dataset-456", nil)
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)

	var response model.DatasetRecord
	err = json.Unmarshal(w.Body.Bytes(), &response)
	assert.NoError(t, err)
	assert.Equal(t, "Test Dataset", response.Title)
	assert.Equal(t, "A test dataset", response.Description)
	assert.Equal(t, "0x1234567890abcdef", response.Owner)
}

func TestGetDataset_NotFound(t *testing.T) {
	router, _ := setupTestAPI(t)

	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/api/dataset/nonexistent", nil)
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusNotFound, w.Code)

	var response map[string]interface{}
	err := json.Unmarshal(w.Body.Bytes(), &response)
	assert.NoError(t, err)
	assert.Equal(t, "Dataset not found", response["error"])
}

func TestVerifyResearch_Success(t *testing.T) {
	router, repo := setupTestAPI(t)

	// 准备测试数据
	contentHash := "0x19eb617fadfd0bd2627cbb32b5a95a96e076f58b6fd7592d5cdd92e63f6c18a9" // keccak256("test data for hashing")
	
	testData := &model.ResearchData{
		TokenID:     "verify-123",
		Title:       "Verify Test",
		Authors:     model.StringArray{"Test Author"},
		ContentHash: contentHash,
	}
	err := repo.InsertResearchData(testData)
	require.NoError(t, err)

	// 准备请求体
	requestBody := map[string]string{
		"rawContent": "test data for hashing", // 这个内容的keccak256哈希匹配上面的contentHash
	}
	jsonBody, _ := json.Marshal(requestBody)

	// 测试API
	w := httptest.NewRecorder()
	req, _ := http.NewRequest("POST", "/api/research/verify-123/verify", bytes.NewBuffer(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)

	var response map[string]interface{}
	err = json.Unmarshal(w.Body.Bytes(), &response)
	assert.NoError(t, err)
	assert.Equal(t, true, response["match"])
}

func TestVerifyResearch_InvalidHash(t *testing.T) {
	router, repo := setupTestAPI(t)

	// 准备测试数据
	testData := &model.ResearchData{
		TokenID:     "verify-456",
		Title:       "Verify Test",
		Authors:     model.StringArray{"Test Author"},
		ContentHash: "0xoriginal_hash",
	}
	err := repo.InsertResearchData(testData)
	require.NoError(t, err)

	// 准备请求体 - 不匹配的内容
	requestBody := map[string]string{
		"rawContent": "different content",
	}
	jsonBody, _ := json.Marshal(requestBody)

	// 测试API
	w := httptest.NewRecorder()
	req, _ := http.NewRequest("POST", "/api/research/verify-456/verify", bytes.NewBuffer(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)

	var response map[string]interface{}
	err = json.Unmarshal(w.Body.Bytes(), &response)
	assert.NoError(t, err)
	assert.Equal(t, false, response["match"])
}

func TestVerifyResearch_BadRequest(t *testing.T) {
	router, _ := setupTestAPI(t)

	// 测试无效JSON
	w := httptest.NewRecorder()
	req, _ := http.NewRequest("POST", "/api/research/123/verify", bytes.NewBuffer([]byte("invalid json")))
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusBadRequest, w.Code)
}

func TestVerifyResearch_MissingContent(t *testing.T) {
	router, _ := setupTestAPI(t)

	// 测试缺少rawContent字段
	requestBody := map[string]string{
		"wrongField": "some content",
	}
	jsonBody, _ := json.Marshal(requestBody)

	w := httptest.NewRecorder()
	req, _ := http.NewRequest("POST", "/api/research/123/verify", bytes.NewBuffer(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusBadRequest, w.Code)
}

func TestVerifyResearch_ResearchNotFound(t *testing.T) {
	router, _ := setupTestAPI(t)

	requestBody := map[string]string{
		"rawContent": "some content",
	}
	jsonBody, _ := json.Marshal(requestBody)

	w := httptest.NewRecorder()
	req, _ := http.NewRequest("POST", "/api/research/nonexistent/verify", bytes.NewBuffer(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusInternalServerError, w.Code)
}

func TestAPIEndpointsExist(t *testing.T) {
	router, repo := setupTestAPI(t)

	// 先插入测试数据确保路由能正确响应
	testData := &model.ResearchData{
		TokenID:      "123",
		Title:        "Test Research",
		Authors:      model.StringArray{"Test Author"},
		ContentHash:  "0xtest123",
		MetadataHash: "0xmeta123",
	}
	err := repo.InsertResearchData(testData)
	require.NoError(t, err)

	testDataset := &model.DatasetRecord{
		DatasetID:   "456",
		Title:       "Test Dataset", 
		Description: "Test Description",
		Owner:       "0xowner123",
		DataHash:    "QmTest456",
	}
	err = repo.InsertDatasetRecord(testDataset)
	require.NoError(t, err)

	// 测试所有定义的路由是否存在并正常工作
	routes := []struct {
		method       string
		path         string
		expectedCode int
	}{
		{"GET", "/health", http.StatusOK},
		{"GET", "/api/research/123", http.StatusOK},
		{"GET", "/api/dataset/456", http.StatusOK},
		{"POST", "/api/research/123/verify", http.StatusBadRequest}, // 没有body会返回400
	}

	for _, route := range routes {
		w := httptest.NewRecorder()
		req, _ := http.NewRequest(route.method, route.path, nil)
		router.ServeHTTP(w, req)

		// 确保路由存在并返回预期状态码
		assert.Equal(t, route.expectedCode, w.Code, 
			"Route %s %s should return %d but got %d", route.method, route.path, route.expectedCode, w.Code)
	}
}

// Benchmark测试
func BenchmarkHealthCheck(b *testing.B) {
	router, _ := setupTestAPI(&testing.T{})

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		w := httptest.NewRecorder()
		req, _ := http.NewRequest("GET", "/health", nil)
		router.ServeHTTP(w, req)
	}
}

func BenchmarkGetResearch(b *testing.B) {
	router, repo := setupTestAPI(&testing.T{})

	// 插入测试数据
	testData := &model.ResearchData{
		TokenID:     "bench-123",
		Title:       "Benchmark Test",
		Authors:     model.StringArray{"Bench Author"},
		ContentHash: "0xbenchmark",
	}
	repo.InsertResearchData(testData)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		w := httptest.NewRecorder()
		req, _ := http.NewRequest("GET", "/api/research/bench-123", nil)
		router.ServeHTTP(w, req)
	}
}

// 测试完整工作流程
func TestCompleteWorkflow(t *testing.T) {
	router, repo := setupTestAPI(t)

	ctx := context.Background()

	// 1. 插入研究数据
	testData := &model.ResearchData{
		TokenID:      "workflow-123",
		Title:        "Workflow Test Research",
		Authors:      model.StringArray{"Alice", "Bob"},
		ContentHash:  "0x19eb617fadfd0bd2627cbb32b5a95a96e076f58b6fd7592d5cdd92e63f6c18a9",
		MetadataHash: "0xworkflow",
	}
	err := repo.InsertResearchData(testData)
	require.NoError(t, err)

	// 2. 插入相关数据集
	datasetRecord := &model.DatasetRecord{
		DatasetID:   "workflow-dataset",
		Title:       "Related Dataset",
		Description: "Dataset for workflow test",
		Owner:       "0xworkflowowner",
		DataHash:    "QmWorkflow123",
	}
	err = repo.InsertDatasetRecord(datasetRecord)
	require.NoError(t, err)

	// 3. 插入事件日志
	eventLog := &model.EventLog{
		TxHash:       "0xworkflowtx",
		LogIndex:     0,
		BlockNumber:  999999,
		EventName:    "ResearchCreated",
		ContractAddr: "0xworkflowcontract",
		PayloadRaw:   `{"tokenId":"workflow-123","title":"Workflow Test Research"}`,
		Processed:    false,
	}
	err = repo.InsertEventLog(eventLog)
	require.NoError(t, err)

	// 4. 测试健康检查
	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/health", nil)
	router.ServeHTTP(w, req)
	assert.Equal(t, http.StatusOK, w.Code)

	// 5. 测试获取研究数据
	w = httptest.NewRecorder()
	req, _ = http.NewRequest("GET", "/api/research/workflow-123", nil)
	router.ServeHTTP(w, req)
	assert.Equal(t, http.StatusOK, w.Code)

	// 6. 测试获取数据集
	w = httptest.NewRecorder()
	req, _ = http.NewRequest("GET", "/api/dataset/workflow-dataset", nil)
	router.ServeHTTP(w, req)
	assert.Equal(t, http.StatusOK, w.Code)

	// 7. 测试验证功能
	requestBody := map[string]string{
		"rawContent": "test data for hashing",
	}
	jsonBody, _ := json.Marshal(requestBody)

	w = httptest.NewRecorder()
	req, _ = http.NewRequest("POST", "/api/research/workflow-123/verify", bytes.NewBuffer(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(w, req)
	assert.Equal(t, http.StatusOK, w.Code)

	var verifyResponse map[string]interface{}
	err = json.Unmarshal(w.Body.Bytes(), &verifyResponse)
	assert.NoError(t, err)
	assert.Equal(t, true, verifyResponse["match"])

	// 8. 测试数据库操作
	err = repo.Ping(ctx)
	assert.NoError(t, err)

	// 9. 获取未处理事件
	events, err := repo.GetUnprocessedEvents()
	assert.NoError(t, err)
	assert.Len(t, events, 1)
	assert.Equal(t, "ResearchCreated", events[0].EventName)

	// 10. 标记事件为已处理
	err = repo.MarkEventProcessed(events[0].ID)
	assert.NoError(t, err)

	// 11. 验证事件已处理
	unprocessedEvents, err := repo.GetUnprocessedEvents()
	assert.NoError(t, err)
	assert.Len(t, unprocessedEvents, 0)
} 