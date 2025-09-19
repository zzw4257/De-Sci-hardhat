const { ethers } = require("hardhat");

async function main() {
    console.log("🎯 DeSci 平台核心操作演示");
    console.log("==========================================");
    console.log("模拟操作:");
    console.log("• 用户注册 → UserRegistered 事件");
    console.log("• 上传数据集 → DatasetUploaded 事件");
    console.log("• 发表研究成果 → ResearchMinted 事件");
    console.log("==========================================\n");

    const [deployer, researcher, dataProvider] = await ethers.getSigners();
    
    console.log("👥 演示账户:");
    console.log(`部署者: ${deployer.address}`);
    console.log(`研究员: ${researcher.address}`);
    console.log(`数据提供者: ${dataProvider.address}\n`);

    // 读取已部署的合约地址
    const fs = require('fs');
    const path = require('path');
    
    let contractAddresses;
    try {
        const deploymentFile = path.join(__dirname, '../deployments/enhanced-desci-deployment.json');
        if (fs.existsSync(deploymentFile)) {
            const deployment = JSON.parse(fs.readFileSync(deploymentFile, 'utf8'));
            contractAddresses = deployment.contracts;
            console.log("📋 使用已部署的合约地址\n");
        } else {
            throw new Error("未找到部署文件，请先运行 deployEnhancedDeSci.js");
        }
    } catch (error) {
        console.error("❌ 无法加载合约地址:", error.message);
        console.log("💡 请先运行: npm run deploy-contracts\n");
        return;
    }

    try {
        // 连接到已部署的合约
        const registry = await ethers.getContractAt("DeSciRegistry", contractAddresses.userRegistry);
        const platform = await ethers.getContractAt("DeSciPlatform", contractAddresses.platform);
        const datasetManager = await ethers.getContractAt("DatasetManager", contractAddresses.datasetManager);
        const researchNFT = await ethers.getContractAt("ResearchNFT", contractAddresses.researchNFT);

        // ================================
        // 权限检查和设置
        // ================================
        console.log("🔐 检查和设置合约权限...");
        
        const ADMIN_ROLE = await registry.ADMIN_ROLE();
        const hasAdminRole = await registry.hasRole(ADMIN_ROLE, contractAddresses.platform);
        
        if (!hasAdminRole) {
            console.log("⚠️  DeSciPlatform需要admin权限，正在设置...");
            await registry.connect(deployer).grantRole(ADMIN_ROLE, contractAddresses.platform);
            console.log("✅ 已授予DeSciPlatform admin权限");
        } else {
            console.log("✅ DeSciPlatform已有admin权限");
        }
        
        console.log("");

        // ================================
        // 操作1: 用户注册 → UserRegistered 事件
        // ================================
        console.log("🔸 操作1: 用户注册");
        console.log("-----------------------------------");
        
        // 检查用户是否已注册
        const isRegistered = await registry.isRegistered(researcher.address);
        
        if (isRegistered) {
            console.log("ℹ️  研究员已注册，跳过注册步骤");
            console.log(`   已注册用户地址: ${researcher.address}`);
            
            // 获取用户信息
            const userProfile = await registry.getUserProfile(researcher.address);
            console.log(`   用户姓名: ${userProfile.name}`);
            console.log(`   用户机构: ${userProfile.organization}`);
        } else {
            console.log("正在注册研究员...");
            const registerTx = await platform.connect(researcher).registerUserWithReward(
                "Dr. Zhang Wei",                    // 姓名
                "浙江大学计算机学院",                // 机构
                "zhangwei@zju.edu.cn",             // 邮箱
                "Blockchain, AI, Data Science",    // 研究领域
                "QmZhangWeiCredentials",           // 凭证哈希
                1                                  // 角色: Researcher
            );
            
            console.log("⏳ 等待交易确认...");
            const registerReceipt = await registerTx.wait();
            
            // 查找UserRegistered事件
            const userRegisteredEvent = registerReceipt.logs.find(
                log => log.fragment && log.fragment.name === 'UserRegistered'
            );
            
            if (userRegisteredEvent) {
                console.log("🎉 UserRegistered 事件触发!");
                console.log(`   用户地址: ${userRegisteredEvent.args[0]}`);
                console.log(`   用户姓名: ${userRegisteredEvent.args[1]}`);
                console.log(`   用户角色: ${userRegisteredEvent.args[6]}`);
            }
            
                         console.log(`✅ 交易哈希: ${registerTx.hash}`);
             console.log(`📦 区块号: ${registerReceipt.blockNumber}`);
         }
         
         console.log("");

        // ================================  
        // 操作2: 上传数据集 → DatasetUploaded 事件
        // ================================
        console.log("🔸 操作2: 上传数据集");
        console.log("-----------------------------------");
        
        // 先注册数据提供者（如果未注册）
        const isDataProviderRegistered = await registry.isRegistered(dataProvider.address);
        if (!isDataProviderRegistered) {
            console.log("正在注册数据提供者...");
            await platform.connect(dataProvider).registerUserWithReward(
                "Dr. Li Ming",                    // 姓名
                "中科院生物医学研究所",             // 机构
                "liming@cas.cn",                  // 邮箱
                "Bioinformatics, Medical Data",   // 研究领域
                "QmLiMingCredentials",            // 凭证哈希
                3                                 // 角色: DataProvider
            );
            console.log("✅ 数据提供者注册完成");
        } else {
            console.log("ℹ️  数据提供者已注册");
        }
        
        console.log("正在上传COVID-19研究数据集...");
        const uploadTx = await platform.connect(dataProvider).uploadDatasetWithReward(
            "COVID-19 患者数据集",              // 标题
            "包含1000例COVID-19患者的匿名化医疗数据", // 描述
            ["covid19", "medical", "epidemiology"], // 关键词
            2,                                  // 数据类型: Medical
            5120000,                           // 大小: 5MB
            "QmCOVIDDatasetHash",              // IPFS哈希
            "QmCOVIDMetadataHash",             // 元数据哈希
            "QmCOVIDZKPProofHash",             // ZKP证明哈希
            0,                                 // 访问类型: Public
            ethers.parseEther("0.05")          // 访问价格: 0.05 ETH
        );
        
        console.log("⏳ 等待交易确认...");
        const uploadReceipt = await uploadTx.wait();
        
        // 查找DatasetUploaded事件
        const datasetUploadedEvent = uploadReceipt.logs.find(
            log => log.fragment && log.fragment.name === 'DatasetUploaded'
        );
        
        if (datasetUploadedEvent) {
            console.log("🎉 DatasetUploaded 事件触发!");
            console.log(`   数据集ID: ${datasetUploadedEvent.args[0]}`);
            console.log(`   上传者: ${datasetUploadedEvent.args[1]}`);
            console.log(`   标题: ${datasetUploadedEvent.args[2]}`);
        }
        
        console.log(`✅ 交易哈希: ${uploadTx.hash}`);
        console.log(`📦 区块号: ${uploadReceipt.blockNumber}\n`);

        // ================================
        // 操作3: 发表研究成果 → ResearchMinted 事件  
        // ================================
        console.log("🔸 操作3: 发表研究成果");
        console.log("-----------------------------------");
        
        // 检查内容是否已存在
        const contentHash = "QmBlockchainResearchHash";
        let shouldMint = true;
        
        try {
            // 尝试获取总供应量，然后检查是否已存在相同内容
            const totalSupply = await researchNFT.totalSupply();
            console.log(`当前已有 ${totalSupply} 个研究成果NFT`);
            
            if (Number(totalSupply) > 0) {
                console.log("ℹ️  已有研究成果，为避免重复，使用新的内容哈希");
                // 使用时间戳创建唯一的内容哈希
                const timestamp = Date.now();
                const uniqueContentHash = `QmBlockchainResearch${timestamp}`;
                console.log(`   新内容哈希: ${uniqueContentHash}`);
            }
        } catch (error) {
            console.log("ℹ️  继续发表研究成果...");
        }
        
        console.log("正在发表区块链研究论文...");
        const uniqueTimestamp = Date.now();
        const mintTx = await researchNFT.connect(researcher).mintResearch(
            [researcher.address],                        // 作者列表
            [10000],                                     // 作者份额 (100%)
            "区块链在科学数据管理中的应用",                // 标题
            "本研究探讨了区块链技术在科学数据管理中的创新应用，提出了基于智能合约的数据完整性验证方案。", // 摘要
            ["blockchain", "data-management", "smart-contracts"], // 关键词
            ["Computer Science", "Data Science"],        // 研究领域
            0,                                           // 发表类型: Paper
            `QmBlockchainResearch${uniqueTimestamp}`,    // 内容哈希 (唯一)
            `QmBlockchainMetadata${uniqueTimestamp}`,    // 元数据哈希 (唯一)
            true,                                        // 开放获取
            ethers.parseEther("0.0"),                    // 访问价格 (免费)
            `QmBlockchainTokenURI${uniqueTimestamp}`     // Token URI (唯一)
        );
        
        console.log("⏳ 等待交易确认...");
        const mintReceipt = await mintTx.wait();
        
        // 查找ResearchMinted事件
        const researchMintedEvent = mintReceipt.logs.find(
            log => log.fragment && log.fragment.name === 'ResearchMinted'
        );
        
        if (researchMintedEvent) {
            console.log("🎉 ResearchMinted 事件触发!");
            console.log(`   Token ID: ${researchMintedEvent.args[0]}`);
            console.log(`   作者: ${researchMintedEvent.args[1]}`);
            console.log(`   标题: ${researchMintedEvent.args[2]}`);
        }
        
        console.log(`✅ 交易哈希: ${mintTx.hash}`);
        console.log(`📦 区块号: ${mintReceipt.blockNumber}\n`);

        // ================================
        // 演示总结
        // ================================
        console.log("🎉 核心操作演示完成!");
        console.log("==========================================");
        console.log("✅ 演示成果:");
        console.log("   • 用户注册系统 - 研究员和数据提供者成功注册");
        console.log("   • 数据集管理 - COVID-19数据集成功上传并设置访问控制");
        console.log("   • 学术成果发表 - 区块链研究论文成功NFT化");
        console.log("   • 事件系统 - 所有关键操作都触发了相应的链上事件");
        console.log("   • 可追溯性 - 每个操作都有交易哈希和区块号记录");
        
        console.log("\n📊 链上事件记录:");
        console.log("   1. UserRegistered - 用户注册到平台");
        console.log("   2. DatasetUploaded - 科研数据上链存储");  
        console.log("   3. ResearchMinted - 学术成果NFT铸造");
        
        console.log("\n🔗 后续链下同步:");
        console.log("   💾 Go后端监听这些事件");
        console.log("   🗃️ 事件数据自动同步到SQLite数据库");
        console.log("   📡 通过RESTful API提供查询服务");
        
        console.log("\n🎯 演示价值:");
        console.log("   🔐 数据主权 - 科研者完全拥有自己的数据和成果");
        console.log("   🌐 去中心化 - 无需依赖传统期刊或机构审查");
        console.log("   📈 透明激励 - 基于贡献的代币奖励机制");
        console.log("   🔍 完全可审计 - 所有科研活动永久记录在区块链");
        
        console.log("\n🚀 这就是Web3科研的未来! 🌟");

    } catch (error) {
        console.error("❌ 演示执行失败:", error.message);
        console.error("\n🔍 可能的原因:");
        console.error("   • 确保Hardhat网络正在运行");
        console.error("   • 确保合约已正确部署");
        console.error("   • 检查账户余额是否充足");
        
        throw error;
    }
}

// 运行演示
if (require.main === module) {
    main()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error(error);
            process.exit(1);
        });
}

module.exports = { main }; 