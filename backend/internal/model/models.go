package model

import (
	"database/sql/driver"
	"encoding/json"
	"errors"
	"time"
)

// ResearchData 研究数据表结构
type ResearchData struct {
	ID           uint      `json:"id" gorm:"primaryKey"`
	TokenID      string    `json:"token_id" gorm:"uniqueIndex;size:255"`
	Title        string    `json:"title"`
	Authors      StringArray  `json:"authors" gorm:"type:text[]"`
	ContentHash  string    `json:"content_hash"`
	MetadataHash string    `json:"metadata_hash"`
	BlockNumber  uint64    `json:"block_number" gorm:"default:0"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

// DatasetRecord 数据集记录表结构
type DatasetRecord struct {
	ID          uint      `json:"id" gorm:"primaryKey"`
	DatasetID   string    `json:"dataset_id" gorm:"uniqueIndex;size:255"`
	Title       string    `json:"title"`
	Description string    `json:"description"`
	Owner       string    `json:"owner" gorm:"index;size:255"`
	DataHash    string    `json:"data_hash"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// EventLog 事件日志表结构
type EventLog struct {
	ID           uint      `json:"id" gorm:"primaryKey"`
	TxHash       string    `json:"tx_hash" gorm:"index;size:255"`
	LogIndex     uint      `json:"log_index"`
	BlockNumber  uint64    `json:"block_number" gorm:"index"`
	EventName    string    `json:"event_name" gorm:"index;size:255"`
	ContractAddr string    `json:"contract_address"`
	PayloadRaw   string    `json:"payload_raw" gorm:"type:text"`
	Processed    bool      `json:"processed" gorm:"default:false"`
	CreatedAt    time.Time `json:"created_at"`
}

// ParsedEvent 解析后的事件结构（用于事件监听）
type ParsedEvent struct {
	TokenID     string `json:"token_id"`
	Author      string `json:"author"`
	DataHash    string `json:"data_hash"`
	Block       uint64 `json:"block"`
	TxHash      string `json:"tx_hash"`
	LogIndex    uint   `json:"log_index"`
	EventName   string `json:"event_name"`
	Title       string `json:"title,omitempty"`
	Description string `json:"description,omitempty"`
}

// 复合唯一索引: tx_hash + log_index
func (EventLog) TableName() string {
	return "event_logs"
}

// uint256 类型别名，用于处理大整数
type uint256 = string

// StringArray 自定义字符串数组类型，兼容SQLite和PostgreSQL
type StringArray []string

// Value 实现 driver.Valuer 接口
func (a StringArray) Value() (driver.Value, error) {
	if a == nil {
		return nil, nil
	}
	return json.Marshal(a)
}

// Scan 实现 sql.Scanner 接口
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
