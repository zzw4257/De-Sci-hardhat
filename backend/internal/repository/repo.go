package repository

import (
	"database/sql/driver"
	"encoding/json"
	"errors"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"your-project/internal/model"
)

type Repository struct {
	db *gorm.DB
}

func NewRepository(databaseURL string) (*Repository, error) {
	db, err := gorm.Open(postgres.Open(databaseURL), &gorm.Config{})
	if err != nil {
		return nil, err
	}

	// 自动迁移
	if err := db.AutoMigrate(&model.ResearchData{}, &model.DatasetRecord{}, &model.EventLog{}); err != nil {
		return nil, err
	}

	return &Repository{db: db}, nil
}

// 插入研究数据（幂等）
func (r *Repository) InsertResearchData(data *model.ResearchData) error {
	return r.db.FirstOrCreate(data, "token_id = ?", data.TokenID).Error
}

// 插入数据集记录（幂等）
func (r *Repository) InsertDatasetRecord(record *model.DatasetRecord) error {
	return r.db.FirstOrCreate(record, "dataset_id = ?", record.DatasetID).Error
}

// 插入事件日志（去重）
func (r *Repository) InsertEventLog(log *model.EventLog) error {
	// 使用复合键确保幂等性
	return r.db.FirstOrCreate(log, "tx_hash = ? AND log_index = ?", log.TxHash, log.LogIndex).Error
}

// 查询研究数据
func (r *Repository) GetResearchData(tokenID string) (*model.ResearchData, error) {
	var data model.ResearchData
	err := r.db.Where("token_id = ?", tokenID).First(&data).Error
	return &data, err
}

// 查询数据集记录
func (r *Repository) GetDatasetRecord(datasetID string) (*model.DatasetRecord, error) {
	var record model.DatasetRecord
	err := r.db.Where("dataset_id = ?", datasetID).First(&record).Error
	return &record, err
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

// StringArray 用于处理PostgreSQL数组类型
type StringArray []string

func (a StringArray) Value() (driver.Value, error) {
	return json.Marshal(a)
}

func (a *StringArray) Scan(value interface{}) error {
	if value == nil {
		*a = nil
		return nil
	}

	switch v := value.(type) {
	case []byte:
		return json.Unmarshal(v, a)
	case string:
		return json.Unmarshal([]byte(v), a)
	default:
		return errors.New("cannot scan into StringArray")
	}
}
