package service

import (
	"encoding/json"
	"log"

	"desci-backend/internal/model"
	"desci-backend/internal/repository"
	"desci-backend/internal/verify"
)

type Service struct {
	repo repository.IRepository
}

func NewService(repo repository.IRepository) *Service {
	return &Service{repo: repo}
}

// ProcessEvent 处理区块链事件
func (s *Service) ProcessEvent(eventLog *model.EventLog) error {
	// 解析事件数据
	switch eventLog.EventName {
	case "ResearchCreated":
		return s.processResearchCreated(eventLog)
	case "DatasetCreated":
		return s.processDatasetCreated(eventLog)
	default:
		log.Printf("Unknown event type: %s", eventLog.EventName)
	}

	return nil
}

// 处理研究创建事件
func (s *Service) processResearchCreated(eventLog *model.EventLog) error {
	var eventData struct {
		TokenID      string   `json:"tokenId"`
		Authors      []string `json:"authors"`
		Title        string   `json:"title"`
		ContentHash  string   `json:"contentHash"`
		MetadataHash string   `json:"metadataHash"`
	}

	if err := json.Unmarshal([]byte(eventLog.PayloadRaw), &eventData); err != nil {
		log.Printf("Failed to parse research created event: %v", err)
		return err
	}

	researchData := &model.ResearchData{
		TokenID:      eventData.TokenID,
		Title:        eventData.Title,
		Authors:      eventData.Authors,
		ContentHash:  eventData.ContentHash,
		MetadataHash: eventData.MetadataHash,
	}

	return s.repo.InsertResearchData(researchData)
}

// 处理数据集创建事件
func (s *Service) processDatasetCreated(eventLog *model.EventLog) error {
	var eventData struct {
		DatasetID   string `json:"datasetId"`
		Title       string `json:"title"`
		Description string `json:"description"`
		Owner       string `json:"owner"`
		IPFSHash    string `json:"ipfsHash"`
	}

	if err := json.Unmarshal([]byte(eventLog.PayloadRaw), &eventData); err != nil {
		log.Printf("Failed to parse dataset created event: %v", err)
		return err
	}

	datasetRecord := &model.DatasetRecord{
		DatasetID:   eventData.DatasetID,
		Title:       eventData.Title,
		Description: eventData.Description,
		Owner:       eventData.Owner,
		DataHash:    eventData.IPFSHash,
	}

	return s.repo.InsertDatasetRecord(datasetRecord)
}

// VerifyResearchContent 验证研究内容哈希
func (s *Service) VerifyResearchContent(tokenID string, rawContent string) (bool, error) {
	research, err := s.repo.GetResearchData(tokenID)
	if err != nil {
		return false, err
	}

	return verify.VerifyHashMatch(rawContent, research.ContentHash), nil
}

// GetResearchByTokenID 根据TokenID获取研究数据
func (s *Service) GetResearchByTokenID(tokenID string) (*model.ResearchData, error) {
	return s.repo.GetResearchData(tokenID)
}

// GetDatasetByID 根据ID获取数据集
func (s *Service) GetDatasetByID(datasetID string) (*model.DatasetRecord, error) {
	return s.repo.GetDatasetRecord(datasetID)
}

// GetLatestResearch 获取最新研究列表
func (s *Service) GetLatestResearch(limit, offset int) ([]*model.ResearchData, error) {
	if limit <= 0 {
		limit = 20 // 默认限制
	}
	// 使用repository的方法，按创建时间倒序
	return s.repo.GetLatestResearchData(limit, offset)
}

// GetResearchByAuthor 按作者获取研究列表
func (s *Service) GetResearchByAuthor(author string, limit int) ([]*model.ResearchData, error) {
	if limit <= 0 {
		limit = 20 // 默认限制
	}
	return s.repo.ListResearchDataByAuthor(author, limit)
}

// GetLastEventBlock 获取最后的事件区块号
func (s *Service) GetLastEventBlock() (uint64, error) {
	return s.repo.GetLastEventBlock()
}
