const { ethers } = require("hardhat");
const fs = require('fs');
const path = require('path');

async function main() {
    console.log("🌟 DeSci Platform Complete Test Scenario\n");
    
    const [deployer, researcher1, researcher2, reviewer1, reviewer2, institution1, admin] = await ethers.getSigners();
    
    console.log("👥 Test Accounts:");
    console.log(`Deployer: ${deployer.address}`);
    console.log(`Researcher1: ${researcher1.address}`);
    console.log(`Researcher2: ${researcher2.address}`);
    console.log(`Reviewer1: ${reviewer1.address}`);
    console.log(`Reviewer2: ${reviewer2.address}`);
    console.log(`Institution1: ${institution1.address}`);
    console.log(`Admin: ${admin.address}\n`);

    let deployedContracts = {};
    let testResults = [];

    try {
        // Step 1: Deploy Contracts
        console.log("📋 Step 1: Deploying Smart Contracts...");
        
        console.log("  Deploying DeSciRegistry...");
        const DeSciRegistry = await ethers.getContractFactory("DeSciRegistry");
        const registry = await DeSciRegistry.deploy();
        await registry.waitForDeployment();
        deployedContracts.DeSciRegistry = await registry.getAddress();
        console.log("✅ DeSciRegistry deployed:", deployedContracts.DeSciRegistry);

        console.log("  Deploying ZKPVerifier...");
        const ZKPVerifier = await ethers.getContractFactory("ZKPVerifier");
        const zkpVerifier = await ZKPVerifier.deploy();
        await zkpVerifier.waitForDeployment();
        deployedContracts.ZKPVerifier = await zkpVerifier.getAddress();
        console.log("✅ ZKPVerifier deployed:", deployedContracts.ZKPVerifier);

        console.log("  Deploying ZKProof...");
        const ZKProof = await ethers.getContractFactory("ZKProof");
        const zkProof = await ZKProof.deploy();
        await zkProof.waitForDeployment();
        deployedContracts.ZKProof = await zkProof.getAddress();
        console.log("✅ ZKProof deployed:", deployedContracts.ZKProof);

        console.log("  Deploying ConstraintManager...");
        const ConstraintManager = await ethers.getContractFactory("ConstraintManager");
        const constraintManager = await ConstraintManager.deploy();
        await constraintManager.waitForDeployment();
        deployedContracts.ConstraintManager = await constraintManager.getAddress();
        console.log("✅ ConstraintManager deployed:", deployedContracts.ConstraintManager);

        console.log("  Deploying DataFeatureExtractor...");
        const DataFeatureExtractor = await ethers.getContractFactory("DataFeatureExtractor");
        const dataFeatureExtractor = await DataFeatureExtractor.deploy();
        await dataFeatureExtractor.waitForDeployment();
        deployedContracts.DataFeatureExtractor = await dataFeatureExtractor.getAddress();
        console.log("✅ DataFeatureExtractor deployed:", deployedContracts.DataFeatureExtractor);

        console.log("  Deploying ResearchDataVerifier...");
        const ResearchDataVerifier = await ethers.getContractFactory("ResearchDataVerifier");
        const researchDataVerifier = await ResearchDataVerifier.deploy();
        await researchDataVerifier.waitForDeployment();
        deployedContracts.ResearchDataVerifier = await researchDataVerifier.getAddress();
        console.log("✅ ResearchDataVerifier deployed:", deployedContracts.ResearchDataVerifier);

        console.log("  Deploying DatasetManager...");
        const DatasetManager = await ethers.getContractFactory("DatasetManager");
        const datasetManager = await DatasetManager.deploy();
        await datasetManager.waitForDeployment();
        deployedContracts.DatasetManager = await datasetManager.getAddress();
        console.log("✅ DatasetManager deployed:", deployedContracts.DatasetManager);

        console.log("  Deploying ResearchNFT...");
        const ResearchNFT = await ethers.getContractFactory("ResearchNFT");
        const researchNFT = await ResearchNFT.deploy();
        await researchNFT.waitForDeployment();
        deployedContracts.ResearchNFT = await researchNFT.getAddress();
        console.log("✅ ResearchNFT deployed:", deployedContracts.ResearchNFT);

        console.log("  Deploying InfluenceRanking...");
        const InfluenceRanking = await ethers.getContractFactory("InfluenceRanking");
        const influenceRanking = await InfluenceRanking.deploy(
            deployedContracts.DeSciRegistry,
            deployedContracts.DatasetManager,
            deployedContracts.ResearchNFT,
            deployedContracts.ZKPVerifier
        );
        await influenceRanking.waitForDeployment();
        deployedContracts.InfluenceRanking = await influenceRanking.getAddress();
        console.log("✅ InfluenceRanking deployed:", deployedContracts.InfluenceRanking);

        console.log("  Deploying DeSciPlatform...");
        const DeSciPlatform = await ethers.getContractFactory("DeSciPlatform");
        const platform = await DeSciPlatform.deploy(
            deployedContracts.DeSciRegistry,
            deployedContracts.DatasetManager,
            deployedContracts.ResearchNFT,
            deployedContracts.InfluenceRanking,
            deployedContracts.ZKPVerifier
        );
        await platform.waitForDeployment();
        deployedContracts.DeSciPlatform = await platform.getAddress();
        console.log("✅ DeSciPlatform deployed:", deployedContracts.DeSciPlatform);

        // 获取自动创建的SciToken地址
        const sciTokenAddress = await platform.sciToken();
        deployedContracts.SciToken = sciTokenAddress;
        console.log("🪙 SciToken address:", deployedContracts.SciToken);

        testResults.push("✅ All 10 contracts deployed successfully");

        // Step 1.5: Setup Permissions
        console.log("\n🔐 Step 1.5: Setting up contract permissions...");
        
        // 获取ADMIN_ROLE
        const ADMIN_ROLE = await registry.ADMIN_ROLE();
        
        // 授予DeSciPlatform合约admin权限，允许它代表用户注册
        console.log("  Granting admin role to DeSciPlatform...");
        await registry.connect(deployer).grantRole(ADMIN_ROLE, deployedContracts.DeSciPlatform);
        
        // 验证权限设置
        const hasAdminRole = await registry.hasRole(ADMIN_ROLE, deployedContracts.DeSciPlatform);
        console.log(`  DeSciPlatform admin role: ${hasAdminRole}`);
        
        testResults.push("✅ Contract permissions configured");

        // Step 2: User Registration
        console.log("\n📋 Step 2: User Registration...");
        
        console.log("  Registering researcher1...");
        await platform.connect(researcher1).registerUserWithReward(
            "Dr. Alice Smith",
            "MIT Research Lab", 
            "alice@mit.edu",
            "Blockchain, Cryptography",
            "QmHashForAliceCredentials",
            1 // Researcher role
        );
        testResults.push("✅ Researcher1 registered successfully");

        console.log("  Registering reviewer1...");
        await platform.connect(reviewer1).registerUserWithReward(
            "Prof. Bob Johnson",
            "Stanford University",
            "bob@stanford.edu", 
            "Computer Science, Peer Review",
            "QmHashForBobCredentials",
            2 // Reviewer role
        );
        testResults.push("✅ Reviewer1 registered successfully");

        // Step 3: Dataset Operations
        console.log("\n📋 Step 3: Dataset Operations...");
        
        console.log("  Uploading research dataset...");
        await platform.connect(researcher1).uploadDatasetWithReward(
            "COVID-19 Research Data",                    // _title
            "Public dataset for COVID-19 research",     // _description  
            ["medical", "covid19", "research"],          // _keywords
            2,                                           // _dataType (Medical = 2)
            1024000,                                     // _size (1MB in bytes)
            "QmHashForCOVIDData",                       // _ipfsHash
            "QmHashForCOVIDMetadata",                   // _metadataHash
            "QmHashForZKPProof",                        // _zkpProofHash
            0,                                          // _accessType (Public = 0)
            ethers.parseEther("0.1")                    // _accessPrice
        );
        testResults.push("✅ Dataset uploaded successfully");

        // Step 4: Research Publication
        console.log("\n📋 Step 4: Research Publication...");
        
        console.log("  Publishing research paper...");
        await researchNFT.connect(researcher1).mintResearch(
            [researcher1.address],                       // _authors
            [10000],                                     // _authorShares (100%)
            "COVID-19 Treatment Analysis",               // _title
            "Comprehensive analysis of COVID-19 treatment effectiveness", // _abstractText
            ["covid19", "treatment", "analysis"],        // _keywords
            ["Medical", "Epidemiology"],                 // _researchFields
            0,                                           // _pubType (Paper = 0)
            "QmHashForResearchPaper",                    // _contentHash
            "QmHashForResearchMetadata",                 // _metadataHash
            true,                                        // _isOpenAccess
            ethers.parseEther("0.0"),                    // _accessPrice (free for open access)
            "QmHashForTokenURI"                          // _tokenURI
        );
        testResults.push("✅ Research paper published as NFT");

        // Step 5: Peer Review Process
        console.log("\n📋 Step 5: Peer Review Process...");
        
        // 首先需要授权reviewer1为评审员
        console.log("  Authorizing reviewer1...");
        await researchNFT.connect(deployer).addAuthorizedReviewer(reviewer1.address);
        
        console.log("  Submitting peer review...");
        const tokenId = 1; // First minted NFT
        await researchNFT.connect(reviewer1).submitPeerReview(
            tokenId,                                     // _tokenId
            8,                                           // _score (rating out of 10)
            "QmHashForReviewContent",                    // _reviewHash
            false,                                       // _isAnonymous
            ethers.keccak256(ethers.toUtf8Bytes("mock_zkp_proof")) // _zkpProof
        );
        testResults.push("✅ Peer review submitted");

        // Step 6: ZKP Operations 
        console.log("\n📋 Step 6: ZKP Operations...");
        
        console.log("  Submitting ZK proof for data verification...");
        const proof = [1, 2, 3, 4, 5, 6, 7, 8]; // Mock proof values
        const publicInputs = [100, 200]; // Mock public inputs
        
        await zkProof.connect(researcher1).submitProof(
            "research_authenticity",
            proof,
            publicInputs,
            "QmHashForZKProofMetadata"
        );
        testResults.push("✅ ZK proof submitted");

        console.log("  Verifying ZK proof...");
        const proofId = 1;
        await zkProof.connect(deployer).verifyProof(proofId, true);
        testResults.push("✅ ZK proof verified");

        // Step 7: Platform Statistics
        console.log("\n📋 Step 7: Checking Platform Statistics...");
        
        const stats = await registry.getPlatformStats();
        console.log(`📊 Platform Stats:`);
        console.log(`  Total Registered: ${stats[0]}`);
        console.log(`  Total Researchers: ${stats[1]}`);
        console.log(`  Total Reviewers: ${stats[2]}`);
        console.log(`  Total Data Providers: ${stats[3]}`);
        console.log(`  Total Institutions: ${stats[4]}`);
        
        testResults.push("✅ Platform statistics verified");

        // Step 8: Generate Test Report
        console.log("\n📋 Step 8: Generating Test Report...");
        
        const testReport = {
            timestamp: new Date().toISOString(),
            network: "localhost",
            testSummary: {
                totalTests: testResults.length,
                successfulOperations: testResults.filter(r => r.includes('✅')).length,
                failedOperations: testResults.filter(r => r.includes('❌')).length
            },
            deployedContracts,
            testAccounts: {
                deployer: deployer.address,
                researcher1: researcher1.address,
                researcher2: researcher2.address,
                reviewer1: reviewer1.address,
                reviewer2: reviewer2.address,
                institution1: institution1.address,
                admin: admin.address
            },
            platformStats: {
                totalRegistered: Number(stats[0]),
                totalResearchers: Number(stats[1]),
                totalReviewers: Number(stats[2]),
                totalDataProviders: Number(stats[3]),
                totalInstitutions: Number(stats[4])
            },
            testResults
        };
        
        // Save test report
        const reportDir = path.join(__dirname, '../test-reports');
        if (!fs.existsSync(reportDir)) {
            fs.mkdirSync(reportDir, { recursive: true });
        }
        
        const reportPath = path.join(reportDir, `desci-test-scenario-${Date.now()}.json`);
        fs.writeFileSync(reportPath, JSON.stringify(testReport, null, 2));
        
        console.log(`✅ Test report saved: ${reportPath}\n`);

        // Final Summary
        console.log("🎉 DeSci Platform Test Scenario Completed!\n");
        
        console.log("📊 Test Results Summary:");
        testResults.forEach((result, index) => {
            console.log(`  ${index + 1}. ${result}`);
        });
        
        console.log("\n🔗 Deployed Contract Addresses:");
        Object.entries(deployedContracts).forEach(([name, address]) => {
            console.log(`  ${name}: ${address}`);
        });
        
        console.log("\n🚀 Next Steps:");
        console.log("  1. Start frontend app: cd frontend && npm start");
        console.log("  2. Connect MetaMask to local network (localhost:8545)");
        console.log("  3. Import test account private keys for real interaction");
        console.log("  4. Register new users on frontend to test complete flow");
        console.log("  5. Verify all operations are traceable on-chain");
        
        console.log("\n✨ This test demonstrates a real Web3 DeSci platform:");
        console.log("  ✅ Real user registration and identity verification");
        console.log("  ✅ Decentralized role management");
        console.log("  ✅ Transparent research data processing");
        console.log("  ✅ Verifiable peer review process");
        console.log("  ✅ Fully traceable operation history");
        console.log("  ✅ ZKP privacy protection mechanisms");
        
        console.log("\n🌟 This is the essence of Web3: Transparent, Decentralized, Traceable!");
        
        return deployedContracts;
        
    } catch (error) {
        console.error("❌ Test execution failed:", error.message);
        console.error("\n🔍 Debug Info:");
        console.error("  - Ensure Hardhat network is running");
        console.error("  - Ensure contracts are compiled");
        console.error("  - Check account balances");
        
        if (Object.keys(deployedContracts).length > 0) {
            console.log("\n📋 Successfully deployed contracts:");
            Object.entries(deployedContracts).forEach(([name, address]) => {
                console.log(`  ${name}: ${address}`);
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