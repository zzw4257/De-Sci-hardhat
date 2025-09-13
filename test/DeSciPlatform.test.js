const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DeSciPlatform Integration", function () {
  let userProfile, zkProof, nft, dataset, influenceRanking, platform;
  let owner, user1, user2, user3;

  beforeEach(async function () {
    [owner, user1, user2, user3] = await ethers.getSigners();

    // 部署所有合约
    // 使用DeSciRegistry而不是UserProfile
    const DeSciRegistry = await ethers.getContractFactory("DeSciRegistry");
    userProfile = await DeSciRegistry.deploy();
    await userProfile.waitForDeployment();

    const ZKProof = await ethers.getContractFactory("ZKProof");
    zkProof = await ZKProof.deploy();
    await zkProof.waitForDeployment();

    // 使用ResearchNFT而不是DeSciNFTSimple
    const ResearchNFT = await ethers.getContractFactory("ResearchNFT");
    nft = await ResearchNFT.deploy();
    await nft.waitForDeployment();

    const Dataset = await ethers.getContractFactory("DatasetManager");
    dataset = await Dataset.deploy();
    await dataset.waitForDeployment();

    const InfluenceRanking = await ethers.getContractFactory("InfluenceRanking");
    influenceRanking = await InfluenceRanking.deploy(
      await userProfile.getAddress(),
      await dataset.getAddress(),
      await nft.getAddress(),
      await zkProof.getAddress()
    );
    await influenceRanking.waitForDeployment();

    const DeSciPlatform = await ethers.getContractFactory("DeSciPlatform");
    platform = await DeSciPlatform.deploy(
      await userProfile.getAddress(),
      await dataset.getAddress(),
      await nft.getAddress(), // 这里需要是payable地址
      await influenceRanking.getAddress(),
      await zkProof.getAddress()
    );
    await platform.waitForDeployment();

    // 设置权限
    await nft.addAuthorizedContract(await platform.getAddress());
    // 使用正确的函数名
    await userProfile.grantRole(await userProfile.ADMIN_ROLE(), await platform.getAddress());
    // 移除不存在的函数调用
    // await dataset.authorizeRegistrar(await platform.getAddress());

    // 为平台提供资金用于奖励
    await owner.sendTransaction({
      to: await platform.getAddress(),
      value: ethers.parseEther("1.0")
    });

    // 创建测试用户档案
    await userProfile.connect(user1).registerUser(
      "Dr. Alice Researcher",
      "MIT",
      "alice@university.edu",
      "Machine Learning, AI",
      "QmAlice123",
      1 // Researcher
    );
    // 验证用户
    const VERIFIER_ROLE = await userProfile.VERIFIER_ROLE();
    await userProfile.grantRole(VERIFIER_ROLE, owner.address);
    const pendingRequests = await userProfile.getPendingVerificationRequests();
    if (pendingRequests.length > 0) {
      await userProfile.processVerificationRequest(pendingRequests[0], true, "Verified");
    }

    await userProfile.connect(user2).registerUser(
      "Dr. Bob Reviewer",
      "Stanford University",
      "bob@institute.org",
      "Computer Science, Cryptography",
      "QmBob456",
      2 // Reviewer
    );
    // 验证用户2
    const pendingRequests2 = await userProfile.getPendingVerificationRequests();
    if (pendingRequests2.length > 0) {
      await userProfile.processVerificationRequest(pendingRequests2[pendingRequests2.length-1], true, "Verified");
    }

    await userProfile.connect(user3).registerUser(
      "Dr. Carol Peer",
      "Data Corp",
      "carol@lab.com",
      "Data Science",
      "QmCarol789",
      3 // DataProvider
    );
    // 验证用户3
    const pendingRequests3 = await userProfile.getPendingVerificationRequests();
    if (pendingRequests3.length > 0) {
      await userProfile.processVerificationRequest(pendingRequests3[pendingRequests3.length-1], true, "Verified");
    }
    
    // 更新声誉
    await userProfile.updateReputation(user1.address, 500, "Good work");
    await userProfile.updateReputation(user2.address, 600, "Excellent reviews");
    await userProfile.updateReputation(user3.address, 400, "Good contributions");
  });

  describe("Step-by-step Debug Tests", function () {
    it("应该能够验证用户注册状态", async function () {
      // 测试用户注册状态
      expect(await userProfile.isRegistered(user1.address)).to.be.true;
      const profile = await userProfile.getUserProfile(user1.address);
      expect(profile.status).to.equal(1); // Verified
    });

    it("应该能够直接调用DatasetManager.uploadDataset", async function () {
      // 直接测试DatasetManager功能
      await expect(
        dataset.connect(user1).uploadDataset(
          "Test Dataset",
          "Test Description",
          [],
          0, // Experimental
          1000,
          "QmTestDataHash",
          "QmTestMetadata",
          "",
          0, // Public
          0
        )
      ).to.not.be.reverted;
    });

    it("应该能够直接调用ResearchNFT.mintResearch", async function () {
      // 直接测试ResearchNFT功能
      const authors = [user1.address];
      const shares = [10000];
      
      await expect(
        nft.connect(user1).mintResearch(
          authors,
          shares,
          "Test Research",
          "Test Abstract",
          [],
          [],
          0, // Paper
          "QmTestDataHash",
          "QmTestMetadata",
          true,
          0,
          "QmTestURI"
        )
      ).to.not.be.reverted;
    });

    it("应该能够在DeSciPlatform中分步测试publishResearch", async function () {
      // 分步测试DeSciPlatform功能
      // 1. 验证用户状态
      expect(await userProfile.isRegistered(user1.address)).to.be.true;
      const profile = await userProfile.getUserProfile(user1.address);
      expect(profile.status).to.equal(1); // Verified
      
      // 2. 测试参数
      const title = "Test Research";
      const abstract = "Test Abstract";
      const datasetName = "Test Dataset";
      const datasetDescription = "Test Dataset Description";
      const dataHash = "QmTestDataHash";
      const metadataHash = "QmTestMetadata";
      const zkProofIds = [];
      const isPublicDataset = true;
      const datasetPrice = 0;
      
      // 3. 调用publishResearch
      try {
        await platform.connect(user1).publishResearch(
          title,
          abstract,
          datasetName,
          datasetDescription,
          dataHash,
          metadataHash,
          zkProofIds,
          isPublicDataset,
          datasetPrice
        );
      } catch (error) {
        console.log("Error in publishResearch:", error.message);
        throw error;
      }
    });
    
    it("应该能够使用publishResearchWithReward函数", async function () {
      // 测试publishResearchWithReward函数
      // 1. 验证用户状态
      expect(await userProfile.isRegistered(user1.address)).to.be.true;
      const profile = await userProfile.getUserProfile(user1.address);
      expect(profile.status).to.equal(1); // Verified
      
      // 2. 准备参数
      const authors = [user1.address];
      const shares = [10000];
      const title = "Test Research";
      const abstract = "Test Abstract";
      const keywords = [];
      const fields = ["General"];
      const contentHash = "QmTestDataHash";
      const metadataHash = "QmTestMetadata";
      const isPublic = true;
      const price = 0;
      const tokenURI = "";
      
      // 3. 调用publishResearchWithReward
      await expect(
        platform.connect(user1).publishResearchWithReward(
          authors,
          shares,
          title,
          abstract,
          keywords,
          fields,
          0, // Paper
          contentHash,
          metadataHash,
          isPublic,
          price,
          tokenURI
        )
      ).to.not.be.reverted;
    });
  });
});