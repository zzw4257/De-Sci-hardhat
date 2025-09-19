# 🧬 DeSci 去中心化科研平台

基于区块链的去中心化科研协作平台，实现链上写、链下读的完整数据管理架构。

## 🏗️ **项目架构**

```
📁 项目根目录
├── 🔗 contracts/          # 智能合约 (10个核心合约)
├── 🖥️ frontend/           # React前端应用
├── ⚙️ backend/            # Go后端服务
├── 📜 scripts/            # 部署和演示脚本
└── 📋 使用文档            # 各模块使用指南
```

## 🚀 **快速开始**

### 环境要求
- Node.js 16+
- Go 1.19+
- Git

### 一键启动演示
```bash
# 1. 安装依赖
npm install && cd backend && go mod tidy && cd ..

# 2. 启动完整演示
./demo-complete.sh
```

### 分步启动
```bash
# 1. 启动区块链网络 (终端1)
npm run start-hardhat

# 2. 部署智能合约 (终端2)  
npm run deploy-contracts

# 3. 启动后端服务 (终端3)
./start-backend-with-contracts.sh

# 4. 运行核心操作演示
npm run demo-core

# 5. 启动前端 (终端4)
cd frontend && npm start
```

## 🔧 **10个核心智能合约**

1. **DeSciRegistry** - 用户注册与身份管理
2. **ZKPVerifier** - 零知识证明验证系统
3. **ZKProof** - ZKP证明管理
4. **ConstraintManager** - 约束管理系统
5. **DataFeatureExtractor** - 数据特征提取
6. **ResearchDataVerifier** - 科研数据验证
7. **DatasetManager** - 数据集管理系统
8. **ResearchNFT** - 科研成果NFT化
9. **InfluenceRanking** - 影响力排行系统
10. **DeSciPlatform** - 主平台协调系统

## 📡 **核心功能演示**

### 链上操作 (智能合约)
- 用户注册 → `UserRegistered` 事件
- 数据集上传 → `DatasetUploaded` 事件  
- 研究成果发表 → `ResearchMinted` 事件

### 链下查询 (RESTful API)
```bash
# 健康检查
curl http://localhost:8080/health

# 查询最新研究
curl "http://localhost:8080/api/research/latest?limit=5"

# 按TokenID查询
curl "http://localhost:8080/api/research/{tokenId}"

# 按作者查询
curl "http://localhost:8080/api/research/by-author/{address}"

# 验证内容哈希
curl -X POST "http://localhost:8080/api/research/{tokenId}/verify" \
  -H "Content-Type: application/json" \
  -d '{"rawContent": "原始内容"}'
```

## 🎯 **核心价值**

- **🔐 数据主权** - 科研者完全拥有自己的数据和成果
- **🌐 去中心化** - 无需依赖传统期刊或机构审查
- **📈 透明激励** - 基于贡献的代币奖励机制
- **🔍 完全可审计** - 所有科研活动永久记录在区块链
- **⚡ 高性能查询** - 链上写、链下读的混合架构

## 📚 **详细文档**

- [智能合约使用指南](contracts/README.md)
- [前端应用部署指南](frontend/README.md)  
- [后端服务配置指南](backend/README.md)

## 🛑 **停止服务**

```bash
# 停止所有服务
./stop-demo.sh
```

---

**🎉 这是一个完整的Web3科研生态系统，实现了链上写、链下读与数据库真实集成的DeSci平台架构！**