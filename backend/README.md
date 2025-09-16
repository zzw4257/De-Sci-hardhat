# DeSci Backend

Go语言实现的DeSci平台后端服务，采用链上写入/链下读取架构。

## 目录结构

```
backend/
├── cmd/server/main.go          # 启动入口
├── internal/
│   ├── config/config.go        # 配置管理
│   ├── listener/listener.go    # 区块链事件监听
│   ├── model/models.go         # 数据模型
│   ├── repository/repo.go      # 数据访问层
│   ├── service/service.go      # 业务逻辑层
│   ├── verify/hash.go          # 哈希验证
│   ├── api/router.go           # HTTP路由
│   └── contracts/              # 合约ABI文件
├── migrations/001_init.sql     # 数据库迁移
├── .env.example                # 环境变量示例
└── go.mod                      # Go依赖管理
```

## 环境配置

1. 复制环境变量文件：

```bash
cp .env.example .env
```

2. 配置数据库：

```bash
# 确保PostgreSQL运行
createdb desci
```

3. 配置环境变量：

- PORT: 服务端口（默认8080）
- ETHEREUM_RPC: 以太坊RPC地址
- DATABASE_URL: PostgreSQL连接串
- 各合约地址：部署后填入

## 运行

```bash
# 安装依赖
go mod tidy

# 运行服务
go run cmd/server/main.go
```

## API接口

- `GET /health` - 健康检查
- `GET /api/v1/research/:tokenId` - 获取研究数据
- `GET /api/v1/dataset/:datasetId` - 获取数据集
- `POST /api/v1/verify/research/:tokenId` - 验证研究内容

## 核心功能

1. **事件监听**: 自动监听智能合约事件并同步到数据库
2. **数据验证**: 通过哈希验证确保数据完整性
3. **幂等处理**: 防止重复处理相同事件
4. **高性能查询**: 链下数据库提供快速查询

## 后续开发

主要在以下目录进行开发：

- `internal/listener/` - 事件处理逻辑
- `internal/service/` - 业务逻辑
- `internal/api/` - API接口
- `internal/repository/` - 数据访问
