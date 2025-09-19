package repository

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"desci-backend/internal/model"
)

// setupTestDB 创建测试数据库
func setupTestDB(t *testing.T) *Repository {
	gormDB, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	require.NoError(t, err)

	// 自动迁移所有模型
	err = gormDB.AutoMigrate(
		&model.ResearchData{}, 
		&model.DatasetRecord{}, 
		&model.EventLog{},
	)
	require.NoError(t, err)

	return NewTestRepository(gormDB)
}

func TestRepository_InsertResearchData(t *testing.T) {
	repo := setupTestDB(t)

	testData := &model.ResearchData{
		TokenID:      "123",
		Title:        "Test Research",
		Authors:      model.StringArray{"Alice", "Bob"},
		ContentHash:  "0xabcd1234",
		MetadataHash: "0xefgh5678",
	}

	// 测试插入
	err := repo.InsertResearchData(testData)
	assert.NoError(t, err)

	// 测试幂等性 - 重复插入相同TokenID
	err = repo.InsertResearchData(testData)
	assert.NoError(t, err)

	// 验证数据
	retrieved, err := repo.GetResearchData("123")
	assert.NoError(t, err)
	assert.Equal(t, "Test Research", retrieved.Title)
	assert.Equal(t, model.StringArray{"Alice", "Bob"}, retrieved.Authors)
	assert.Equal(t, "0xabcd1234", retrieved.ContentHash)
}

func TestRepository_GetResearchData_NotFound(t *testing.T) {
	repo := setupTestDB(t)

	_, err := repo.GetResearchData("nonexistent")
	assert.Error(t, err)
	assert.Equal(t, gorm.ErrRecordNotFound, err)
}

func TestRepository_ListResearchDataByAuthor(t *testing.T) {
	repo := setupTestDB(t)

	// 插入测试数据
	testData1 := &model.ResearchData{
		TokenID:     "token1",
		Title:       "Research 1",
		Authors:     model.StringArray{"Alice", "Bob"},
		ContentHash: "0xhash1",
	}
	testData2 := &model.ResearchData{
		TokenID:     "token2", 
		Title:       "Research 2",
		Authors:     model.StringArray{"Alice", "Charlie"},
		ContentHash: "0xhash2",
	}

	err := repo.InsertResearchData(testData1)
	require.NoError(t, err)
	err = repo.InsertResearchData(testData2)
	require.NoError(t, err)

	// 查询Alice的研究
	results, err := repo.ListResearchDataByAuthor("Alice", 10)
	assert.NoError(t, err)
	assert.Len(t, results, 2)
}

func TestRepository_UpdateResearchData(t *testing.T) {
	repo := setupTestDB(t)

	// 插入初始数据
	testData := &model.ResearchData{
		TokenID:     "update-test",
		Title:       "Original Title",
		ContentHash: "0xoriginal",
	}
	err := repo.InsertResearchData(testData)
	require.NoError(t, err)

	// 更新数据
	updates := map[string]interface{}{
		"title": "Updated Title",
	}
	err = repo.UpdateResearchData("update-test", updates)
	assert.NoError(t, err)

	// 验证更新
	updated, err := repo.GetResearchData("update-test")
	assert.NoError(t, err)
	assert.Equal(t, "Updated Title", updated.Title)
}

func TestRepository_InsertDatasetRecord(t *testing.T) {
	repo := setupTestDB(t)

	testRecord := &model.DatasetRecord{
		DatasetID:   "dataset-456",
		Title:       "Test Dataset",
		Description: "A test dataset",
		Owner:       "0x1234567890abcdef",
		DataHash:    "QmTest123",
	}

	// 测试插入
	err := repo.InsertDatasetRecord(testRecord)
	assert.NoError(t, err)

	// 测试幂等性
	err = repo.InsertDatasetRecord(testRecord)
	assert.NoError(t, err)

	// 验证数据
	retrieved, err := repo.GetDatasetRecord("dataset-456")
	assert.NoError(t, err)
	assert.Equal(t, "Test Dataset", retrieved.Title)
	assert.Equal(t, "A test dataset", retrieved.Description)
	assert.Equal(t, "0x1234567890abcdef", retrieved.Owner)
}

