# DeSci Backend - Go 数据库层

基于 Go + PostgreSQL 的后端模块，负责链上事件与业务数据的持久化与查询。

## 🎯 核心功能

- **数据库层**: 使用 GORM 进行 PostgreSQL 数据操作
- **事务支持**: 原子性的跨表操作
- **幂等操作**: 防重复插入，支持高并发场景
- **哈希验证**: Keccak256/SHA256 哈希计算与校验
- **API 服务**: Gin 框架的 REST API
- **测试完备**: 单元测试 + 集成测试，覆盖率 ≥80%

## 📁 项目结构

```
backend/
├── internal/
│   ├── api/           # HTTP API 路由和处理器
│   ├── db/            # 数据库连接和迁移管理
│   ├── model/         # 数据模型定义
│   ├── repository/    # 数据访问层（接口+实现）
│   ├── service/       # 业务逻辑层
│   └── verify/        # 哈希验证工具
├── migrations/        # 数据库迁移文件
├── tests/            # 集成测试
│   └── testutil/     # 测试工具包
├── .github/workflows/ # CI/CD 配置
├── Makefile          # 本地开发命令
└── README.md         # 项目文档
```

## 🚀 快速开始

### 1. 环境要求

- Go 1.22+
- PostgreSQL 15/16
- Docker (可选，用于本地数据库)

### 2. 安装依赖

```bash
make deps
# 或
go mod download
```

### 3. 启动数据库

```bash
# 使用 Docker 启动 PostgreSQL
make docker-up

# 或手动安装 PostgreSQL，配置：
# - 用户: postgres
# - 密码: postgres  
# - 数据库: desci
# - 端口: 5432
```

### 4. 执行迁移

```bash
make migrate
```

### 5. 运行测试

```bash
# 运行所有测试
make test

# 运行测试并检查覆盖率（≥80%）
make check-coverage

# 查看覆盖率报告
make cover
```

## 📊 数据库设计

### 核心表结构

#### research_data - 研究数据表
```sql
- id (SERIAL PRIMARY KEY)
- token_id (VARCHAR UNIQUE) -- 研究成果NFT的tokenId
- title (TEXT) -- 研究标题
- authors (TEXT[]) -- 作者列表
- content_hash (VARCHAR) -- 内容哈希
- metadata_hash (VARCHAR) -- 元数据哈希
- created_at, updated_at (TIMESTAMP)
```

#### dataset_records - 数据集记录表  
```sql
- id (SERIAL PRIMARY KEY)
- dataset_id (VARCHAR UNIQUE) -- 数据集ID
- title, description (TEXT) -- 标题和描述
- owner (VARCHAR) -- 拥有者地址
- ipfs_hash (VARCHAR) -- IPFS哈希
- created_at, updated_at (TIMESTAMP)
```

#### event_logs - 事件日志表
```sql
- id (SERIAL PRIMARY KEY)
- tx_hash (VARCHAR) -- 交易哈希
- log_index (INTEGER) -- 日志索引
- block_number (BIGINT) -- 区块号
- event_name (VARCHAR) -- 事件名称
- contract_address (VARCHAR) -- 合约地址
- payload_raw (TEXT) -- 原始载荷JSON
- processed (BOOLEAN) -- 是否已处理
- created_at (TIMESTAMP)
- UNIQUE(tx_hash, log_index) -- 防重复约束
```

## 🔧 Repository 接口

### 核心接口方法

```go
type IRepository interface {
    // 事务支持
    WithTx(ctx context.Context, fn func(tx IRepository) error) error
    
    // Research 操作
    InsertResearchData(data *model.ResearchData) error
    GetResearchData(tokenID string) (*model.ResearchData, error)
    ListResearchDataByAuthor(author string, limit int) ([]*model.ResearchData, error)
    UpdateResearchData(tokenID string, updates map[string]interface{}) error
    
    // Dataset 操作
    InsertDatasetRecord(record *model.DatasetRecord) error
    GetDatasetRecord(datasetID string) (*model.DatasetRecord, error)
    ListDatasetsByOwner(owner string, limit int) ([]*model.DatasetRecord, error)
    UpdateDatasetRecord(datasetID string, updates map[string]interface{}) error
    
    // EventLog 操作
    InsertEventLog(log *model.EventLog) error
    GetUnprocessedEvents() ([]model.EventLog, error)
    MarkEventProcessed(eventID uint) error
    GetEventsByBlockRange(fromBlock, toBlock uint64) ([]model.EventLog, error)
    
    // 健康检查
    Ping(ctx context.Context) error
}
```

### 特性说明

