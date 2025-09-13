const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("🚀 开始部署DeSci平台智能合约...");
  console.log("部署账户:", deployer.address);
  console.log("账户余额:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)));

  // 部署合约的地址映射
  const contracts = {};

  try {
    // 1. 部署 UserProfile 合约
    console.log("\n📝 部署 UserProfile 合约...");
    const UserProfile = await ethers.getContractFactory("UserProfile");
    const userProfile = await UserProfile.deploy();
    await userProfile.waitForDeployment();
    contracts.userProfile = await userProfile.getAddress();
    console.log("✅ UserProfile 部署完成:", contracts.userProfile);

    // 2. 部署 ZKP 模块合约
    console.log("\n🔐 部署 ZKP 模块...");
    
    // 2.1 部署 ZKPVerifier
    console.log("部署 ZKPVerifier...");
    const ZKPVerifier = await ethers.getContractFactory("ZKPVerifier");
    const zkpVerifier = await ZKPVerifier.deploy();
    await zkpVerifier.waitForDeployment();
    contracts.zkpVerifier = await zkpVerifier.getAddress();
    console.log("✅ ZKPVerifier 部署完成:", contracts.zkpVerifier);
    
    // 2.2 部署 ZKProof
    console.log("部署 ZKProof...");
    const ZKProof = await ethers.getContractFactory("ZKProof");
    const zkProof = await ZKProof.deploy();
    await zkProof.waitForDeployment();
    contracts.zkProof = await zkProof.getAddress();
    console.log("✅ ZKProof 部署完成:", contracts.zkProof);
    
    // 2.3 部署 DataFeatureExtractor
    console.log("部署 DataFeatureExtractor...");
    const DataFeatureExtractor = await ethers.getContractFactory("DataFeatureExtractor");
    const dataFeatureExtractor = await DataFeatureExtractor.deploy();
    await dataFeatureExtractor.waitForDeployment();
    contracts.dataFeatureExtractor = await dataFeatureExtractor.getAddress();
    console.log("✅ DataFeatureExtractor 部署完成:", contracts.dataFeatureExtractor);
    
    // 2.4 部署 ConstraintManager
    console.log("部署 ConstraintManager...");
    const ConstraintManager = await ethers.getContractFactory("ConstraintManager");
    const constraintManager = await ConstraintManager.deploy();
    await constraintManager.waitForDeployment();
    contracts.constraintManager = await constraintManager.getAddress();
    console.log("✅ ConstraintManager 部署完成:", contracts.constraintManager);
    
    // 2.5 部署 ResearchDataVerifier
    console.log("部署 ResearchDataVerifier...");
    const ResearchDataVerifier = await ethers.getContractFactory("ResearchDataVerifier");
    const researchDataVerifier = await ResearchDataVerifier.deploy(); // 不需要参数
    await researchDataVerifier.waitForDeployment();
    contracts.researchDataVerifier = await researchDataVerifier.getAddress();
    console.log("✅ ResearchDataVerifier 部署完成:", contracts.researchDataVerifier);

    // 3. 部署 DeSciNFTSimple 合约
    console.log("\n🎨 部署 DeSciNFTSimple 合约...");
    const DeSciNFTSimple = await ethers.getContractFactory("DeSciNFTSimple");
    const nft = await DeSciNFTSimple.deploy();
    await nft.waitForDeployment();
    contracts.nft = await nft.getAddress();
    console.log("✅ DeSciNFTSimple 部署完成:", contracts.nft);

    // 4. 部署 Dataset 合约
    console.log("\n📊 部署 Dataset 合约...");
    const Dataset = await ethers.getContractFactory("Dataset");
    const dataset = await Dataset.deploy();
    await dataset.waitForDeployment();
    contracts.dataset = await dataset.getAddress();
    console.log("✅ Dataset 部署完成:", contracts.dataset);

    // 5. 部署 DeSciPlatform 主合约
    console.log("\n🏛️ 部署 DeSciPlatform 主合约...");
    const DeSciPlatform = await ethers.getContractFactory("DeSciPlatform");
    const platform = await DeSciPlatform.deploy(
      contracts.userProfile,
      contracts.zkProof,
      contracts.nft,
      contracts.dataset
    );
    await platform.waitForDeployment();
    contracts.platform = await platform.getAddress();
    console.log("✅ DeSciPlatform 部署完成:", contracts.platform);

    // 6. 设置权限和授权
    console.log("\n⚙️ 设置合约权限...");
    
    // 设置NFT合约的权限给平台合约
    console.log("设置NFT合约权限...");
    await nft.authorizeMinter(contracts.platform);
    
    // 设置用户档案合约的权限给平台合约
    console.log("设置用户档案合约权限...");
    await userProfile.authorizeUpdater(contracts.platform);
    
    // 设置数据集合约的权限给平台合约
    console.log("设置数据集合约权限...");
    await dataset.authorizeRegistrar(contracts.platform);
    
    // 设置ZKP模块权限
    console.log("设置ZKP模块权限...");
    await dataFeatureExtractor.authorizeCalculator(contracts.researchDataVerifier, true);
    await dataFeatureExtractor.authorizeCalculator(contracts.platform, true);
    
    // 注册额外的证明类型
    console.log("注册证明类型...");
    await zkpVerifier.registerProofType(
      "statistical_analysis",
      [1, 2], // alpha1
      [[1, 2], [3, 4]], // beta2
      [[5, 6], [7, 8]], // gamma2
      [[9, 10], [11, 12]], // delta2
      [[1, 2], [3, 4], [5, 6]] // ic
    );
    
    // 创建基础约束条件
    console.log("创建基础约束条件...");
    await constraintManager.createConstraint(
      "Mean Range Constraint", // name
      "Mean value range constraint", // description
      0, // STATISTICAL category
      1, // BETWEEN operator
      [1, 1000000], // thresholds array
      1, // priority
      10, // weight
      ["mean"], // applicable fields
      true // isGlobal
    );
    
    await constraintManager.createConstraint(
      "Quality Score Constraint", // name
      "Data quality score constraint", // description
      2, // QUALITY category
      2, // GREATER_EQUAL operator
      [0], // thresholds array
      1, // priority
      20, // weight
      ["quality_score"], // applicable fields
      true // isGlobal
    );
    
    // 为平台合约提供一些ETH用于奖励机制
    console.log("为平台合约提供资金...");
    const tx = await deployer.sendTransaction({
      to: contracts.platform,
      value: ethers.parseEther("1.0") // 1 ETH for review rewards
    });
    await tx.wait();

    console.log("\n🎉 所有合约部署完成！");
    console.log("=".repeat(60));
    console.log("📋 合约地址清单:");
    console.log("👥 UserProfile:", contracts.userProfile);
    console.log("🔐 ZKPVerifier:", contracts.zkpVerifier);
    console.log("📋 ZKProof:", contracts.zkProof);
    console.log("📊 DataFeatureExtractor:", contracts.dataFeatureExtractor);
    console.log("⚖️ ConstraintManager:", contracts.constraintManager);
    console.log("🔬 ResearchDataVerifier:", contracts.researchDataVerifier);
    console.log("🎨 DeSciNFTSimple:", contracts.nft);
    console.log("📊 Dataset:", contracts.dataset);
    console.log("🏦 DeSciPlatform:", contracts.platform);
    console.log("=".repeat(60));

    // 保存合约地址到文件
    const fs = require("fs");
    const contractAddresses = {
      network: "localhost",
      chainId: 31337,
      contracts: contracts,
      deployedAt: new Date().toISOString(),
      deployer: deployer.address
    };
    
    fs.writeFileSync(
      "./frontend/src/contracts/addresses.json",
      JSON.stringify(contractAddresses, null, 2)
    );
    console.log("💾 合约地址已保存到 frontend/src/contracts/addresses.json");

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