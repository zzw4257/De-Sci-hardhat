# 🔗 智能合约使用指南

## 📋 **合约部署**

```bash
# 启动本地区块链
npx hardhat node

# 编译合约
npx hardhat compile

# 部署所有合约
npm run deploy-contracts
```

## 🔧 **核心合约功能**

### 1. DeSciRegistry - 用户管理
```javascript
// 用户注册
await registry.registerUser(name, org, email, fields, credentials, role);

// 检查注册状态
const isRegistered = await registry.isRegistered(userAddress);

// 获取用户信息
const profile = await registry.getUserProfile(userAddress);
```

### 2. DatasetManager - 数据集管理
```javascript
// 上传数据集
await datasetManager.uploadDataset(title, description, keywords, dataType, size, ipfsHash, metadataHash, zkpProof, accessType, price);

// 查询数据集
const dataset = await datasetManager.getDataset(datasetId);
```

### 3. ResearchNFT - 研究成果NFT
```javascript
// 铸造研究NFT
await researchNFT.mintResearch(authors, shares, title, abstract, keywords, fields, pubType, contentHash, metadataHash, isOpenAccess, price, tokenURI);

// 查询NFT信息
const research = await researchNFT.getResearch(tokenId);
```

### 4. DeSciPlatform - 主平台
```javascript
// 用户注册(带奖励)
await platform.registerUserWithReward(name, org, email, fields, credentials, role);

// 上传数据集(带奖励)
await platform.uploadDatasetWithReward(title, description, keywords, dataType, size, ipfsHash, metadataHash, zkpProof, accessType, price);
```

### 5. ZKPVerifier - 零知识证明
```javascript
// 验证Groth16证明
await zkpVerifier.verifyGroth16Proof(proofType, proof, publicInputs);

// 注册证明类型
await zkpVerifier.registerProofType(proofType, alpha1, beta2, gamma2, delta2, ic);
```

## 📊 **事件监听**

### 关键事件
- `UserRegistered(address user, string name, ...)`
- `DatasetUploaded(uint256 datasetId, address owner, string title)`  
- `ResearchMinted(uint256 tokenId, address author, string title)`
- `ProofSubmitted(uint256 proofId, address submitter, string proofType)`

### 监听示例
```javascript
// 监听用户注册事件
registry.on("UserRegistered", (user, name, role) => {
    console.log(`新用户注册: ${name} (${user})`);
});
```

## 🔧 **部署后配置**

```bash
# 查看部署地址
cat deployments/enhanced-desci-deployment.json

# 合约地址配置文件
cat frontend/src/contracts.json
```

## 🧪 **测试合约**

```bash
# 运行单元测试
npx hardhat test

# 运行完整测试场景
npm run demo-scenario
``` 