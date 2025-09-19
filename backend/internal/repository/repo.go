package repository

import (
	"context"
	"strings"
	"time"

	"gorm.io/driver/postgres"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"desci-backend/internal/model"
)

// IRepository 定义标准的repository接口
type IRepository interface {
	// 事务支持
	WithTx(ctx context.Context, fn func(tx IRepository) error) error
	
	// Research data operations
	InsertResearchData(data *model.ResearchData) error
	GetResearchData(tokenID string) (*model.ResearchData, error)
	ListResearchDataByAuthor(author string, limit int) ([]*model.ResearchData, error)
	UpdateResearchData(tokenID string, updates map[string]interface{}) error
	
	// Dataset operations
	InsertDatasetRecord(record *model.DatasetRecord) error
	GetDatasetRecord(datasetID string) (*model.DatasetRecord, error)
	ListDatasetsByOwner(owner string, limit int) ([]*model.DatasetRecord, error)
	UpdateDatasetRecord(datasetID string, updates map[string]interface{}) error
	
	// Extended query operations
	GetLatestResearchData(limit, offset int) ([]*model.ResearchData, error)
	GetLastEventBlock() (uint64, error)
	
	// Event log operations
	InsertEventLog(log *model.EventLog) error
	GetUnprocessedEvents() ([]model.EventLog, error)
	MarkEventProcessed(eventID uint) error
	GetEventsByBlockRange(fromBlock, toBlock uint64) ([]model.EventLog, error)
	
	// Health check
	Ping(ctx context.Context) error
}

type Repository struct {
	db *gorm.DB
}

// 确保Repository实现了IRepository接口
var _ IRepository = (*Repository)(nil)

// NewTestRepository 创建测试用的Repository实例
func NewTestRepository(db *gorm.DB) *Repository {
	return &Repository{db: db}
}

func NewRepository(databaseURL string) (*Repository, error) {
	var dialector gorm.Dialector
	
	// 根据URL选择合适的数据库驱动
	if strings.HasPrefix(databaseURL, "sqlite://") || strings.HasPrefix(databaseURL, "sqlite:") {
		// SQLite
		dbPath := strings.TrimPrefix(databaseURL, "sqlite://")
		dbPath = strings.TrimPrefix(dbPath, "sqlite:")
		dialector = sqlite.Open(dbPath)
	} else {
		// PostgreSQL (默认)
		dialector = postgres.Open(databaseURL)
	}
	
	db, err := gorm.Open(dialector, &gorm.Config{})
	if err != nil {
		return nil, err
	}

	// 自动迁移
	if err := db.AutoMigrate(&model.ResearchData{}, &model.DatasetRecord{}, &model.EventLog{}); err != nil {
		return nil, err
	}

	return &Repository{db: db}, nil
}

// WithTx 执行事务操作
func (r *Repository) WithTx(ctx context.Context, fn func(tx IRepository) error) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		txRepo := &Repository{db: tx}
		return fn(txRepo)
	})
}

// 插入研究数据（幂等）
func (r *Repository) InsertResearchData(data *model.ResearchData) error {
	return r.db.FirstOrCreate(data, "token_id = ?", data.TokenID).Error
}

// 查询研究数据
func (r *Repository) GetResearchData(tokenID string) (*model.ResearchData, error) {
	var data model.ResearchData
	err := r.db.Where("token_id = ?", tokenID).First(&data).Error
	return &data, err
}

// 根据作者查询研究数据
func (r *Repository) ListResearchDataByAuthor(author string, limit int) ([]*model.ResearchData, error) {
	var data []*model.ResearchData
	// 使用LIKE查询兼容SQLite和PostgreSQL
	query := r.db.Where("authors LIKE ?", "%\""+author+"\"%")
	if limit > 0 {
		query = query.Limit(limit)
	}
	err := query.Find(&data).Error
	return data, err
}

// 更新研究数据
func (r *Repository) UpdateResearchData(tokenID string, updates map[string]interface{}) error {
	updates["updated_at"] = time.Now()
	return r.db.Model(&model.ResearchData{}).Where("token_id = ?", tokenID).Updates(updates).Error
}

// 插入数据集记录（幂等）
func (r *Repository) InsertDatasetRecord(record *model.DatasetRecord) error {
	return r.db.FirstOrCreate(record, "dataset_id = ?", record.DatasetID).Error
}

// 查询数据集记录
func (r *Repository) GetDatasetRecord(datasetID string) (*model.DatasetRecord, error) {
	var record model.DatasetRecord
	err := r.db.Where("dataset_id = ?", datasetID).First(&record).Error
	return &record, err
}

// 根据拥有者查询数据集
func (r *Repository) ListDatasetsByOwner(owner string, limit int) ([]*model.DatasetRecord, error) {
	var records []*model.DatasetRecord
	query := r.db.Where("owner = ?", owner)
	if limit > 0 {
		query = query.Limit(limit)
	}
	err := query.Find(&records).Error
	return records, err
}

// 更新数据集记录
func (r *Repository) UpdateDatasetRecord(datasetID string, updates map[string]interface{}) error {
	updates["updated_at"] = time.Now()
	return r.db.Model(&model.DatasetRecord{}).Where("dataset_id = ?", datasetID).Updates(updates).Error
}

// 插入事件日志（去重）
func (r *Repository) InsertEventLog(log *model.EventLog) error {
	// 使用复合键确保幂等性
	return r.db.FirstOrCreate(log, "tx_hash = ? AND log_index = ?", log.TxHash, log.LogIndex).Error
}

// 查询未处理的事件
func (r *Repository) GetUnprocessedEvents() ([]model.EventLog, error) {
	var events []model.EventLog
	err := r.db.Where("processed = ?", false).Order("block_number ASC").Find(&events).Error
	return events, err
}

// 标记事件为已处理
func (r *Repository) MarkEventProcessed(eventID uint) error {
	return r.db.Model(&model.EventLog{}).Where("id = ?", eventID).Update("processed", true).Error
}

// 按区块范围查询事件
func (r *Repository) GetEventsByBlockRange(fromBlock, toBlock uint64) ([]model.EventLog, error) {
	var events []model.EventLog
	err := r.db.Where("block_number >= ? AND block_number <= ?", fromBlock, toBlock).
		Order("block_number ASC, log_index ASC").Find(&events).Error
	return events, err
}

// 健康检查
func (r *Repository) Ping(ctx context.Context) error {
	db, err := r.db.DB()
	if err != nil {
		return err
	}
	return db.PingContext(ctx)
}

// 获取最新研究数据（按创建时间倒序）
func (r *Repository) GetLatestResearchData(limit, offset int) ([]*model.ResearchData, error) {
	var data []*model.ResearchData
	query := r.db.Order("created_at DESC")
	if limit > 0 {
		query = query.Limit(limit)
	}
	if offset > 0 {
		query = query.Offset(offset)
	}
	err := query.Find(&data).Error
	return data, err
}

// 获取最后的事件区块号
func (r *Repository) GetLastEventBlock() (uint64, error) {
	var result struct {
		BlockNumber uint64
	}
	err := r.db.Model(&model.EventLog{}).
		Select("MAX(block_number) as block_number").
		Scan(&result).Error
	if err != nil {
		return 0, err
	}
	return result.BlockNumber, nil
}


