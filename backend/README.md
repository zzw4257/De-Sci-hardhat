# DeSci Backend

Go语言实现的DeSci平台后端服务，采用链上写入/链下读取架构。

## 🚀 快速启动

### 方法一：一键启动
```bash
./start.sh
```

### 方法二：手动启动
```bash
# 1. 安装依赖
go mod tidy

# 2. 编译项目
go build -o main_simple cmd/server/main_simple.go

# 3. 启动服务
PORT=8088 ./main_simple
```

### 方法三：直接运行
```bash
go run cmd/server/main_simple.go
```

## 📊 API测试

服务启动后，运行演示脚本测试所有API：

```bash
./demo.sh
```

### 可用接口

- `GET /health` - 健康检查
- `GET /api/v1/research/:tokenId` - 获取研究数据
- `GET /api/v1/dataset/:datasetId` - 获取数据集
- `POST /api/v1/verify/research/:tokenId` - 验证研究内容

### 示例请求

```bash
# 健康检查
curl http://localhost:8088/health

# 查看研究数据
curl http://localhost:8088/api/v1/research/123

# 查看数据集
curl http://localhost:8088/api/v1/dataset/456

# 验证研究内容
curl -X POST http://localhost:8088/api/v1/verify/research/789 \
     -H "Content-Type: application/json" \
     -d '{"raw":"test data"}'
```

## 📁 目录结构

```
backend/
├── cmd/server/              # 启动入口
│   ├── main.go             # 完整版本（待完善）
│   └── main_simple.go      # 简化版本（当前可用）
├── internal/               # 内部模块
│   ├── config/config.go    # 配置管理
│   ├── listener/           # 区块链事件监听
│   ├── model/models.go     # 数据模型
│   ├── repository/         # 数据访问层
│   ├── service/            # 业务逻辑层
│   ├── verify/hash.go      # 哈希验证
│   ├── api/router.go       # HTTP路由
│   └── contracts/          # 合约ABI文件
├── migrations/             # 数据库迁移
├── .env                    # 环境变量
├── start.sh               # 启动脚本
├── demo.sh                # 演示脚本
└── README.md              # 说明文档
```

## 🔧 配置说明

环境变量配置文件 `.env`：

```bash
# 服务器配置
PORT=8088

# 区块链配置
ETHEREUM_RPC=http://localhost:8545
START_BLOCK=0
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# 数据库配置
DATABASE_URL=postgres://zzw4257@localhost:5432/desci?sslmode=disable

# 合约地址
DESCI_REGISTRY_ADDRESS=0x5FbDB2315678afecb367f032d93F642f64180aa3
RESEARCH_NFT_ADDRESS=0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9
DATASET_MANAGER_ADDRESS=0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
INFLUENCE_RANKING_ADDRESS=0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9
DESCI_PLATFORM_ADDRESS=0x5FC8d32690cc91D4c39d9d3abcBD16989F875707
```

## 📝 当前状态

✅ **已完成**：
- 基本项目结构
- 简化版API服务器
- 模拟数据响应
- 健康检查接口
- 基础CRUD接口
- 启动和演示脚本

🚧 **待完善**：
- 数据库连接和迁移
- 区块链事件监听
- 真实数据处理
- 哈希验证逻辑
- 错误处理和日志

## 🎯 下一步开发

主要在以下目录进行开发：

- `internal/listener/` - 事件处理逻辑
- `internal/service/` - 业务逻辑
- `internal/api/` - API接口
- `internal/repository/` - 数据访问

## 📋 开发者说明

当前为MVP版本，所有API返回模拟数据。这样设计的好处：

1. **快速验证** - 可以立即测试API接口
2. **前端开发** - 前端可以基于这些接口进行开发
3. **逐步完善** - 后续可以逐步替换为真实数据
4. **演示友好** - 适合演示和测试

要切换到完整版本，需要：
1. 配置PostgreSQL数据库
2. 运行数据库迁移脚本
3. 修改main.go中的启动逻辑
4. 完善区块链监听器
