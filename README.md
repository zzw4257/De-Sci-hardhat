# DeSci 去中心化科研平台

基于区块链的去中心化科研协作平台，包含10个核心智能合约和完整的前端应用。

## 📚 完整文档

详细的项目说明、架构设计、API接口和使用指南请查看：[**技术文档**](docs/DeSci_Platform_Documentation.md)

## 🚀 快速开始

### 编译合约

```bash
# 安装依赖
npm install

# 编译所有智能合约
npx hardhat compile
```

### 运行测试

```bash
# 运行所有测试
npx hardhat test

# 运行完整合约验证测试
npx hardhat test test/CompleteContractTest.js

# 运行特定合约测试
npx hardhat test test/DeSciRegistry.test.js
npx hardhat test test/DeSciPlatform.test.js
```

### 部署和启动

```bash
# 启动本地区块链网络
npx hardhat node

# 部署所有合约（在新终端）
npx hardhat run scripts/deployEnhancedDeSci.js --network localhost

# 启动前端应用
cd frontend && npm install && npm start
```

## 🔧 10个核心智能合约

### 1. DeSciRegistry.sol - 用户注册与身份管理
- **功能**: 多角色用户注册（研究员、评审员、数据提供者、机构）
- **核心方法**: `registerUser()`, `updateReputation()`, `getUserProfile()`
- **特性**: 声誉积分管理、角色升级申请、验证请求处理

### 2. DatasetManager.sol - 数据集管理系统
- **功能**: 数据集上传、访问控制、质量验证、收益分配
- **核心方法**: `uploadDataset()`, `purchaseAccess()`, `citeDataset()`
- **特性**: IPFS存储、ZKP隐私保护、动态定价机制

### 3. ResearchNFT.sol - 科研成果NFT化
- **功能**: 研究成果NFT铸造、同行评审、引用追踪
- **核心方法**: `mintResearch()`, `submitPeerReview()`, `addCitation()`
- **特性**: 多作者份额分配、影响力计算、开放获取设置

### 4. InfluenceRanking.sol - 影响力排行系统
- **功能**: 多维度影响力计算、全球/领域/机构排名
- **核心方法**: `updateUserInfluence()`, `getGlobalTopRanking()`, `getUserInfluenceDetails()`
- **特性**: 发表、评审、数据贡献、协作、治理等多维度评估

### 5. DeSciPlatform.sol - 主平台协调系统
- **功能**: 平台各模块协调、奖励分发、治理代币管理
- **核心方法**: `registerUserWithReward()`, `uploadDatasetWithReward()`, `getPlatformStats()`
- **特性**: 自动奖励机制、跨合约调用、平台配置管理

### 6. ZKPVerifier.sol - 零知识证明验证
- **功能**: Groth16零知识证明验证、多种科研场景约束验证
- **核心方法**: `verifyGroth16Proof()`, `registerProofType()`, `verifyMultipleProofs()`
- **特性**: 批量验证、可配置验证参数、验证结果记录

### 7. ConstraintManager.sol - 约束管理系统
- **功能**: 动态约束条件管理、约束组和验证规则配置
- **核心方法**: `createConstraint()`, `createConstraintGroup()`, `evaluateValidationRule()`
- **特性**: 多维度约束评估、优先级权重设置、灵活的规则组合

### 8. DataFeatureExtractor.sol - 数据特征提取
- **功能**: 科研数据统计特征计算、多数据类型支持
- **核心方法**: `calculateDataFeatures()`, `updateStatisticalMetrics()`, `calculateDataQualityScore()`
- **特性**: 特征哈希生成、批量处理、数据质量评分

### 9. ResearchDataVerifier.sol - 科研数据验证
- **功能**: 科研数据提交管理、特征提取存储、约束验证
- **核心方法**: `submitResearchData()`, `extractDataFeatures()`, `validateDataConstraints()`
- **特性**: ZKP验证集成、数据溯源记录、完整性检查

### 10. ZKProof.sol - ZKP证明管理
- **功能**: 零知识证明提交管理、多种证明类型支持
- **核心方法**: `submitProof()`, `verifyProof()`, `addProofType()`
- **特性**: 证明验证状态跟踪、用户证明历史、声誉要求检查

## 📋 测试覆盖

- ✅ **单元测试**: 每个合约的核心功能测试
- ✅ **集成测试**: 合约间协作和数据流测试
- ✅ **完整流程测试**: 端到端科研工作流程验证
- ✅ **12个测试用例全部通过**，覆盖所有核心功能