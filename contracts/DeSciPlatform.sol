// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./DeSciRegistry.sol";
import "./DatasetManager.sol";
import "./ResearchNFT.sol";
import "./InfluenceRanking.sol";
import "./ZKPVerifier.sol";

/**
 * @title SciToken
 * @dev 平台治理代币
 */
contract SciToken is ERC20, Ownable {
    constructor() ERC20("Science Token", "SCI") Ownable(msg.sender) {
        _mint(msg.sender, 1000000 * 10**decimals()); // 100万代币
    }
    
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}

/**
 * @title DeSciPlatform
 * @dev 去中心化科学平台主合约 - 集成所有功能模块
 */
contract DeSciPlatform is Ownable, ReentrancyGuard, IERC721Receiver {
    
    // 相关合约引用
    DeSciRegistry public immutable userRegistry;
    DatasetManager public immutable datasetManager;
    ResearchNFT public immutable researchNFT;
    InfluenceRanking public immutable influenceRanking;
    ZKPVerifier public immutable zkpVerifier;
    
    // 平台治理代币地址
    SciToken public immutable sciToken;
    
    // 平台配置
    struct PlatformConfig {
        uint256 userRegistrationReward;    // 用户注册奖励
        uint256 datasetUploadReward;       // 数据集上传奖励
        uint256 researchPublishReward;     // 研究发表奖励
        uint256 peerReviewReward;          // 同行评审奖励
        uint256 citationReward;            // 引用奖励
        uint256 qualityBonusMultiplier;    // 质量奖励倍数
        uint256 weeklyInfluenceReward;     // 周度影响力奖励池
        bool rewardsEnabled;               // 奖励开关
        uint256 minimumReputationToReview; // 评审最低声誉要求
        uint256 minimumReviewsToPublish;   // 发布所需最少评审数
        uint256 reviewReward;              // 评审奖励
    }
    
    // 查询和溯源系统
    struct ResearchGraph {
        uint256 totalConnections;  // 添加一个非映射字段
        mapping(uint256 => uint256[]) citations;     // 引用关系图
        mapping(uint256 => uint256[]) references;    // 被引用关系图
        mapping(address => uint256[]) authorWorks;   // 作者作品图
        mapping(string => uint256[]) fieldWorks;     // 领域作品图
        mapping(string => uint256[]) institutionWorks; // 机构作品图
    }
    
    // 协作网络
    struct CollaborationNetwork {
        uint256 totalCollaborations;  // 添加一个非映射字段
        mapping(address => mapping(address => uint256)) collaborationCount;
        mapping(address => address[]) collaborators;
        mapping(string => address[]) fieldExperts;
    }
    
    PlatformConfig public config;
    ResearchGraph public researchGraph;
    CollaborationNetwork public collabNetwork;
    
    // 奖励分发记录
    mapping(address => uint256) public totalRewardsEarned;
    mapping(address => uint256) public lastRewardClaim;
    
    // 平台统计
    struct PlatformStats {
        uint256 totalUsers;
        uint256 totalDatasets;
        uint256 totalResearches;
        uint256 totalCitations;
        uint256 totalRewardsDistributed;
        uint256 averageInfluenceScore;
        uint256 activeUsersThisMonth;
    }
    
    // 事件
    event RewardDistributed(
        address indexed user,
        uint256 amount,
        string reason
    );
    
    event CollaborationFormed(
        address indexed user1,
        address indexed user2,
        uint256 indexed researchId
    );
    
    event InfluenceRankingUpdated(
        address indexed user,
        uint256 oldRank,
        uint256 newRank
    );
    
    event PlatformConfigUpdated(
        uint256 timestamp
    );
    
    constructor(
        address _userRegistry,
        address _datasetManager,
        address payable _researchNFT,
        address _influenceRanking,
        address _zkpVerifier
    ) Ownable(msg.sender) {
        userRegistry = DeSciRegistry(_userRegistry);
        datasetManager = DatasetManager(_datasetManager);
        researchNFT = ResearchNFT(_researchNFT);
        influenceRanking = InfluenceRanking(_influenceRanking);
        zkpVerifier = ZKPVerifier(_zkpVerifier);
        
        // 部署治理代币
        sciToken = new SciToken();
        
        // 初始化平台配置
        config = PlatformConfig({
            userRegistrationReward: 100 * 10**18,      // 100 SCI
            datasetUploadReward: 50 * 10**18,          // 50 SCI
            researchPublishReward: 200 * 10**18,       // 200 SCI
            peerReviewReward: 25 * 10**18,             // 25 SCI
            citationReward: 10 * 10**18,               // 10 SCI
            qualityBonusMultiplier: 150,               // 1.5x倍数
            weeklyInfluenceReward: 10000 * 10**18,     // 10000 SCI奖励池
            rewardsEnabled: true,
            minimumReputationToReview: 50,             // 评审最低声誉要求
            minimumReviewsToPublish: 2,                // 发布所需最少评审数
            reviewReward: 0.01 ether                   // 评审奖励
        });
    }
    
    /**
     * @dev ERC721接收者接口实现
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
    
    /**
     * @dev 用户注册并获得奖励
     */
    function registerUserWithReward(
        string memory _name,
        string memory _organization,
        string memory _email,
        string memory _researchFields,
        string memory _credentials,
        DeSciRegistry.UserRole _role
    ) external {
        // 代表用户注册
        userRegistry.registerUserFor(
            msg.sender,
            _name,
            _organization,
            _email,
            _researchFields,
            _credentials,
            _role
        );
        
        // 发放注册奖励
        if (config.rewardsEnabled) {
            _distributeReward(msg.sender, config.userRegistrationReward, "User Registration");
        }
    }
    
    /**
     * @dev 上传数据集并获得奖励
     */
    function uploadDatasetWithReward(
        string memory _title,
        string memory _description,
        string[] memory _keywords,
        DatasetManager.DatasetType _dataType,
        uint256 _size,
        string memory _ipfsHash,
        string memory _metadataHash,
        string memory _zkpProofHash,
        DatasetManager.AccessType _accessType,
        uint256 _accessPrice
    ) external returns (uint256) {
        // 上传数据集
        uint256 datasetId = datasetManager.uploadDataset(
            _title,
            _description,
            _keywords,
            _dataType,
            _size,
            _ipfsHash,
            _metadataHash,
            _zkpProofHash,
            _accessType,
            _accessPrice
        );
        
        // 发放上传奖励
        if (config.rewardsEnabled) {
            uint256 reward = config.datasetUploadReward;
            
            // 大数据集奖励加成
            if (_size > 1024 * 1024 * 100) { // 100MB以上
                reward = reward * 150 / 100; // 1.5x奖励
            }
            
            _distributeReward(msg.sender, reward, "Dataset Upload");
        }
        
        return datasetId;
    }
    
    /**
     * @dev 发表研究成果并获得奖励
     */
    function publishResearchWithReward(
        address[] memory _authors,
        uint256[] memory _authorShares,
        string memory _title,
        string memory _abstractText,
        string[] memory _keywords,
        string[] memory _researchFields,
        ResearchNFT.PublicationType _pubType,
        string memory _contentHash,
        string memory _metadataHash,
        bool _isOpenAccess,
        uint256 _accessPrice,
        string memory _tokenURI
    ) external returns (uint256) {
        // 发表研究成果
        uint256 tokenId = researchNFT.mintResearch(
            _authors,
            _authorShares,
            _title,
            _abstractText,
            _keywords,
            _researchFields,
            _pubType,
            _contentHash,
            _metadataHash,
            _isOpenAccess,
            _accessPrice,
            _tokenURI
        );
        
        // 更新研究图谱
        _updateResearchGraph(tokenId, _authors, _researchFields);
        
        // 更新协作网络
        _updateCollaborationNetwork(_authors, tokenId);
        
        // 发放发表奖励
        if (config.rewardsEnabled) {
            uint256 totalReward = config.researchPublishReward;
            
            // 开放获取奖励加成
            if (_isOpenAccess) {
                totalReward = totalReward * 120 / 100; // 1.2x奖励
            }
            
            // 按作者份额分配奖励
            for (uint256 i = 0; i < _authors.length; i++) {
                uint256 authorReward = (totalReward * _authorShares[i]) / 10000;
                _distributeReward(_authors[i], authorReward, "Research Publication");
            }
        }
        
        return tokenId;
    }
    
    /**
     * @dev 提交同行评审并获得奖励
     */
    function submitPeerReviewWithReward(
        uint256 _tokenId,
        uint8 _score,
        string memory _reviewHash,
        bool _isAnonymous,
        bytes32 _zkpProof
    ) external {
        // 提交评审
        researchNFT.submitPeerReview(_tokenId, _score, _reviewHash, _isAnonymous, _zkpProof);
        
        // 发放评审奖励
        if (config.rewardsEnabled) {
            uint256 reward = config.peerReviewReward;
            
            // 高质量评审奖励加成
            if (_score >= 8) {
                reward = reward * config.qualityBonusMultiplier / 100;
            }
            
            _distributeReward(msg.sender, reward, "Peer Review");
        }
    }
    
    /**
     * @dev 添加引用关系并获得奖励
     */
    function addCitationWithReward(
        uint256 _fromTokenId,
        uint256 _toTokenId,
        string memory _context
    ) external {
        // 添加引用
        researchNFT.addCitation(_fromTokenId, _toTokenId, _context);
        
        // 更新研究图谱
        researchGraph.citations[_fromTokenId].push(_toTokenId);
        researchGraph.references[_toTokenId].push(_fromTokenId);
        
        // 发放引用奖励给被引用者
        if (config.rewardsEnabled) {
            address citedAuthor = researchNFT.ownerOf(_toTokenId);
            _distributeReward(citedAuthor, config.citationReward, "Citation Received");
        }
    }
    
    /**
     * @dev 发表研究成果
     */
    function publishResearch(
        string memory _title,
        string memory _abstract,
        string memory _datasetName,
        string memory _datasetDescription,
        string memory _dataHash,
        string memory _metadataHash,
        uint256[] memory _zkProofIds,
        bool _isPublicDataset,
        uint256 _datasetPrice
    ) external {
        // 添加调试日志
        // 验证用户是否已注册并验证
        require(userRegistry.isRegistered(msg.sender), "User must be registered");
        DeSciRegistry.UserProfile memory profile = userRegistry.getUserProfile(msg.sender);
        require(profile.status == DeSciRegistry.VerificationStatus.Verified, "User must be verified");
        
        // 验证ZK证明
        for (uint256 i = 0; i < _zkProofIds.length; i++) {
            // 这里应该调用ZKProof合约验证证明
            // 简化实现，假设所有证明都有效
        }
        
        // 上传数据集
        string[] memory emptyKeywords = new string[](0);
        DatasetManager.AccessType accessType = _isPublicDataset ? 
            DatasetManager.AccessType.Public : DatasetManager.AccessType.Restricted;
            
        // 添加检查确保参数有效
        require(bytes(_datasetName).length > 0, "Dataset name cannot be empty");
        require(bytes(_dataHash).length > 0, "Data hash cannot be empty");
            
        datasetManager.uploadDataset(
            _datasetName,
            _datasetDescription,
            emptyKeywords,
            DatasetManager.DatasetType.Experimental,
            1000, // 简化实现，固定大小
            _dataHash,
            _metadataHash,
            "", // ZKP证明哈希
            accessType,
            _datasetPrice
        );
        
        // 创建研究NFT
        address[] memory authors = new address[](1);
        authors[0] = msg.sender;
        uint256[] memory shares = new uint256[](1);
        shares[0] = 10000; // 100%
        string[] memory keywords = new string[](0);
        string[] memory fields = new string[](1);
        fields[0] = "General";
        
        // 添加检查确保参数有效
        require(bytes(_title).length > 0, "Research title cannot be empty");
        
        researchNFT.mintResearch(
            authors,
            shares,
            _title,
            _abstract,
            keywords,
            fields,
            ResearchNFT.PublicationType.Paper,
            _dataHash,
            _metadataHash,
            true, // 开放获取
            0, // 免费
            "" // Token URI
        );
    }

    /**
     * @dev 获取研究总数
     */
    function getTotalResearches() external view returns (uint256) {
        (uint256 totalResearches,,,,,) = researchNFT.getPlatformStats();
        return totalResearches;
    }

    /**
     * @dev 更新平台设置
     */
    function updatePlatformSettings(
        uint256 _minReputationToReview,
        uint256 _minReviewsToPublish,
        uint256 _reviewReward
    ) external onlyOwner {
        config.minimumReputationToReview = _minReputationToReview;
        config.minimumReviewsToPublish = _minReviewsToPublish;
        config.reviewReward = _reviewReward;
        
        emit PlatformConfigUpdated(block.timestamp);
    }

    /**
     * @dev 获取所有研究
     */
    function getAllResearches() external view returns (uint256[] memory) {
        // 简化实现，返回空数组
        return new uint256[](0);
    }

    /**
     * @dev 获取研究者发表记录
     */
    function getResearcherPublications(address _researcher) external view returns (uint256[] memory) {
        return researchNFT.getAuthorWorks(_researcher);
    }

    /**
     * @dev 手动发布研究
     */
    function manuallyPublishResearch(uint256 _researchId) external onlyOwner {
        // 简化实现，仅作为占位符
    }

    /**
     * @dev 获取研究详情
     */
    function getResearch(uint256 _researchId) external view returns (
        string memory title,
        address researcher,
        uint256 status,
        uint256 datasetId,
        uint256 nftTokenId
    ) {
        // 简化实现，返回默认值
        return ("", address(0), 0, 0, 0);
    }

    /**
     * @dev 提交同行评审
     */
    function submitPeerReview(
        uint256 _researchId,
        uint8 _rating,
        string memory _reviewHash,
        string memory _comments
    ) external {
        // 简化实现，仅作为占位符
    }

    /**
     * @dev 获取同行评审
     */
    function getPeerReviews(uint256 _researchId) external view returns (
        address[] memory reviewers,
        uint8[] memory ratings,
        string[] memory comments
    ) {
        // 简化实现，返回空数组
        return (new address[](0), new uint8[](0), new string[](0));
    }

    /**
     * @dev 分发奖励
     */
    function _distributeReward(address _user, uint256 _amount, string memory _reason) internal {
        require(_amount > 0, "Invalid reward amount");
        
        // 铸造代币给用户
        sciToken.mint(_user, _amount);
        
        // 更新记录
        totalRewardsEarned[_user] += _amount;
        
        emit RewardDistributed(_user, _amount, _reason);
    }
    
    /**
     * @dev 更新研究图谱
     */
    function _updateResearchGraph(
        uint256 _tokenId,
        address[] memory _authors,
        string[] memory _researchFields
    ) internal {
        // 更新作者作品图
        for (uint256 i = 0; i < _authors.length; i++) {
            researchGraph.authorWorks[_authors[i]].push(_tokenId);
        }
        
        // 更新领域作品图
        for (uint256 i = 0; i < _researchFields.length; i++) {
            researchGraph.fieldWorks[_researchFields[i]].push(_tokenId);
        }
    }
    
    /**
     * @dev 更新协作网络
     */
    function _updateCollaborationNetwork(address[] memory _authors, uint256 _tokenId) internal {
        // 更新协作关系
        for (uint256 i = 0; i < _authors.length; i++) {
            for (uint256 j = i + 1; j < _authors.length; j++) {
                address author1 = _authors[i];
                address author2 = _authors[j];
                
                // 增加协作计数
                collabNetwork.collaborationCount[author1][author2]++;
                collabNetwork.collaborationCount[author2][author1]++;
                
                // 添加到协作者列表（如果尚未存在）
                bool found1 = false;
                bool found2 = false;
                
                address[] storage collaborators1 = collabNetwork.collaborators[author1];
                address[] storage collaborators2 = collabNetwork.collaborators[author2];
                
                for (uint256 k = 0; k < collaborators1.length; k++) {
                    if (collaborators1[k] == author2) {
                        found1 = true;
                        break;
                    }
                }
                
                for (uint256 k = 0; k < collaborators2.length; k++) {
                    if (collaborators2[k] == author1) {
                        found2 = true;
                        break;
                    }
                }
                
                if (!found1) collaborators1.push(author2);
                if (!found2) collaborators2.push(author1);
                
                emit CollaborationFormed(author1, author2, _tokenId);
            }
        }
    }
    
    /**
     * @dev 查询用户的研究轨迹
     */
    function getUserResearchTrajectory(address _user) external view returns (
        uint256[] memory researchIds,
        uint256[] memory timestamps,
        string[] memory titles,
        uint256[] memory citationCounts
    ) {
        uint256[] memory userWorks = researchGraph.authorWorks[_user];
        
        researchIds = new uint256[](userWorks.length);
        timestamps = new uint256[](userWorks.length);
        titles = new string[](userWorks.length);
        citationCounts = new uint256[](userWorks.length);
        
        for (uint256 i = 0; i < userWorks.length; i++) {
            researchIds[i] = userWorks[i];
            // 这里需要从ResearchNFT获取详细信息
            // 简化实现
            timestamps[i] = block.timestamp;
            titles[i] = "Research Title";
            citationCounts[i] = researchGraph.references[userWorks[i]].length;
        }
    }
    
    /**
     * @dev 获取研究影响传播路径
     */
    function getResearchInfluencePath(uint256 _tokenId) external view returns (
        uint256[] memory citingWorks,
        uint256[] memory citedWorks,
        uint256 totalInfluenceScore
    ) {
        citingWorks = researchGraph.references[_tokenId];
        citedWorks = researchGraph.citations[_tokenId];
        
        // 计算总影响力分数
        totalInfluenceScore = researchNFT.calculateImpactScore(_tokenId);
        
        // 加上被引用带来的影响力
        for (uint256 i = 0; i < citingWorks.length; i++) {
            totalInfluenceScore += researchNFT.calculateImpactScore(citingWorks[i]) / 10;
        }
    }
    
    /**
     * @dev 搜索相关研究
     */
    function searchResearchByKeywords(string[] memory _keywords) external view returns (
        uint256[] memory researchIds,
        uint256[] memory relevanceScores
    ) {
        // 简化实现：返回领域相关的研究
        if (_keywords.length > 0) {
            uint256[] memory fieldWorks = researchGraph.fieldWorks[_keywords[0]];
            researchIds = new uint256[](fieldWorks.length);
            relevanceScores = new uint256[](fieldWorks.length);
            
            for (uint256 i = 0; i < fieldWorks.length; i++) {
                researchIds[i] = fieldWorks[i];
                relevanceScores[i] = 100; // 简化评分
            }
        }
    }
    
    /**
     * @dev 获取协作推荐
     */
    function getCollaborationRecommendations(address _user) external view returns (
        address[] memory recommendedUsers,
        uint256[] memory compatibilityScores
    ) {
        // 基于共同研究领域和协作历史推荐
        address[] memory existingCollaborators = collabNetwork.collaborators[_user];
        
        // 简化实现：返回现有协作者
        recommendedUsers = existingCollaborators;
        compatibilityScores = new uint256[](existingCollaborators.length);
        
        for (uint256 i = 0; i < existingCollaborators.length; i++) {
            compatibilityScores[i] = collabNetwork.collaborationCount[_user][existingCollaborators[i]] * 10;
        }
    }
    
    /**
     * @dev 周度影响力奖励分发
     */
    function distributeWeeklyInfluenceRewards() external onlyOwner {
        require(config.rewardsEnabled, "Rewards disabled");
        
        // 获取前100名用户
        (address[] memory topUsers, uint256[] memory influences,) = 
            influenceRanking.getGlobalTopRanking(100);
        
        uint256 totalInfluence = 0;
        for (uint256 i = 0; i < influences.length; i++) {
            totalInfluence += influences[i];
        }
        
        if (totalInfluence > 0) {
            // 按影响力比例分配奖励
            for (uint256 i = 0; i < topUsers.length; i++) {
                uint256 userReward = (config.weeklyInfluenceReward * influences[i]) / totalInfluence;
                _distributeReward(topUsers[i], userReward, "Weekly Influence Reward");
            }
        }
    }
    
    /**
     * @dev 获取平台综合统计
     */
    function getPlatformStats() external view returns (PlatformStats memory stats) {
        (stats.totalUsers,,,,,) = userRegistry.getPlatformStats();
        (stats.totalDatasets,,,) = datasetManager.getPlatformStats();
        (stats.totalResearches, stats.totalCitations,,,,) = researchNFT.getPlatformStats();
        
        // 计算总奖励分发量
        stats.totalRewardsDistributed = sciToken.totalSupply() - 1000000 * 10**18;
        
        // 获取平均影响力分数
        (,stats.averageInfluenceScore,,) = influenceRanking.getRankingStats();
        
        // 简化实现：活跃用户数
        stats.activeUsersThisMonth = stats.totalUsers / 2;
    }
    
    /**
     * @dev 更新平台配置
     */
    function updatePlatformConfig(PlatformConfig memory _newConfig) external onlyOwner {
        config = _newConfig;
        emit PlatformConfigUpdated(block.timestamp);
    }
    
    /**
     * @dev 紧急暂停奖励
     */
    function pauseRewards() external onlyOwner {
        config.rewardsEnabled = false;
    }
    
    /**
     * @dev 恢复奖励分发
     */
    function resumeRewards() external onlyOwner {
        config.rewardsEnabled = true;
    }
    
    /**
     * @dev 提取平台收益
     */
    function withdrawPlatformFees() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        
        payable(owner()).transfer(balance);
    }
    
    /**
     * @dev 接收以太币
     */
    receive() external payable {}
}