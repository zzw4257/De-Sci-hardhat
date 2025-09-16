package verify

import (
	"crypto/sha256"
	"encoding/hex"
	"golang.org/x/crypto/sha3"
)

// VerifyHashMatch 验证本地计算的哈希与链上哈希是否匹配
func VerifyHashMatch(rawContent string, chainHash string) bool {
	localHash := CalculateKeccak256(rawContent)
	return localHash == chainHash
}

// CalculateKeccak256 计算keccak256哈希
func CalculateKeccak256(data string) string {
	hash := sha3.NewLegacyKeccak256()
	hash.Write([]byte(data))
	return "0x" + hex.EncodeToString(hash.Sum(nil))
}

// CalculateSHA256 计算SHA256哈希（备用）
func CalculateSHA256(data string) string {
	hash := sha256.Sum256([]byte(data))
	return "0x" + hex.EncodeToString(hash[:])
}

// VerifyDataIntegrity 验证数据完整性
func VerifyDataIntegrity(rawData, expectedHash string) (bool, string) {
	calculatedHash := CalculateKeccak256(rawData)
	isMatch := calculatedHash == expectedHash
	return isMatch, calculatedHash
}
