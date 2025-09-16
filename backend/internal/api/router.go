package api

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"your-project/internal/service"
)

type Handler struct {
	service *service.Service
}

func NewHandler(service *service.Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) SetupRoutes() *gin.Engine {
	r := gin.Default()

	// 健康检查
	r.GET("/health", h.healthCheck)

	// API路由组
	api := r.Group("/api/v1")
	{
		api.GET("/research/:tokenId", h.getResearch)
		api.GET("/dataset/:datasetId", h.getDataset)
		api.POST("/verify/research/:tokenId", h.verifyResearch)
	}

	return r
}

// 健康检查
func (h *Handler) healthCheck(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status":  "ok",
		"service": "desci-backend",
	})
}

// 获取研究数据
func (h *Handler) getResearch(c *gin.Context) {
	tokenID := c.Param("tokenId")

	research, err := h.service.GetResearchByTokenID(tokenID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Research not found",
		})
		return
	}

	c.JSON(http.StatusOK, research)
}

// 获取数据集
func (h *Handler) getDataset(c *gin.Context) {
	datasetID := c.Param("datasetId")

	dataset, err := h.service.GetDatasetByID(datasetID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Dataset not found",
		})
		return
	}

	c.JSON(http.StatusOK, dataset)
}

// 验证研究内容
func (h *Handler) verifyResearch(c *gin.Context) {
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

	isValid, err := h.service.VerifyResearchContent(tokenID, req.RawContent)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to verify content",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"tokenId": tokenID,
		"isValid": isValid,
	})
}
