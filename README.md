# DeSci 去中心化科研平台

## 项目概述

DeSci（去中心化科学）平台是一个基于区块链技术构建的科研协作平台，旨在通过去中心化的方式促进科学研究的开放性、透明性和协作性。平台支持研究成果的确权、数据共享、同行评审和影响力评估等功能。

## 核心功能

1. **用户注册与身份管理** - 多角色系统（研究员、评审员、数据提供者、机构）
2. **数据集管理** - 安全的数据上传、验证、访问控制和收益分成机制
3. **科研成果NFT化** - 研究成果NFT铸造、版权确权、同行评审和交易流通
4. **影响力排行** - 多维度影响力计算，全球、领域、机构排名体系
5. **零知识证明验证** - 保护研究数据隐私和匿名评审

## 技术架构

- **区块链层**: 基于以太坊的智能合约，确保数据透明和不可篡改
- **隐私保护**: 零知识证明技术保护研究数据隐私和匿名评审
- **分布式存储**: IPFS去中心化存储确保数据安全和永久可访问
- **前端框架**: React + Wagmi + RainbowKit

## 项目结构

```
desci-platform/
├── contracts/                 # 智能合约
│   ├── DeSciRegistry.sol     # 用户注册合约
│   ├── DatasetManager.sol    # 数据集管理合约
│   ├── ResearchNFT.sol       # 科研成果NFT合约
│   ├── InfluenceRanking.sol  # 影响力排行合约
│   └── DeSciPlatform.sol     # 主平台合约
├── frontend/                 # 前端应用
├── scripts/                  # 部署和测试脚本
├── test/                     # 测试文件
└── docs/                     # 技术文档
```

## 快速开始

### 环境准备

```bash
# 克隆项目
git clone <repository-url>
cd desci-platform

# 安装后端依赖
npm install

# 安装前端依赖
cd frontend
npm install
cd ..
```

### 合约部署

```bash
# 启动本地网络
npx hardhat node

# 在新终端中部署合约
npx hardhat run scripts/deployEnhancedDeSci.js --network localhost
```

### 运行前端

```bash
# 启动前端开发服务器
cd frontend
npm start
```

## 核心合约说明

### DeSciRegistry.sol
用户注册和身份管理合约，支持多角色系统和声誉管理。

### DatasetManager.sol
数据集管理合约，支持数据上传、访问控制和收益分成。

### ResearchNFT.sol
科研成果NFT合约，支持研究成果的NFT化、评审和引用追踪。

### InfluenceRanking.sol
影响力排行合约，计算和维护用户、领域、机构的影响力排名。

### DeSciPlatform.sol
主平台协调合约，整合所有功能模块并提供统一接口。

## API接口

详细API接口说明请参考 [技术文档](docs/DeSci_Platform_Documentation.md)

## 测试

```bash
# 运行合约测试
npx hardhat test
```

## 许可证

本项目采用MIT许可证。