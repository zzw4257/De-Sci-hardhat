package verify

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestCalculateKeccak256(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{
			name:     "empty string",
			input:    "",
			expected: "0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470",
		},
		{
			name:     "hello world",
			input:    "hello world",
			expected: "0x47173285a8d7341e5e972fc677286384f802f8ef42a5ec5f03bbfa254cb01fad",
		},
		{
			name:     "test data",
			input:    "test data for hashing",
			expected: "0x19eb617fadfd0bd2627cbb32b5a95a96e076f58b6fd7592d5cdd92e63f6c18a9",
		},
		{
			name:     "numeric string",
			input:    "123456789",
			expected: "0x2a359feeb8e488a1af2c03b908b3ed7990400555db73e1421181d97cac004d48",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := CalculateKeccak256(tt.input)
			assert.Equal(t, tt.expected, result)
		})
	}
}

func TestCalculateSHA256(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{
			name:     "empty string",
			input:    "",
			expected: "0xe3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
		},
		{
			name:     "hello world",
			input:    "hello world",
			expected: "0xb94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9",
		},
		{
			name:     "test data",
			input:    "test data for hashing",
			expected: "0xf7eb7961d8a233e6256d3a6257548bbb9293c3a08fb3574c88c7d6b429dbb9f5",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := CalculateSHA256(tt.input)
			assert.Equal(t, tt.expected, result)
		})
	}
}

func TestVerifyHashMatch(t *testing.T) {
	testData := "test content for verification"
	correctHash := CalculateKeccak256(testData)
	incorrectHash := "0x1234567890abcdef"

	tests := []struct {
		name        string
		rawContent  string
		chainHash   string
		expectMatch bool
	}{
		{
			name:        "matching hash",
			rawContent:  testData,
			chainHash:   correctHash,
			expectMatch: true,
		},
		{
			name:        "non-matching hash",
			rawContent:  testData,
			chainHash:   incorrectHash,
			expectMatch: false,
		},
		{
			name:        "empty content with correct hash",
			rawContent:  "",
			chainHash:   CalculateKeccak256(""),
			expectMatch: true,
		},
		{
			name:        "different content",
			rawContent:  "different content",
			chainHash:   correctHash,
			expectMatch: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := VerifyHashMatch(tt.rawContent, tt.chainHash)
			assert.Equal(t, tt.expectMatch, result)
		})
	}
}

func TestVerifyDataIntegrity(t *testing.T) {
	testData := "integrity test data"
	expectedHash := CalculateKeccak256(testData)

	tests := []struct {
		name         string
		rawData      string
		expectedHash string
		expectMatch  bool
	}{
		{
			name:         "valid data integrity",
			rawData:      testData,
			expectedHash: expectedHash,
			expectMatch:  true,
		},
		{
			name:         "invalid data integrity",
			rawData:      "tampered data",
			expectedHash: expectedHash,
			expectMatch:  false,
		},
		{
			name:         "empty data",
			rawData:      "",
			expectedHash: CalculateKeccak256(""),
			expectMatch:  true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			isMatch, calculatedHash := VerifyDataIntegrity(tt.rawData, tt.expectedHash)
			assert.Equal(t, tt.expectMatch, isMatch)
			assert.Equal(t, CalculateKeccak256(tt.rawData), calculatedHash)
		})
	}
}

func TestHashConsistency(t *testing.T) {
	// 测试相同输入产生相同哈希
	testData := "consistency test"
	
	hash1 := CalculateKeccak256(testData)
	hash2 := CalculateKeccak256(testData)
	
	assert.Equal(t, hash1, hash2, "Same input should produce same hash")
}

func TestHashUniqueness(t *testing.T) {
	// 测试不同输入产生不同哈希
	data1 := "test data 1"
	data2 := "test data 2"
	
	hash1 := CalculateKeccak256(data1)
	hash2 := CalculateKeccak256(data2)
	
	assert.NotEqual(t, hash1, hash2, "Different inputs should produce different hashes")
}

func TestHashFormat(t *testing.T) {
	// 测试哈希格式正确性
	testData := "format test"
	
	keccakHash := CalculateKeccak256(testData)
	sha256Hash := CalculateSHA256(testData)
	
	// 检查是否以0x开头
	assert.True(t, len(keccakHash) > 2 && keccakHash[:2] == "0x", "Keccak256 hash should start with 0x")
	assert.True(t, len(sha256Hash) > 2 && sha256Hash[:2] == "0x", "SHA256 hash should start with 0x")
	
	// 检查长度 (0x + 64个十六进制字符)
	assert.Equal(t, 66, len(keccakHash), "Keccak256 hash should be 66 characters long")
	assert.Equal(t, 66, len(sha256Hash), "SHA256 hash should be 66 characters long")
}

func TestLargeDataHashing(t *testing.T) {
	// 测试大数据哈希
	largeData := make([]byte, 1024*1024) // 1MB数据
	for i := range largeData {
		largeData[i] = byte(i % 256)
	}
	
	hash := CalculateKeccak256(string(largeData))
	assert.NotEmpty(t, hash)
	assert.True(t, len(hash) == 66, "Large data hash should have correct length")
}

// Benchmark测试
func BenchmarkCalculateKeccak256(b *testing.B) {
	testData := "benchmark test data for keccak256 hashing performance"
	
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		CalculateKeccak256(testData)
	}
}

func BenchmarkCalculateSHA256(b *testing.B) {
	testData := "benchmark test data for sha256 hashing performance"
	
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		CalculateSHA256(testData)
	}
}

func BenchmarkVerifyHashMatch(b *testing.B) {
	testData := "benchmark test data for hash verification"
	hash := CalculateKeccak256(testData)
	
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		VerifyHashMatch(testData, hash)
	}
}
