package main

import (
	"log"
	"net/http"
	"os"

	"github.com/gin-gonic/gin"
)

func main() {
	// 获取端口
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// 创建Gin路由
	r := gin.Default()

	// 健康检查
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "ok",
			"service": "desci-backend",
			"message": "Backend service is running",
		})
	})

	// API路由组
	api := r.Group("/api/v1")
	{
		api.GET("/research/:tokenId", func(c *gin.Context) {
			tokenId := c.Param("tokenId")
			c.JSON(http.StatusOK, gin.H{
				"token_id": tokenId,
				"title":    "Mock Research Title",
				"message":  "This is a mock response - database not connected yet",
			})
		})

		api.GET("/dataset/:datasetId", func(c *gin.Context) {
			datasetId := c.Param("datasetId")
			c.JSON(http.StatusOK, gin.H{
				"dataset_id": datasetId,
				"title":      "Mock Dataset Title",
				"message":    "This is a mock response - database not connected yet",
			})
		})

		api.POST("/verify/research/:tokenId", func(c *gin.Context) {
			tokenId := c.Param("tokenId")
			c.JSON(http.StatusOK, gin.H{
				"token_id": tokenId,
				"verified": true,
				"message":  "Mock verification - always returns true",
			})
		})
	}

	log.Printf("DeSci Backend starting on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, r))
}