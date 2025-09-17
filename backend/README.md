# DeSci 后端服务

基于Go的区块链事件监听和API服务，负责处理去中心化科研平台的后端逻辑。

## 🏗️ 项目架构

按照任务分工文档，项目采用清晰的模块化架构：

### 📁 目录结构
```
backend/
├── cmd/server/           # 主程序入口
├── internal/
│   ├── api/             # HTTP API处理器
│   ├── config/          # 配置管理
│   ├── contracts/       # 智能合约ABI
│   ├── listener/        # 区块链事件监听
│   ├── model/           # 数据模型定义
│   ├── repository/      # 数据访问层
│   ├── service/         # 业务逻辑层
│   └── verify/          # 哈希验证模块
├── migrations/          # 数据库迁移脚本
└── test_coverage.sh     # 测试覆盖率脚本
```

## 🚀 快速开始

### 环境要求
- Go 1.22+
- PostgreSQL 13+
- 区块链节点 (本地或远程)

### 安装依赖
```bash
go mod tidy
```

### 配置环境
```bash
cp .env.example .env
# 编辑 .env 文件，配置数据库和区块链连接
```

### 运行服务
```bash
go run cmd/server/main.go
```

## 🧪 测试

### 运行所有测试
```bash
# 使用测试脚本（推荐）
chmod +x test_coverage.sh
./test_coverage.sh

# 或手动运行
go test -v ./internal/...
```

### 测试覆盖率
```bash
# 生成覆盖率报告
go test -coverprofile=coverage.out ./internal/...
go tool cover -html=coverage.out -o coverage.html

# 查看覆盖率统计
go tool cover -func=coverage.out
```

## 📊 张家畅模块完成情况

根据任务分工文档，张家畅负责的独立模块已全部完成：

### ✅ 数据库层
- **migrations/001_init.sql**: 完整的数据库建表脚本
- **repository/repository.go**: 纯数据访问层接口与实现
- **DB连接与迁移**: 自动迁移和连接管理

### ✅ 单元测试
- **repository_test.go**: 数据库操作测试 (12个测试用例)
- **verify_test.go**: 哈希验证函数测试 (8个测试用例 + 性能测试)
- **integration_test.go**: API集成测试 (10个测试用例 + 性能测试)
- **测试数据准备与清理**: 完整的测试环境管理

### ✅ 模型定义
- **model/models.go**: 数据结构定义，配合ParsedEvent

### 📈 产出判定达标
- ✅ **测试覆盖率 >80%**: 通过test_coverage.sh验证
- ✅ **CI可跑**: 所有测试用例通过
- ✅ **repository接口稳定**: 实现了任务分工文档中定义的所有接口

## 🔌 API接口

### 健康检查
```bash
GET /health
```

### 研究数据
```bash
# 获取研究数据
GET /api/v1/research/:tokenId

# 验证研究内容
POST /api/v1/verify/research/:tokenId
Content-Type: application/json
{
  "rawContent": "原始内容"
}
```

### 数据集
```bash
# 获取数据集信息
GET /api/v1/dataset/:datasetId
```

## 🔧 接口契约

按照任务分工文档定义的接口契约：

### ParsedEvent 结构
```go
type ParsedEvent struct {
    TokenID   string
    Author    string  
    DataHash  string
    Block     uint64
    TxHash    string
    LogIndex  uint
    EventName string
}
```

### Repository 接口
```go
type Repository interface {
    InsertResearch(e ParsedEvent) error
    GetByID(id string) (*ResearchData, error)
    ListLatest(limit, offset int) ([]ResearchData, error)
    ListByAuthor(author string, limit, offset int) ([]ResearchData, error)
}
```

### Verify 函数
```go
func VerifyHashMatch(expected, raw string) bool
func CalculateKeccak256(data string) string
func VerifyDataIntegrity(rawData, expectedHash string) (bool, string)
```

## 🎯 演示脚本

按照任务分工文档的演示要求：

```bash
# 1. 启动服务
go run cmd/server/main.go

# 2. 健康检查
curl localhost:8080/health

# 3. 查看数据 
curl localhost:8080/api/v1/research/latest

# 4. 验证匹配
curl -X POST localhost:8080/api/v1/verify/research/1 \
  -H "Content-Type: application/json" \
  -d '{"rawContent":"original data"}'

# 5. 验证不匹配  
curl -X POST localhost:8080/api/v1/verify/research/1 \
  -H "Content-Type: application/json" \
  -d '{"rawContent":"modified data"}'
```

## 📋 测试用例覆盖

### Repository层测试 (12个用例)
- 数据插入和幂等性测试
- 数据查询和错误处理
- 事件日志管理
- 并发安全性测试
- 性能基准测试

### Verify层测试 (8个用例)
- Keccak256哈希计算
- SHA256哈希计算  
- 哈希匹配验证
- 数据完整性验证
- 哈希格式和一致性测试
- 大数据哈希测试
- 性能基准测试

### API层测试 (10个用例)
- 健康检查接口
- 研究数据CRUD操作
- 数据集查询接口
- 内容验证接口
- 错误处理和边界测试
- 性能基准测试

## 🏆 成功标准达成

✅ **张家畅任务完成**:
- 测试通过: 所有30+测试用例通过
- 数据层稳定: Repository接口完整实现
- 代码质量合格: 完整的测试覆盖和文档

✅ **整体集成就绪**:
- 端到端流程无阻塞
- 演示效果达预期
- 符合任务分工文档要求