func TestRepository_GetDatasetRecord_NotFound(t *testing.T) {
	repo := setupTestDB(t)

	_, err := repo.GetDatasetRecord("nonexistent")
	assert.Error(t, err)
	assert.Equal(t, gorm.ErrRecordNotFound, err)
}

func TestRepository_ListDatasetsByOwner(t *testing.T) {
	repo := setupTestDB(t)

	owner := "0x1234567890abcdef"
	
	// 插入测试数据
	dataset1 := &model.DatasetRecord{
		DatasetID: "dataset1",
		Title:     "Dataset 1",
		Owner:     owner,
		DataHash:  "QmHash1",
	}
	dataset2 := &model.DatasetRecord{
		DatasetID: "dataset2",
		Title:     "Dataset 2", 
		Owner:     owner,
		DataHash:  "QmHash2",
	}

	err := repo.InsertDatasetRecord(dataset1)
	require.NoError(t, err)
	err = repo.InsertDatasetRecord(dataset2)
	require.NoError(t, err)

	// 查询owner的数据集
	results, err := repo.ListDatasetsByOwner(owner, 10)
	assert.NoError(t, err)
	assert.Len(t, results, 2)
}

func TestRepository_InsertEventLog(t *testing.T) {
	repo := setupTestDB(t)

	testLog := &model.EventLog{
		TxHash:       "0xtxhash123",
		LogIndex:     0,
		BlockNumber:  12345,
		EventName:    "ResearchCreated",
		ContractAddr: "0xcontract123",
		PayloadRaw:   `{"tokenId":"123","title":"Test"}`,
		Processed:    false,
	}

	// 测试插入
	err := repo.InsertEventLog(testLog)
	assert.NoError(t, err)

	// 测试去重 - 相同tx_hash和log_index
	err = repo.InsertEventLog(testLog)
	assert.NoError(t, err)

	// 验证只有一条记录
	var count int64
	err = repo.db.Raw("SELECT COUNT(*) FROM event_logs WHERE tx_hash = ? AND log_index = ?", 
		"0xtxhash123", 0).Scan(&count).Error
	assert.NoError(t, err)
	assert.Equal(t, int64(1), count)
}

func TestRepository_GetUnprocessedEvents(t *testing.T) {
	repo := setupTestDB(t)

	// 插入测试事件
	events := []*model.EventLog{
		{
			TxHash:      "0xtx1",
			LogIndex:    0,
			BlockNumber: 100,
			EventName:   "Event1",
			Processed:   false,
		},
		{
			TxHash:      "0xtx2",
			LogIndex:    0,
			BlockNumber: 200,
			EventName:   "Event2",
			Processed:   true,
		},
		{
			TxHash:      "0xtx3",
			LogIndex:    0,
			BlockNumber: 150,
			EventName:   "Event3",
			Processed:   false,
		},
	}

	for _, event := range events {
		err := repo.InsertEventLog(event)
		require.NoError(t, err)
	}

	// 获取未处理事件
	unprocessed, err := repo.GetUnprocessedEvents()
	assert.NoError(t, err)
	assert.Len(t, unprocessed, 2)

	// 验证按block_number排序
	assert.Equal(t, uint64(100), unprocessed[0].BlockNumber)
	assert.Equal(t, uint64(150), unprocessed[1].BlockNumber)
}

func TestRepository_MarkEventProcessed(t *testing.T) {
	repo := setupTestDB(t)

	testLog := &model.EventLog{
		TxHash:      "0xtxhash",
		LogIndex:    0,
		BlockNumber: 12345,
		EventName:   "TestEvent",
		Processed:   false,
	}

	// 插入事件
	err := repo.InsertEventLog(testLog)
	require.NoError(t, err)

	// 获取插入的事件ID
	var inserted model.EventLog
	err = repo.db.Where("tx_hash = ? AND log_index = ?", "0xtxhash", 0).First(&inserted).Error
	require.NoError(t, err)

	// 标记为已处理
	err = repo.MarkEventProcessed(inserted.ID)
	assert.NoError(t, err)

	// 验证状态更新
	var updated model.EventLog
	err = repo.db.First(&updated, inserted.ID).Error
	require.NoError(t, err)
	assert.True(t, updated.Processed)
}

