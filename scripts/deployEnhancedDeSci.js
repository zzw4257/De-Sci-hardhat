const { ethers } = require("hardhat");

async function main() {
    console.log("🚀 开始部署增强版DeSci平台...\n");
    
    const [deployer] = await ethers.getSigners();
    console.log("👤 部署账户:", deployer.address);
    
    const balance = await deployer.provider.getBalance(deployer.address);
    console.log("💰 账户余额:", ethers.formatEther(balance), "ETH\n");

    const deployedContracts = {};

    try {
        // 1. 部署用户注册合约
        console.log("📝 部署DeSciRegistry合约...");
        const DeSciRegistry = await ethers.getContractFactory("DeSciRegistry");
        const userRegistry = await DeSciRegistry.deploy();
        await userRegistry.waitForDeployment();
        deployedContracts.userRegistry = await userRegistry.getAddress();
        console.log("✅ DeSciRegistry部署完成:", deployedContracts.userRegistry);

        // 2. 部署ZKP验证合约
        console.log("\n🔐 部署ZKPVerifier合约...");
        const ZKPVerifier = await ethers.getContractFactory("ZKPVerifier");
        const zkpVerifier = await ZKPVerifier.deploy();
        await zkpVerifier.waitForDeployment();
        deployedContracts.zkpVerifier = await zkpVerifier.getAddress();
        console.log("✅ ZKPVerifier部署完成:", deployedContracts.zkpVerifier);

        // 3. 部署数据集管理合约
        console.log("\n📊 部署DatasetManager合约...");
        const DatasetManager = await ethers.getContractFactory("DatasetManager");
        const datasetManager = await DatasetManager.deploy();
        await datasetManager.waitForDeployment();
        deployedContracts.datasetManager = await datasetManager.getAddress();
        console.log("✅ DatasetManager部署完成:", deployedContracts.datasetManager);

        // 4. 部署科研成果NFT合约
        console.log("\n🎨 部署ResearchNFT合约...");
        const ResearchNFT = await ethers.getContractFactory("ResearchNFT");
        const researchNFT = await ResearchNFT.deploy();
        await researchNFT.waitForDeployment();
        deployedContracts.researchNFT = await researchNFT.getAddress();
        console.log("✅ ResearchNFT部署完成:", deployedContracts.researchNFT);

        // 5. 部署影响力排行合约
        console.log("\n📈 部署InfluenceRanking合约...");
        const InfluenceRanking = await ethers.getContractFactory("InfluenceRanking");
        const influenceRanking = await InfluenceRanking.deploy(
            deployedContracts.userRegistry,
            deployedContracts.datasetManager,
            deployedContracts.researchNFT,
            deployedContracts.zkpVerifier
        );
        await influenceRanking.waitForDeployment();
        deployedContracts.influenceRanking = await influenceRanking.getAddress();
        console.log("✅ InfluenceRanking部署完成:", deployedContracts.influenceRanking);

        // 6. 部署主平台合约
        console.log("\n🏛️ 部署DeSciPlatform主合约...");
        const DeSciPlatform = await ethers.getContractFactory("DeSciPlatform");
        const platform = await DeSciPlatform.deploy(
            deployedContracts.userRegistry,
            deployedContracts.datasetManager,
            deployedContracts.researchNFT,
            deployedContracts.influenceRanking,
            deployedContracts.zkpVerifier
        );
        await platform.waitForDeployment();
        deployedContracts.platform = await platform.getAddress();
        console.log("✅ DeSciPlatform部署完成:", deployedContracts.platform);

        // 获取SciToken地址
        const sciTokenAddress = await platform.sciToken();
        deployedContracts.sciToken = sciTokenAddress;
        console.log("🪙 SciToken地址:", deployedContracts.sciToken);

        console.log("\n🎉 所有合约部署完成！");
        
        // 输出所有合约地址
        console.log("\n📋 合约地址汇总:");
        console.log("=" .repeat(60));
        Object.entries(deployedContracts).forEach(([name, address]) => {
            console.log(`${name.padEnd(20)}: ${address}`);
        });
        console.log("=" .repeat(60));

        // 设置合约权限和初始配置
        console.log("\n⚙️ 配置合约权限...");
        
        // 设置DatasetManager的质量验证者
        await datasetManager.addQualityVerifier(deployer.address);
        console.log("✅ 添加质量验证者");

        // 设置ResearchNFT的评审员权限
        await researchNFT.addAuthorizedReviewer(deployer.address);
        console.log("✅ 添加授权评审员");

        // 验证合约功能
        console.log("\n🔍 验证合约功能...");
        
        // 检查平台统计
        const stats = await userRegistry.getPlatformStats();
        console.log("📊 初始平台统计:");
        console.log(`  - 总用户数: ${stats[0]}`);
        console.log(`  - 研究员数: ${stats[1]}`);
        console.log(`  - 评审员数: ${stats[2]}`);

        // 保存部署信息到文件
        const deploymentInfo = {
            network: "localhost",
            deployer: deployer.address,
            timestamp: new Date().toISOString(),
            contracts: deployedContracts,
            gasUsed: "估算中..."
        };

        const fs = require('fs');
        const path = require('path');
        
        // 确保deployments目录存在
        const deploymentsDir = path.join(__dirname, '../deployments');
        if (!fs.existsSync(deploymentsDir)) {
            fs.mkdirSync(deploymentsDir);
        }

        // 保存部署信息
        fs.writeFileSync(
            path.join(deploymentsDir, 'enhanced-desci-deployment.json'),
            JSON.stringify(deploymentInfo, null, 2)
        );

        console.log("\n💾 部署信息已保存至 deployments/enhanced-desci-deployment.json");

        // 创建前端配置文件
        const frontendConfig = {
            contracts: {
                DeSciRegistry: {
                    address: deployedContracts.userRegistry,
                    abi: "artifacts/contracts/DeSciRegistry.sol/DeSciRegistry.json"
                },
                DatasetManager: {
                    address: deployedContracts.datasetManager,
                    abi: "artifacts/contracts/DatasetManager.sol/DatasetManager.json"
                },
                ResearchNFT: {
                    address: deployedContracts.researchNFT,
                    abi: "artifacts/contracts/ResearchNFT.sol/ResearchNFT.json"
                },
                InfluenceRanking: {
                    address: deployedContracts.influenceRanking,
                    abi: "artifacts/contracts/InfluenceRanking.sol/InfluenceRanking.json"
                },
                DeSciPlatform: {
                    address: deployedContracts.platform,
                    abi: "artifacts/contracts/DeSciPlatform.sol/DeSciPlatform.json"
                },
                SciToken: {
                    address: deployedContracts.sciToken,
                    abi: "artifacts/contracts/DeSciPlatform.sol/SciToken.json"
                }
            },
            network: {
                name: "localhost",
                chainId: 31337,
                rpcUrl: "http://127.0.0.1:8545"
            }
        };

        fs.writeFileSync(
            path.join(__dirname, '../frontend/src/contracts.json'),
            JSON.stringify(frontendConfig, null, 2)
        );

        console.log("🌐 前端配置文件已创建: frontend/src/contracts.json");
        
        console.log("\n🎯 部署总结:");
        console.log("✅ 用户注册系统已就绪");
        console.log("✅ 数据集管理系统已就绪");
        console.log("✅ 科研成果NFT系统已就绪");
        console.log("✅ 影响力排行系统已就绪");
        console.log("✅ ZKP验证系统已就绪");
        console.log("✅ 主平台合约已就绪");
        console.log("✅ 治理代币系统已就绪");

        console.log("\n🚀 DeSci平台现在可以投入使用了！");
        
        return deployedContracts;

    } catch (error) {
        console.error("\n❌ 部署过程中出现错误:");
        console.error(error);
        
        // 如果有部分合约已部署，显示已部署的合约
        if (Object.keys(deployedContracts).length > 0) {
            console.log("\n📋 已成功部署的合约:");
            Object.entries(deployedContracts).forEach(([name, address]) => {
                console.log(`${name}: ${address}`);
            });
        }
        
        throw error;
    }
}

// 如果直接运行此脚本
if (require.main === module) {
    main()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error(error);
            process.exit(1);
        });
}

module.exports = { main };