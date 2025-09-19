package config

import (
	"os"
	"strconv"
)

type Config struct {
	// 服务器配置
	Port string

	// 区块链配置
	EthereumRPC    string
	StartBlock     uint64
	PrivateKey     string

	// 数据库配置
	DatabaseURL string

	// 合约地址
	DeSciRegistryAddress    string
	ResearchNFTAddress      string
	DatasetManagerAddress   string
	InfluenceRankingAddress string
	DeSciPlatformAddress    string
}

func Load() *Config {
	return &Config{
		Port:        getEnv("PORT", "8080"),
		EthereumRPC: getEnv("ETHEREUM_RPC", "http://localhost:8545"),
		StartBlock:  getEnvUint64("START_BLOCK", 0),
		PrivateKey:  getEnv("PRIVATE_KEY", ""),

		DatabaseURL: getEnv("DATABASE_URL", "sqlite://desci.db"),

		DeSciRegistryAddress:    getEnv("DESCI_REGISTRY_ADDRESS", ""),
		ResearchNFTAddress:      getEnv("RESEARCH_NFT_ADDRESS", ""),
		DatasetManagerAddress:   getEnv("DATASET_MANAGER_ADDRESS", ""),
		InfluenceRankingAddress: getEnv("INFLUENCE_RANKING_ADDRESS", ""),
		DeSciPlatformAddress:    getEnv("DESCI_PLATFORM_ADDRESS", ""),
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvUint64(key string, defaultValue uint64) uint64 {
	if value := os.Getenv(key); value != "" {
		if parsed, err := strconv.ParseUint(value, 10, 64); err == nil {
			return parsed
		}
	}
	return defaultValue
}