func TestRepository_GetEventsByBlockRange(t *testing.T) {
	repo := setupTestDB(t)

	// 插入不同区块的事件
	events := []*model.EventLog{
		{TxHash: "0xtx1", LogIndex: 0, BlockNumber: 100, EventName: "Event1"},
		{TxHash: "0xtx2", LogIndex: 0, BlockNumber: 150, EventName: "Event2"},
		{TxHash: "0xtx3", LogIndex: 0, BlockNumber: 200, EventName: "Event3"},
		{TxHash: "0xtx4", LogIndex: 0, BlockNumber: 250, EventName: "Event4"},
	}

	for _, event := range events {
		err := repo.InsertEventLog(event)
		require.NoError(t, err)
	}

	// 查询区块范围 120-180
	results, err := repo.GetEventsByBlockRange(120, 180)
	assert.NoError(t, err)
	assert.Len(t, results, 1)
	assert.Equal(t, uint64(150), results[0].BlockNumber)
}

func TestRepository_WithTx(t *testing.T) {
	repo := setupTestDB(t)

	// 测试事务成功提交
	err := repo.WithTx(context.Background(), func(tx IRepository) error {
		testData := &model.ResearchData{
			TokenID:     "tx-test-1",
			Title:       "Transaction Test 1",
			ContentHash: "0xtx1",
		}
		return tx.InsertResearchData(testData)
	})
	assert.NoError(t, err)

	// 验证数据已提交
	_, err = repo.GetResearchData("tx-test-1")
	assert.NoError(t, err)

	// 测试事务回滚
	err = repo.WithTx(context.Background(), func(tx IRepository) error {
		testData := &model.ResearchData{
			TokenID:     "tx-test-2",
			Title:       "Transaction Test 2",
			ContentHash: "0xtx2",
		}
		if err := tx.InsertResearchData(testData); err != nil {
			return err
		}
		// 强制返回错误触发回滚
		return assert.AnError
	})
	assert.Error(t, err)

	// 验证数据未提交
	_, err = repo.GetResearchData("tx-test-2")
	assert.Error(t, err)
}

func TestRepository_Ping(t *testing.T) {
	repo := setupTestDB(t)

	err := repo.Ping(context.Background())
	assert.NoError(t, err)
}

func TestRepository_ConcurrentInsert(t *testing.T) {
	repo := setupTestDB(t)

	// 先插入一条记录测试幂等性
	testData := &model.ResearchData{
		TokenID:     "concurrent-test",
		Title:       "Concurrent Test",
		Authors:     model.StringArray{"Test Author"},
		ContentHash: "0xconcurrent",
	}

	// 第一次插入
	err := repo.InsertResearchData(testData)
	assert.NoError(t, err)

	// 第二次插入同样的数据（测试幂等性）
	err = repo.InsertResearchData(testData)
	assert.NoError(t, err)

	// 验证只有一条记录
	var count int64
	repo.db.Model(&model.ResearchData{}).Where("token_id = ?", "concurrent-test").Count(&count)
	assert.Equal(t, int64(1), count)
	
	// 验证可以读取数据
	retrieved, err := repo.GetResearchData("concurrent-test")
	assert.NoError(t, err)
	assert.Equal(t, "Concurrent Test", retrieved.Title)
}

// Benchmark测试
func BenchmarkRepository_InsertResearchData(b *testing.B) {
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		b.Fatal(err)
	}

	db.AutoMigrate(&model.ResearchData{})
	repo := NewTestRepository(db)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		testData := &model.ResearchData{
			TokenID:     "bench-" + string(rune(i)),
			Title:       "Benchmark Test",
			Authors:     model.StringArray{"Benchmark Author"},
			ContentHash: "0xbenchmark",
		}
		repo.InsertResearchData(testData)
	}
}