- **幂等操作**: `InsertResearchData` 和 `InsertEventLog` 基于唯一键自动去重
- **事务封装**: `WithTx` 提供事务上下文，支持跨表原子操作  
- **错误处理**: 统一将 `sql.ErrNoRows` 转换为领域错误
- **分页查询**: 支持 `limit` 参数控制返回数量

## 🧪 测试策略

### 单元测试 (`internal/repository/repository_test.go`)

```bash
# 覆盖场景：
- 正常插入/查询操作
- 幂等性验证（重复插入）
- 唯一约束处理
- 事务回滚测试
- 并发写入测试
- 边界条件测试
```

### 哈希验证测试 (`internal/verify/verify_test.go`)

```bash
# 覆盖场景：
- Keccak256/SHA256 哈希计算
- 哈希格式验证（0x前缀，长度）
- 数据完整性校验
- 大数据哈希性能测试
```

### 集成测试 (`tests/integration_test.go`)

```bash
# 覆盖场景：
- 完整API工作流程
- 数据库迁移验证
- 跨模块协作测试
- HTTP路由和状态码验证
```

## 📈 覆盖率要求

- **总体覆盖率**: ≥80% （CI 强制检查）
- **核心模块覆盖率**: 
  - Repository: ≥85%
  - Verify: ≥90%
  - Service: ≥80%
  - API: ≥75%

```bash
# 本地检查覆盖率
make check-coverage

# CI 自动验证覆盖率阈值，低于 80% 会失败
```

## 🔨 本地开发

### 常用命令 (Makefile)

```bash
make help           # 显示所有可用命令
make dev-setup      # 一键设置开发环境（启动数据库+迁移）
make test           # 运行单元测试
make test-race      # 竞争检测
make check-coverage # 运行测试并检查覆盖率阈值
make lint           # 代码检查
make migrate        # 执行数据库迁移
make docker-up      # 启动PostgreSQL容器
make docker-down    # 停止并删除容器
make ci             # 本地模拟CI流程
```

### 开发工作流

1. **启动环境**: `make dev-setup`
2. **开发代码**: 修改 `internal/` 下的代码
3. **运行测试**: `make test` 验证功能
4. **检查覆盖率**: `make check-coverage` 确保 ≥80%
5. **代码检查**: `make lint` 修复代码问题
6. **提交代码**: 推送到仓库触发 CI

## 🚦 CI/CD 流程

### GitHub Actions 工作流

- **触发条件**: Push 到 main/master 分支或 Pull Request
- **流程步骤**:
  1. 启动 PostgreSQL 服务
  2. 执行数据库迁移
  3. 运行单元测试（race 检测）
  4. 验证覆盖率 ≥80%
  5. 代码检查（golangci-lint）
  6. 集成测试（独立数据库）

### CI 配置文件

- **位置**: `.github/workflows/ci.yml`
- **数据库**: PostgreSQL 16 容器
- **Go 版本**: 1.22
- **缓存**: Go modules 缓存加速构建

## 🛡️ 安全与性能

### 数据安全
- 使用参数化查询防止 SQL 注入
- 事务隔离保证数据一致性
- 唯一约束防止重复数据

### 性能优化
- 数据库索引优化（tx_hash, block_number, owner 等）
- 连接池配置（最大连接数、空闲连接、生命周期）
- 批量操作支持

### 并发处理
- 使用 `-race` 标志检测竞争条件
- 幂等操作支持高并发写入
- 事务回滚确保数据一致性

## 🐛 故障排除

### 常见问题

1. **数据库连接失败**
   ```bash
   export DATABASE_URL="postgres://postgres:postgres@localhost:5432/desci?sslmode=disable"
   make docker-up  # 确保数据库运行
   ```

2. **测试覆盖率不足**
   ```bash
   make cover  # 查看详细覆盖率报告
   # 补充缺失测试用例
   ```

3. **迁移执行失败**
   ```bash
   make db-reset  # 重置数据库（警告：会删除数据）
   ```

4. **依赖问题**
   ```bash
   go mod tidy
   make deps
   ```

## 📚 扩展开发

### 添加新的数据模型

1. 在 `internal/model/models.go` 定义结构
2. 创建对应的迁移文件 `migrations/00X_*.sql`
3. 在 `repository.go` 添加 CRUD 方法
4. 编写对应的测试用例
5. 更新 API 路由（如需要）

### 新增测试用例

1. 单元测试：`internal/*/test.go`
2. 集成测试：`tests/integration_test.go`  
3. 确保覆盖率符合要求

## 📄 许可证

本项目采用 MIT 许可证，详情请查看 LICENSE 文件。 