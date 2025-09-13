// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./DeSciRegistry.sol";
import "./DatasetManager.sol";
import "./ResearchNFT.sol";
import "./ZKPVerifier.sol";

/**
 * @title InfluenceRanking
 * @dev 影响力排行系统 - 计算和管理研究者的综合影响力排名
 */
contract InfluenceRanking is Ownable, ReentrancyGuard {
    
    // 影响力维度
    struct InfluenceMetrics {
        uint256 publicationScore;      // 发表影响力
        uint256 reviewScore;           // 评审影响力
        uint256 dataContribution;      // 数据贡献
        uint256 collaborationScore;    // 协作影响力
        uint256 governanceScore;       // 治理贡献
        uint256 totalInfluence;       // 总影响力
        uint256 lastUpdateTime;       // 最后更新时间
        uint256 rank;                 // 排名
    }
    
    // 研究领域排名
    struct FieldRanking {
        mapping(address => uint256) userRanks;
        address[] topUsers;
        string fieldName;
    }
    
    // 机构排名
    struct InstitutionRanking {
        string name;
        uint256 totalInfluence;
        uint256 memberCount;
        uint256 avgInfluence;
        address[] members;
        uint256 rank;
    }
    
    // 排行榜类型
    enum RankingType {
        Global,         // 全球排名
        Field,          // 领域排名
        Institution,    // 机构排名
        Regional,       // 地区排名
        Trending        // 趋势排名
    }
    
    // 时间周期
    enum TimePeriod {
        AllTime,        // 历史总计
        Year,           // 年度
        Quarter,        // 季度
        Month,          // 月度
        Week            // 周度
    }
    
    // 相关合约引用
    DeSciRegistry public immutable userRegistry;
    DatasetManager public immutable datasetManager;
    ResearchNFT public immutable researchNFT;
    ZKPVerifier public immutable zkpVerifier;
    
    // 存储
    mapping(address => InfluenceMetrics) public userInfluence;
    mapping(string => FieldRanking) public fieldRankings;
    mapping(string => InstitutionRanking) public institutionRankings;
    mapping(TimePeriod => mapping(address => InfluenceMetrics)) public historicalInfluence;
    
    address[] public globalRanking;
    mapping(address => uint256) public globalRankPosition;
    
    // 影响力权重配置（总和为10000，即100%）
    uint256 public publicationWeight = 4000;    // 40%
    uint256 public reviewWeight = 2000;         // 20%
    uint256 public dataWeight = 2000;           // 20%
    uint256 public collaborationWeight = 1000;  // 10%
    uint256 public governanceWeight = 1000;     // 10%
    
    // 排名更新参数
    uint256 public rankingUpdateInterval = 24 hours;
    uint256 public lastGlobalUpdate;
    uint256 public maxRankingSize = 1000;
    
    // 影响力衰减参数
    uint256 public timeDecayRate = 50; // 每年衰减5%
    uint256 public constant DECAY_BASE = 10000;
    
    // 事件
    event InfluenceUpdated(
        address indexed user,
        uint256 oldInfluence,
        uint256 newInfluence,
        uint256 newRank
    );
    
    event RankingUpdated(
        RankingType rankingType,
        string identifier,
        uint256 timestamp
    );
    
    event WeightsUpdated(
        uint256 publicationWeight,
        uint256 reviewWeight,
        uint256 dataWeight,
        uint256 collaborationWeight,
        uint256 governanceWeight
    );
    
    constructor(
        address _userRegistry,
        address _datasetManager,
        address payable _researchNFT,
        address _zkpVerifier
    ) Ownable(msg.sender) {
        userRegistry = DeSciRegistry(_userRegistry);
        datasetManager = DatasetManager(_datasetManager);
        researchNFT = ResearchNFT(_researchNFT);
        zkpVerifier = ZKPVerifier(_zkpVerifier);
        
        lastGlobalUpdate = block.timestamp;
    }
    
    /**
     * @dev 计算用户的发表影响力
     */
    function calculatePublicationScore(address _user) public view returns (uint256) {
        uint256[] memory userWorks = researchNFT.getAuthorWorks(_user);
        uint256 totalScore = 0;
        
        for (uint256 i = 0; i < userWorks.length; i++) {
            uint256 tokenId = userWorks[i];
            uint256 impactScore = researchNFT.calculateImpactScore(tokenId);
            
            // 应用时间衰减
            uint256 decayedScore = _applyTimeDecay(impactScore, tokenId);
            totalScore += decayedScore;
        }
        
        return totalScore;
    }
    
    /**
     * @dev 计算用户的评审影响力
     */
    function calculateReviewScore(address _user) public view returns (uint256) {
        // 获取用户评审的所有研究
        uint256 totalScore = 0;
        uint256 reviewCount = 0;
        
        // 这里需要遍历所有研究，检查用户的评审记录
        // 简化实现，实际应用中可以通过事件或索引优化
        (uint256 totalResearches,,,,,) = researchNFT.getPlatformStats();
        
        for (uint256 i = 1; i <= totalResearches; i++) {
            try researchNFT.getPeerReviews(i) returns (ResearchNFT.PeerReview[] memory reviews) {
                for (uint256 j = 0; j < reviews.length; j++) {
                    if (reviews[j].reviewer == _user) {
                        // 评审质量分 = 评审分数 × 被评审研究的影响力 × 0.1
                        uint256 researchImpact = researchNFT.calculateImpactScore(i);
                        uint256 reviewQuality = (reviews[j].score * researchImpact) / 100;
                        totalScore += reviewQuality;
                        reviewCount++;
                    }
                }
            } catch {
                continue;
            }
        }
        
        // 考虑评审数量奖励
        if (reviewCount > 0) {
            totalScore = totalScore * (100 + reviewCount) / 100; // 每次评审增加1%奖励
        }
        
        return totalScore;
    }
    
    /**
     * @dev 计算用户的数据贡献分
     */
    function calculateDataContribution(address _user) public view returns (uint256) {
        uint256[] memory userDatasets = datasetManager.getUserDatasets(_user);
        uint256 totalScore = 0;
        
        for (uint256 i = 0; i < userDatasets.length; i++) {
            DatasetManager.Dataset memory dataset = datasetManager.getDataset(userDatasets[i]);
            
            // 数据集质量分
            uint256 qualityScore = uint256(dataset.quality) * 20; // 0-80分
            
            // 使用次数加分
            uint256 usageScore = dataset.downloadCount * 5;
            
            // 引用次数加分
            uint256 citationScore = dataset.citationCount * 10;
            
            // 数据大小加分（对数缩放）
            uint256 sizeScore = _log2(dataset.size / 1024) * 2; // 以KB为单位的对数
            
            uint256 datasetScore = qualityScore + usageScore + citationScore + sizeScore;
            totalScore += datasetScore;
        }
        
        return totalScore;
    }
    
    /**
     * @dev 计算协作影响力
     */
    function calculateCollaborationScore(address _user) public view returns (uint256) {
        uint256[] memory userWorks = researchNFT.getAuthorWorks(_user);
        uint256 collaborationScore = 0;
        
        for (uint256 i = 0; i < userWorks.length; i++) {
            // 获取合作者数量
            // 这里需要从ResearchNFT合约获取作者信息
            // 简化实现
            collaborationScore += 10; // 每个合作项目10分
        }
        
        // 跨机构合作奖励
        // 这里可以检查合作者的机构信息
        collaborationScore = collaborationScore * 110 / 100; // 10%奖励
        
        return collaborationScore;
    }
    
    /**
     * @dev 计算治理贡献分
     */
    function calculateGovernanceScore(address _user) public view returns (uint256) {
        // 这里可以集成DAO治理合约的数据
        // 简化实现，返回基础分数
        
        // 检查用户角色
        if (userRegistry.isRegistered(_user)) {
            DeSciRegistry.UserProfile memory profile = userRegistry.getUserProfile(_user);
            
            // 评审员和机构有额外治理权重
            if (profile.role == DeSciRegistry.UserRole.Reviewer || profile.role == DeSciRegistry.UserRole.Institution) {
                return 100;
            }
        }
        
        return 50; // 基础治理分
    }
    
    /**
     * @dev 更新用户影响力
     */
    function updateUserInfluence(address _user) public {
        require(userRegistry.isRegistered(_user), "User not registered");
        
        InfluenceMetrics storage metrics = userInfluence[_user];
        
        // 计算各维度分数
        uint256 pubScore = calculatePublicationScore(_user);
        uint256 revScore = calculateReviewScore(_user);
        uint256 dataScore = calculateDataContribution(_user);
        uint256 collabScore = calculateCollaborationScore(_user);
        uint256 govScore = calculateGovernanceScore(_user);
        
        // 计算加权总分
        uint256 newInfluence = (
            pubScore * publicationWeight +
            revScore * reviewWeight +
            dataScore * dataWeight +
            collabScore * collaborationWeight +
            govScore * governanceWeight
        ) / 10000;
        
        uint256 oldInfluence = metrics.totalInfluence;
        
        // 更新影响力数据
        metrics.publicationScore = pubScore;
        metrics.reviewScore = revScore;
        metrics.dataContribution = dataScore;
        metrics.collaborationScore = collabScore;
        metrics.governanceScore = govScore;
        metrics.totalInfluence = newInfluence;
        metrics.lastUpdateTime = block.timestamp;
        
        emit InfluenceUpdated(_user, oldInfluence, newInfluence, metrics.rank);
    }
    
    /**
     * @dev 批量更新影响力
     */
    function batchUpdateInfluence(address[] memory _users) external {
        for (uint256 i = 0; i < _users.length; i++) {
            updateUserInfluence(_users[i]);
        }
    }
    
    /**
     * @dev 更新全球排名
     */
    function updateGlobalRanking() external {
        require(
            block.timestamp >= lastGlobalUpdate + rankingUpdateInterval,
            "Too frequent updates"
        );
        
        // 获取所有注册用户
        (uint256 totalUsers,,,,,) = userRegistry.getPlatformStats();
        
        // 创建临时数组存储用户和影响力
        address[] memory users = new address[](totalUsers);
        uint256[] memory influences = new uint256[](totalUsers);
        uint256 validUsers = 0;
        
        // 收集所有用户的影响力数据
        for (uint256 i = 0; i < totalUsers; i++) {
            // 这里需要遍历所有用户，实际实现中应该有用户列表
            // 简化实现
        }
        
        // 对用户按影响力排序（冒泡排序，实际应用中使用更高效的算法）
        for (uint256 i = 0; i < validUsers - 1; i++) {
            for (uint256 j = 0; j < validUsers - 1 - i; j++) {
                if (influences[j] < influences[j + 1]) {
                    // 交换位置
                    (influences[j], influences[j + 1]) = (influences[j + 1], influences[j]);
                    (users[j], users[j + 1]) = (users[j + 1], users[j]);
                }
            }
        }
        
        // 更新全球排名
        delete globalRanking;
        for (uint256 i = 0; i < validUsers && i < maxRankingSize; i++) {
            globalRanking.push(users[i]);
            globalRankPosition[users[i]] = i + 1;
            userInfluence[users[i]].rank = i + 1;
        }
        
        lastGlobalUpdate = block.timestamp;
        
        emit RankingUpdated(RankingType.Global, "global", block.timestamp);
    }
    
    /**
     * @dev 获取全球排名前N名
     */
    function getGlobalTopRanking(uint256 _limit) external view returns (
        address[] memory users,
        uint256[] memory influences,
        uint256[] memory ranks
    ) {
        uint256 limit = _limit;
        if (limit > globalRanking.length) {
            limit = globalRanking.length;
        }
        
        users = new address[](limit);
        influences = new uint256[](limit);
        ranks = new uint256[](limit);
        
        for (uint256 i = 0; i < limit; i++) {
            users[i] = globalRanking[i];
            influences[i] = userInfluence[globalRanking[i]].totalInfluence;
            ranks[i] = i + 1;
        }
    }
    
    /**
     * @dev 获取用户详细影响力数据
     */
    function getUserInfluenceDetails(address _user) external view returns (
        uint256 publicationScore,
        uint256 reviewScore,
        uint256 dataContribution,
        uint256 collaborationScore,
        uint256 governanceScore,
        uint256 totalInfluence,
        uint256 rank,
        uint256 lastUpdateTime
    ) {
        InfluenceMetrics memory metrics = userInfluence[_user];
        
        return (
            metrics.publicationScore,
            metrics.reviewScore,
            metrics.dataContribution,
            metrics.collaborationScore,
            metrics.governanceScore,
            metrics.totalInfluence,
            metrics.rank,
            metrics.lastUpdateTime
        );
    }
    
    /**
     * @dev 按研究领域获取排名
     */
    function getFieldRanking(
        string memory _field,
        uint256 _limit
    ) external view returns (
        address[] memory users,
        uint256[] memory influences
    ) {
        // 实现领域排名逻辑
        // 需要根据用户的研究领域进行分组排名
        
        users = new address[](_limit);
        influences = new uint256[](_limit);
        
        // 简化实现，返回空数组
        return (users, influences);
    }
    
    /**
     * @dev 设置影响力权重
     */
    function setInfluenceWeights(
        uint256 _publicationWeight,
        uint256 _reviewWeight,
        uint256 _dataWeight,
        uint256 _collaborationWeight,
        uint256 _governanceWeight
    ) external onlyOwner {
        require(
            _publicationWeight + _reviewWeight + _dataWeight + 
            _collaborationWeight + _governanceWeight == 10000,
            "Weights must sum to 100%"
        );
        
        publicationWeight = _publicationWeight;
        reviewWeight = _reviewWeight;
        dataWeight = _dataWeight;
        collaborationWeight = _collaborationWeight;
        governanceWeight = _governanceWeight;
        
        emit WeightsUpdated(
            _publicationWeight,
            _reviewWeight,
            _dataWeight,
            _collaborationWeight,
            _governanceWeight
        );
    }
    
    /**
     * @dev 设置排名更新间隔
     */
    function setRankingUpdateInterval(uint256 _interval) external onlyOwner {
        require(_interval >= 1 hours, "Interval too short");
        rankingUpdateInterval = _interval;
    }
    
    /**
     * @dev 设置最大排名大小
     */
    function setMaxRankingSize(uint256 _size) external onlyOwner {
        require(_size >= 100, "Size too small");
        maxRankingSize = _size;
    }
    
    /**
     * @dev 应用时间衰减
     */
    function _applyTimeDecay(uint256 _score, uint256 _tokenId) internal view returns (uint256) {
        // 简化实现，实际应该从NFT获取时间戳
        uint256 age = block.timestamp - block.timestamp; // 占位符
        uint256 yearsOld = age / (365 * 24 * 3600);
        
        if (yearsOld == 0) return _score;
        
        // 每年衰减timeDecayRate/10000
        uint256 decayFactor = DECAY_BASE - (yearsOld * timeDecayRate);
        if (decayFactor < DECAY_BASE / 2) {
            decayFactor = DECAY_BASE / 2; // 最低50%
        }
        
        return (_score * decayFactor) / DECAY_BASE;
    }
    
    /**
     * @dev 计算以2为底的对数（简化实现）
     */
    function _log2(uint256 _value) internal pure returns (uint256) {
        if (_value == 0) return 0;
        
        uint256 result = 0;
        uint256 value = _value;
        
        while (value > 1) {
            value = value / 2;
            result++;
        }
        
        return result;
    }
    
    /**
     * @dev 获取排行榜统计
     */
    function getRankingStats() external view returns (
        uint256 totalRankedUsers,
        uint256 averageInfluence,
        uint256 topInfluence,
        uint256 lastUpdateTime
    ) {
        totalRankedUsers = globalRanking.length;
        lastUpdateTime = lastGlobalUpdate;
        
        if (totalRankedUsers > 0) {
            topInfluence = userInfluence[globalRanking[0]].totalInfluence;
            
            uint256 totalInfluence = 0;
            for (uint256 i = 0; i < totalRankedUsers; i++) {
                totalInfluence += userInfluence[globalRanking[i]].totalInfluence;
            }
            averageInfluence = totalInfluence / totalRankedUsers;
        }
    }
}