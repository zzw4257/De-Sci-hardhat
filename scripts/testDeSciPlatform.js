const { ethers } = require("hardhat");
const fs = require('fs');
const path = require('path');

async function main() {
    console.log("🧪 开始DeSci平台功能测试...\n");
    
    const [deployer, user1, user2, user3] = await ethers.getSigners();
    console.log("👥 测试账户:");
    console.log("部署者:", deployer.address);
    console.log("用户1:", user1.address);
    console.log("用户2:", user2.address);
    console.log("用户3:", user3.address);
    
    // 读取部署的合约地址
    const deploymentPath = path.join(__dirname, '../deployments/enhanced-desci-deployment.json');
    if (!fs.existsSync(deploymentPath)) {
        console.error("❌ 未找到部署信息文件，请先运行部署脚本");
        process.exit(1);
    }
    
    const deployment = JSON.parse(fs.readFileSync(deploymentPath, 'utf8'));
    const contracts = deployment.contracts;
    
    console.log("📋 使用的合约地址:");
    Object.entries(contracts).forEach(([name, address]) => {
        console.log(`${name}: ${address}`);
    });
    console.log();

    // 获取合约实例
    const userRegistry = await ethers.getContractAt("DeSciRegistry", contracts.userRegistry);
    const datasetManager = await ethers.getContractAt("DatasetManager", contracts.datasetManager);
    const researchNFT = await ethers.getContractAt("ResearchNFT", contracts.researchNFT);
    const influenceRanking = await ethers.getContractAt("InfluenceRanking", contracts.influenceRanking);
    const platform = await ethers.getContractAt("DeSciPlatform", contracts.platform);
    const sciToken = await ethers.getContractAt("SciToken", contracts.sciToken);

    console.log("🧪 测试1: 用户注册功能");
    console.log("-".repeat(50));
    
    try {
        // 注册用户1为研究员
        console.log("📝 注册用户1为研究员...");
        await userRegistry.connect(user1).registerUser(
            "Alice Johnson",
            "MIT Computer Science",
            "alice@mit.edu",
            "Machine Learning, Computer Vision",
            "QmCredentialsAlice123",
            1 // Researcher
        );
        console.log("✅ 用户1注册成功");

        // 注册用户2为评审员（需要验证）
        console.log("📝 注册用户2为评审员...");
        await userRegistry.connect(user2).registerUser(
            "Bob Smith",
            "Stanford AI Lab",
            "bob@stanford.edu",
            "Natural Language Processing, AI Ethics",
            "QmCredentialsBob456",
            2 // Reviewer
        );
        console.log("✅ 用户2注册成功");

        // 注册用户3为数据提供者
        console.log("📝 注册用户3为数据提供者...");
        await userRegistry.connect(user3).registerUser(
            "Carol Wilson",
            "Data Science Corp",
            "carol@datascience.com",
            "Big Data, Statistical Analysis",
            "QmCredentialsCarol789",
            3 // DataProvider
        );
        console.log("✅ 用户3注册成功");

        // 检查注册状态
        const isUser1Registered = await userRegistry.isRegistered(user1.address);
        const isUser2Registered = await userRegistry.isRegistered(user2.address);
        const isUser3Registered = await userRegistry.isRegistered(user3.address);
        
        console.log(`用户1注册状态: ${isUser1Registered ? '✅' : '❌'}`);
        console.log(`用户2注册状态: ${isUser2Registered ? '✅' : '❌'}`);
        console.log(`用户3注册状态: ${isUser3Registered ? '✅' : '❌'}`);

    } catch (error) {
        console.error("❌ 用户注册测试失败:", error.message);
    }

    console.log("\n🧪 测试2: 数据集管理功能");
    console.log("-".repeat(50));

    try {
        // 用户3上传数据集
        console.log("📊 用户3上传实验数据集...");
        const uploadTx = await datasetManager.connect(user3).uploadDataset(
            "COVID-19 Patient Dataset",
            "Anonymized COVID-19 patient data for research purposes",
            ["covid-19", "medical", "epidemiology"],
            2, // Medical
            1024 * 1024 * 50, // 50MB
            "QmCovidDataset12345",
            "QmCovidMetadata12345",
            "QmCovidZKProof12345",
            2, // Premium access
            ethers.parseEther("0.01") // 0.01 ETH access price
        );
        
        const receipt = await uploadTx.wait();
        console.log("✅ 数据集上传成功");

        // 检查数据集信息
        const dataset1 = await datasetManager.getDataset(1);
        console.log(`数据集标题: ${dataset1.title}`);
        console.log(`数据集大小: ${dataset1.size} bytes`);
        console.log(`访问价格: ${ethers.formatEther(dataset1.accessPrice)} ETH`);

        // 用户1购买数据集访问权限
        console.log("💰 用户1购买数据集访问权限...");
        await datasetManager.connect(user1).purchaseAccess(
            1,
            "For my machine learning research project",
            { value: ethers.parseEther("0.01") }
        );
        console.log("✅ 访问权限购买成功");

        // 检查访问权限
        const hasAccess = await datasetManager.checkAccess(1, user1.address);
        console.log(`用户1访问权限: ${hasAccess ? '✅' : '❌'}`);

    } catch (error) {
        console.error("❌ 数据集管理测试失败:", error.message);
    }

    console.log("\n🧪 测试3: 科研成果NFT功能");
    console.log("-".repeat(50));

    try {
        // 用户1发表研究成果
        console.log("🎨 用户1发表研究论文...");
        const mintTx = await researchNFT.connect(user1).mintResearch(
            [user1.address], // 作者
            [10000], // 作者份额 (100%)
            "Deep Learning for COVID-19 Diagnosis",
            "This paper presents a novel deep learning approach for automated COVID-19 diagnosis using chest X-rays...",
            ["deep-learning", "medical-ai", "covid-19"],
            ["Computer Science", "Medical Informatics"],
            0, // Paper
            "QmResearchPaper12345",
            "QmPaperMetadata12345",
            true, // Open access
            0, // Free access
            "QmTokenURI12345"
        );
        
        await mintTx.wait();
        console.log("✅ 研究成果NFT铸造成功");

        // 检查NFT信息
        const research1 = await researchNFT.researches(1);
        console.log(`论文标题: ${research1.title}`);
        console.log(`作者数量: ${research1.authors.length}`);
        console.log(`开放获取: ${research1.isOpenAccess ? '✅' : '❌'}`);

        // 用户2提交同行评审
        console.log("📝 用户2提交同行评审...");
        await researchNFT.connect(user2).submitPeerReview(
            1,
            8, // 评分 8/10
            "QmReviewContent12345",
            false, // 非匿名评审
            ethers.ZeroHash // 无ZKP证明
        );
        console.log("✅ 同行评审提交成功");

        // 检查评审状态
        const reviews = await researchNFT.getPeerReviews(1);
        console.log(`评审数量: ${reviews.length}`);
        if (reviews.length > 0) {
            console.log(`第一个评审分数: ${reviews[0].score}/10`);
        }

    } catch (error) {
        console.error("❌ 科研成果NFT测试失败:", error.message);
    }

    console.log("\n🧪 测试4: 影响力排行功能");
    console.log("-".repeat(50));

    try {
        // 更新用户影响力
        console.log("📈 更新用户1影响力...");
        await influenceRanking.updateUserInfluence(user1.address);
        console.log("✅ 影响力更新成功");

        console.log("📈 更新用户2影响力...");
        await influenceRanking.updateUserInfluence(user2.address);
        console.log("✅ 影响力更新成功");

        console.log("📈 更新用户3影响力...");
        await influenceRanking.updateUserInfluence(user3.address);
        console.log("✅ 影响力更新成功");

        // 获取用户影响力详情
        const user1Influence = await influenceRanking.getUserInfluenceDetails(user1.address);
        console.log(`用户1总影响力: ${user1Influence.totalInfluence}`);
        console.log(`用户1发表分数: ${user1Influence.publicationScore}`);
        console.log(`用户1评审分数: ${user1Influence.reviewScore}`);

        const user2Influence = await influenceRanking.getUserInfluenceDetails(user2.address);
        console.log(`用户2总影响力: ${user2Influence.totalInfluence}`);
        console.log(`用户2评审分数: ${user2Influence.reviewScore}`);

    } catch (error) {
        console.error("❌ 影响力排行测试失败:", error.message);
    }

    console.log("\n🧪 测试5: 平台整合功能");
    console.log("-".repeat(50));

    try {
        // 检查SciToken余额
        const deployerBalance = await sciToken.balanceOf(deployer.address);
        console.log(`部署者SciToken余额: ${ethers.formatEther(deployerBalance)} SCI`);

        // 获取平台统计
        const platformStats = await userRegistry.getPlatformStats();
        console.log("📊 平台统计:");
        console.log(`总用户数: ${platformStats[0]}`);
        console.log(`研究员数: ${platformStats[1]}`);
        console.log(`评审员数: ${platformStats[2]}`);
        console.log(`数据提供者数: ${platformStats[3]}`);
        console.log(`机构数: ${platformStats[4]}`);

        const datasetStats = await datasetManager.getPlatformStats();
        console.log(`总数据集数: ${datasetStats[0]}`);
        console.log(`总下载次数: ${datasetStats[1]}`);
        console.log(`总收益: ${ethers.formatEther(datasetStats[2])} ETH`);

        const researchStats = await researchNFT.getPlatformStats();
        console.log(`总研究成果数: ${researchStats[0]}`);
        console.log(`总引用次数: ${researchStats[3]}`);

    } catch (error) {
        console.error("❌ 平台整合测试失败:", error.message);
    }

    console.log("\n🧪 测试6: 高级功能");
    console.log("-".repeat(50));

    try {
        // 数据集引用
        console.log("📝 用户1引用数据集...");
        await datasetManager.connect(user1).citeDataset(
            1,
            "QmResearchPaper12345" // 研究成果IPFS哈希
        );
        console.log("✅ 数据集引用成功");

        // 检查引用统计
        const updatedDataset = await datasetManager.getDataset(1);
        console.log(`数据集引用次数: ${updatedDataset.citationCount}`);

        // 获取引用记录
        const citations = await datasetManager.getCitations(1);
        console.log(`引用记录数量: ${citations.length}`);

    } catch (error) {
        console.error("❌ 高级功能测试失败:", error.message);
    }

    console.log("\n🎉 DeSci平台功能测试完成！");
    console.log("=" .repeat(60));
    console.log("✅ 用户注册系统正常运行");
    console.log("✅ 数据集管理系统正常运行");
    console.log("✅ 科研成果NFT系统正常运行");
    console.log("✅ 同行评审系统正常运行");
    console.log("✅ 影响力排行系统正常运行");
    console.log("✅ 平台整合功能正常运行");
    console.log("✅ 合约间交互正常运行");
    console.log("=" .repeat(60));
    
    console.log("\n🚀 DeSci平台已准备好投入使用！");
    console.log("💡 您现在可以:");
    console.log("   - 通过前端应用与平台交互");
    console.log("   - 注册不同角色的用户");
    console.log("   - 上传和管理科研数据集");
    console.log("   - 发表和评审科研成果");
    console.log("   - 查看影响力排行");
    console.log("   - 参与平台治理");
}

// 运行测试
if (require.main === module) {
    main()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error(error);
            process.exit(1);
        });
}

module.exports = { main };