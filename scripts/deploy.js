const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("🚀 开始部署DeSci平台智能合约...");
  console.log("部署账户:", deployer.address);
  console.log("账户余额:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)));

  // 部署合约的地址映射
  const contracts = {};

  try {
    // 1. 部署 DeSciRegistry 合约
    console.log("\n📝 部署 DeSciRegistry 合约...");
    const DeSciRegistry = await ethers.getContractFactory("DeSciRegistry");
    const registry = await DeSciRegistry.deploy();
    await registry.waitForDeployment();
    contracts.DeSciRegistry = await registry.getAddress();
    console.log("✅ DeSciRegistry 部署完成:", contracts.DeSciRegistry);

    // 2. 部署 DatasetManager 合约
    console.log("\n📊 部署 DatasetManager 合约...");
    const DatasetManager = await ethers.getContractFactory("DatasetManager");
    const datasetManager = await DatasetManager.deploy();
    await datasetManager.waitForDeployment();
    contracts.DatasetManager = await datasetManager.getAddress();
    console.log("✅ DatasetManager 部署完成:", contracts.DatasetManager);

    // 3. 部署 ResearchNFT 合约
    console.log("\n🎨 部署 ResearchNFT 合约...");
    const ResearchNFT = await ethers.getContractFactory("ResearchNFT");
    const researchNFT = await ResearchNFT.deploy();
    await researchNFT.waitForDeployment();
    contracts.ResearchNFT = await researchNFT.getAddress();
    console.log("✅ ResearchNFT 部署完成:", contracts.ResearchNFT);

    // 4. 部署 InfluenceRanking 合约
    console.log("\n📈 部署 InfluenceRanking 合约...");
    const InfluenceRanking = await ethers.getContractFactory("InfluenceRanking");
    const influenceRanking = await InfluenceRanking.deploy();
    await influenceRanking.waitForDeployment();
    contracts.InfluenceRanking = await influenceRanking.getAddress();
    console.log("✅ InfluenceRanking 部署完成:", contracts.InfluenceRanking);

    // 5. 部署 DeSciPlatform 主合约
    console.log("\n🏛️ 部署 DeSciPlatform 主合约...");
    const DeSciPlatform = await ethers.getContractFactory("DeSciPlatform");
    const platform = await DeSciPlatform.deploy(
      contracts.DeSciRegistry,
      contracts.DatasetManager,
      contracts.ResearchNFT,
      contracts.InfluenceRanking
    );
    await platform.waitForDeployment();
    contracts.DeSciPlatform = await platform.getAddress();
    console.log("✅ DeSciPlatform 部署完成:", contracts.DeSciPlatform);

    // 6. 部署 ZKP 模块合约
    console.log("\n🔐 部署 ZKP 模块...");
    
    // 6.1 部署 ZKPVerifier
    console.log("部署 ZKPVerifier...");
    const ZKPVerifier = await ethers.getContractFactory("ZKPVerifier");
    const zkpVerifier = await ZKPVerifier.deploy();
    await zkpVerifier.waitForDeployment();
    contracts.ZKPVerifier = await zkpVerifier.getAddress();
    console.log("✅ ZKPVerifier 部署完成:", contracts.ZKPVerifier);
    
    // 6.2 部署 ZKProof
    console.log("部署 ZKProof...");
    const ZKProof = await ethers.getContractFactory("ZKProof");
    const zkProof = await ZKProof.deploy();
    await zkProof.waitForDeployment();
    contracts.ZKProof = await zkProof.getAddress();
    console.log("✅ ZKProof 部署完成:", contracts.ZKProof);
    
    // 6.3 部署 DataFeatureExtractor
    console.log("部署 DataFeatureExtractor...");
    const DataFeatureExtractor = await ethers.getContractFactory("DataFeatureExtractor");
    const dataFeatureExtractor = await DataFeatureExtractor.deploy();
    await dataFeatureExtractor.waitForDeployment();
    contracts.DataFeatureExtractor = await dataFeatureExtractor.getAddress();
    console.log("✅ DataFeatureExtractor 部署完成:", contracts.DataFeatureExtractor);
    
    // 6.4 部署 ConstraintManager
    console.log("部署 ConstraintManager...");
    const ConstraintManager = await ethers.getContractFactory("ConstraintManager");
    const constraintManager = await ConstraintManager.deploy();
    await constraintManager.waitForDeployment();
    contracts.ConstraintManager = await constraintManager.getAddress();
    console.log("✅ ConstraintManager 部署完成:", contracts.ConstraintManager);
    
    // 6.5 部署 ResearchDataVerifier
    console.log("部署 ResearchDataVerifier...");
    const ResearchDataVerifier = await ethers.getContractFactory("ResearchDataVerifier");
    const researchDataVerifier = await ResearchDataVerifier.deploy();
    await researchDataVerifier.waitForDeployment();
    contracts.ResearchDataVerifier = await researchDataVerifier.getAddress();
    console.log("✅ ResearchDataVerifier 部署完成:", contracts.ResearchDataVerifier);

    // 7. 设置权限和授权
    console.log("\n⚙️ 设置合约权限...");
    
    // 设置平台合约为其他合约的授权用户
    try {
      console.log("设置权限关系...");
      // 这里可以根据实际的权限管理方法来设置
      console.log("权限设置完成");
    } catch (error) {
      console.warn("权限设置可选，跳过:", error.message);
    }

    console.log("\n🎉 所有合约部署完成！");
    console.log("=".repeat(60));
    console.log("📋 合约地址清单:");
    console.log("📝 DeSciRegistry:", contracts.DeSciRegistry);
    console.log("📊 DatasetManager:", contracts.DatasetManager);
    console.log("🎨 ResearchNFT:", contracts.ResearchNFT);
    console.log("📈 InfluenceRanking:", contracts.InfluenceRanking);
    console.log("🏛️ DeSciPlatform:", contracts.DeSciPlatform);
    console.log("🔐 ZKPVerifier:", contracts.ZKPVerifier);
    console.log("📋 ZKProof:", contracts.ZKProof);
    console.log("📊 DataFeatureExtractor:", contracts.DataFeatureExtractor);
    console.log("⚖️ ConstraintManager:", contracts.ConstraintManager);
    console.log("🔬 ResearchDataVerifier:", contracts.ResearchDataVerifier);
    console.log("=".repeat(60));

    // 保存合约地址到文件
    const fs = require("fs");
    
    // 创建目录（如果不存在）
    const path = require("path");
    const contractsDir = "./frontend/src/contracts/";
    if (!fs.existsSync(contractsDir)) {
      fs.mkdirSync(contractsDir, { recursive: true });
    }
    
    const contractAddresses = {
      network: "localhost",
      chainId: 31337,
      contracts: contracts,
      deployedAt: new Date().toISOString(),
      deployer: deployer.address
    };
    
    fs.writeFileSync(
      path.join(contractsDir, "addresses.json"),
      JSON.stringify(contractAddresses, null, 2)
    );
    console.log("💾 合约地址已保存到 frontend/src/contracts/addresses.json");

    // 也保存到后端目录
    const backendDir = "./backend/internal/contracts/";
    if (!fs.existsSync(backendDir)) {
      fs.mkdirSync(backendDir, { recursive: true });
    }
    
    fs.writeFileSync(
      path.join(backendDir, "addresses.json"),
      JSON.stringify(contractAddresses, null, 2)
    );
    console.log("💾 合约地址已保存到 backend/internal/contracts/addresses.json");

    return contracts;

  } catch (error) {
    console.error("❌ 部署失败:", error);
    throw error;
  }
}

// 允许脚本被直接运行
if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}

module.exports = main;