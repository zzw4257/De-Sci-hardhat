// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ResearchNFT
 * @dev 科研成果NFT合约 - 支持论文、专利、数据等科研成果的NFT化
 */
contract ResearchNFT is ERC721URIStorage, Ownable, ReentrancyGuard {
    
    uint256 private _tokenIds;
    
    // 成果类型枚举
    enum PublicationType {
        Paper,          // 学术论文
        Patent,         // 专利
        Dataset,        // 数据集
        Software,       // 软件代码
        Experiment,     // 实验结果
        Review,         // 综述
        Preprint,       // 预印本
        Thesis          // 学位论文
    }
    
    // 评审状态
    enum ReviewStatus {
        Pending,        // 待评审
        UnderReview,    // 评审中
        Approved,       // 已通过
        Rejected,       // 已拒绝
        Revised         // 已修订
    }
    
    // 影响力等级
    enum ImpactLevel {
        Low,            // 低影响力
        Medium,         // 中等影响力
        High,           // 高影响力
        Breakthrough    // 突破性发现
    }
    
    // 科研成果结构
    struct Research {
        uint256 tokenId;
        address[] authors;          // 作者列表
        uint256[] authorShares;     // 作者份额（基点）
        string title;
        string abstractText;
        string[] keywords;
        string[] researchFields;
        PublicationType pubType;
        string contentHash;         // IPFS内容哈希
        string metadataHash;        // 元数据哈希
        uint256 timestamp;
        ReviewStatus reviewStatus;
        ImpactLevel impactLevel;
        uint256 citationCount;
        uint256[] citedWorks;       // 引用的其他成果
        uint256[] citingWorks;      // 被引用的成果
        uint256 downloadCount;
        uint256 revenueGenerated;
        bool isOpenAccess;
        uint256 accessPrice;
        mapping(address => bool) hasAccess;
    }
    
    // 评审记录
    struct PeerReview {
        address reviewer;
        uint256 timestamp;
        uint8 score;                // 1-10分
        string reviewHash;          // 评审意见IPFS哈希
        bool isAnonymous;
        bytes32 zkpProof;          // 匿名评审的ZKP证明
    }
    
    // 引用关系
    struct Citation {
        uint256 fromTokenId;
        uint256 toTokenId;
        address citer;
        uint256 timestamp;
        string context;             // 引用上下文
    }
    
    // 存储
    mapping(uint256 => Research) public researches;
    mapping(uint256 => PeerReview[]) public peerReviews;
    mapping(uint256 => Citation[]) public citations;
    mapping(address => uint256[]) public authorWorks;
    mapping(string => bool) public contentExists; // 防止重复提交
    mapping(address => bool) public authorizedReviewers;
    mapping(address => bool) public qualityVerifiers;
    mapping(address => bool) public authorizedContracts; // 添加授权合约映射
    
    // 平台费率和设置
    uint256 public platformFeeRate = 250; // 2.5%
    uint256 public reviewerReward = 0.01 ether; // 评审奖励
    uint256 public minReviewers = 2; // 最少评审员数量
    uint256 public constant MAX_AUTHORS = 20; // 最大作者数量
    
    // 影响力权重配置
    mapping(PublicationType => uint256) public typeWeights;
    mapping(ImpactLevel => uint256) public impactMultipliers;
    
    // 事件
    event ResearchMinted(
        uint256 indexed tokenId,
        address[] authors,
        string title,
        PublicationType pubType,
        uint256 timestamp
    );
    
    event ReviewSubmitted(
        uint256 indexed tokenId,
        address indexed reviewer,
        uint8 score,
        bool isAnonymous
    );
    
    event CitationAdded(
        uint256 indexed fromTokenId,
        uint256 indexed toTokenId,
        address indexed citer
    );
    
    event ImpactLevelUpdated(
        uint256 indexed tokenId,
        ImpactLevel oldLevel,
        ImpactLevel newLevel
    );
    
    event RevenueDistributed(
        uint256 indexed tokenId,
        address[] authors,
        uint256[] shares,
        uint256 totalAmount
    );
    
    constructor() ERC721("DeSci Research NFT", "DSRN") Ownable(msg.sender) {
        // 初始化类型权重
        typeWeights[PublicationType.Paper] = 100;
        typeWeights[PublicationType.Patent] = 120;
        typeWeights[PublicationType.Dataset] = 80;
        typeWeights[PublicationType.Software] = 90;
        typeWeights[PublicationType.Experiment] = 85;
        typeWeights[PublicationType.Review] = 70;
        typeWeights[PublicationType.Preprint] = 60;
        typeWeights[PublicationType.Thesis] = 75;
        
        // 初始化影响力倍数
        impactMultipliers[ImpactLevel.Low] = 100;
        impactMultipliers[ImpactLevel.Medium] = 200;
        impactMultipliers[ImpactLevel.High] = 400;
        impactMultipliers[ImpactLevel.Breakthrough] = 1000;
    }
    
    /**
     * @dev 检查科研成果是否存在
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return tokenId > 0 && tokenId <= _tokenIds && researches[tokenId].timestamp != 0;
    }
    
    /**
     * @dev 铸造科研成果NFT
     */
    function mintResearch(
        address[] memory _authors,
        uint256[] memory _authorShares,
        string memory _title,
        string memory _abstractText,
        string[] memory _keywords,
        string[] memory _researchFields,
        PublicationType _pubType,
        string memory _contentHash,
        string memory _metadataHash,
        bool _isOpenAccess,
        uint256 _accessPrice,
        string memory _tokenURI
    ) external returns (uint256) {
        require(_authors.length > 0 && _authors.length <= MAX_AUTHORS, "Invalid authors count");
        require(_authors.length == _authorShares.length, "Authors and shares length mismatch");
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_contentHash).length > 0, "Content hash cannot be empty");
        require(!contentExists[_contentHash], "Content already exists");
        
        // 验证作者份额总和为10000 (100%)
        uint256 totalShares = 0;
        for (uint256 i = 0; i < _authorShares.length; i++) {
            totalShares += _authorShares[i];
        }
        require(totalShares == 10000, "Author shares must sum to 100%");
        
        // 验证调用者是作者之一或授权合约
        bool isAuthor = false;
        for (uint256 i = 0; i < _authors.length; i++) {
            if (_authors[i] == msg.sender) {
                isAuthor = true;
                break;
            }
        }
        
        // 如果调用者不是作者，检查是否是授权合约
        bool isAuthorizedContract = authorizedContracts[msg.sender];
        
        require(isAuthor || isAuthorizedContract, "Caller must be one of the authors or an authorized contract");
        
        _tokenIds++;
        uint256 tokenId = _tokenIds;
        
        // 创建研究记录
        Research storage research = researches[tokenId];
        research.tokenId = tokenId;
        research.authors = _authors;
        research.authorShares = _authorShares;
        research.title = _title;
        research.abstractText = _abstractText;
        research.keywords = _keywords;
        research.researchFields = _researchFields;
        research.pubType = _pubType;
        research.contentHash = _contentHash;
        research.metadataHash = _metadataHash;
        research.timestamp = block.timestamp;
        research.reviewStatus = ReviewStatus.Pending;
        research.impactLevel = ImpactLevel.Low;
        research.isOpenAccess = _isOpenAccess;
        research.accessPrice = _accessPrice;
        
        // 记录内容存在
        contentExists[_contentHash] = true;
        
        // 为每个作者记录作品
        for (uint256 i = 0; i < _authors.length; i++) {
            authorWorks[_authors[i]].push(tokenId);
        }
        
        // 铸造NFT给第一作者
        _safeMint(_authors[0], tokenId);
        _setTokenURI(tokenId, _tokenURI);
        
        emit ResearchMinted(tokenId, _authors, _title, _pubType, block.timestamp);
        
        return tokenId;
    }
    
    /**
     * @dev 提交同行评审
     */
    function submitPeerReview(
        uint256 _tokenId,
        uint8 _score,
        string memory _reviewHash,
        bool _isAnonymous,
        bytes32 _zkpProof
    ) external {
        require(_exists(_tokenId), "Research does not exist");
        require(authorizedReviewers[msg.sender], "Not authorized reviewer");
        require(_score >= 1 && _score <= 10, "Score must be between 1 and 10");
        require(bytes(_reviewHash).length > 0, "Review hash cannot be empty");
        
        Research storage research = researches[_tokenId];
        require(research.reviewStatus == ReviewStatus.Pending || 
                research.reviewStatus == ReviewStatus.UnderReview, "Not accepting reviews");
        
        // 检查评审员是否已经评审过
        PeerReview[] storage reviews = peerReviews[_tokenId];
        for (uint256 i = 0; i < reviews.length; i++) {
            require(reviews[i].reviewer != msg.sender, "Already reviewed");
        }
        
        // 添加评审记录
        reviews.push(PeerReview({
            reviewer: msg.sender,
            timestamp: block.timestamp,
            score: _score,
            reviewHash: _reviewHash,
            isAnonymous: _isAnonymous,
            zkpProof: _zkpProof
        }));
        
        // 更新评审状态
        research.reviewStatus = ReviewStatus.UnderReview;
        
        // 发放评审奖励
        if (reviewerReward > 0 && address(this).balance >= reviewerReward) {
            payable(msg.sender).transfer(reviewerReward);
        }
        
        // 检查是否达到最小评审数量
        if (reviews.length >= minReviewers) {
            _finalizeReview(_tokenId);
        }
        
        emit ReviewSubmitted(_tokenId, msg.sender, _score, _isAnonymous);
    }
    
    /**
     * @dev 完成评审流程
     */
    function _finalizeReview(uint256 _tokenId) internal {
        PeerReview[] storage reviews = peerReviews[_tokenId];
        require(reviews.length >= minReviewers, "Insufficient reviews");
        
        // 计算平均分
        uint256 totalScore = 0;
        for (uint256 i = 0; i < reviews.length; i++) {
            totalScore += reviews[i].score;
        }
        uint256 avgScore = totalScore / reviews.length;
        
        Research storage research = researches[_tokenId];
        
        // 根据平均分决定状态和影响力等级
        if (avgScore >= 8) {
            research.reviewStatus = ReviewStatus.Approved;
            research.impactLevel = ImpactLevel.High;
        } else if (avgScore >= 6) {
            research.reviewStatus = ReviewStatus.Approved;
            research.impactLevel = ImpactLevel.Medium;
        } else if (avgScore >= 4) {
            research.reviewStatus = ReviewStatus.Approved;
            research.impactLevel = ImpactLevel.Low;
        } else {
            research.reviewStatus = ReviewStatus.Rejected;
        }
    }
    
    /**
     * @dev 添加引用关系
     */
    function addCitation(
        uint256 _fromTokenId,
        uint256 _toTokenId,
        string memory _context
    ) external {
        require(_exists(_fromTokenId) && _exists(_toTokenId), "Token does not exist");
        require(_fromTokenId != _toTokenId, "Cannot cite self");
        
        Research storage fromResearch = researches[_fromTokenId];
        Research storage toResearch = researches[_toTokenId];
        
        // 验证调用者是引用方的作者
        bool isAuthor = false;
        for (uint256 i = 0; i < fromResearch.authors.length; i++) {
            if (fromResearch.authors[i] == msg.sender) {
                isAuthor = true;
                break;
            }
        }
        require(isAuthor, "Must be author to add citation");
        
        // 添加引用记录
        citations[_fromTokenId].push(Citation({
            fromTokenId: _fromTokenId,
            toTokenId: _toTokenId,
            citer: msg.sender,
            timestamp: block.timestamp,
            context: _context
        }));
        
        // 更新引用关系
        fromResearch.citedWorks.push(_toTokenId);
        toResearch.citingWorks.push(_fromTokenId);
        toResearch.citationCount++;
        
        emit CitationAdded(_fromTokenId, _toTokenId, msg.sender);
    }
    
    /**
     * @dev 购买访问权限
     */
    function purchaseAccess(uint256 _tokenId) external payable nonReentrant {
        require(_exists(_tokenId), "Research does not exist");
        
        Research storage research = researches[_tokenId];
        require(!research.isOpenAccess, "Research is open access");
        require(msg.value >= research.accessPrice, "Insufficient payment");
        require(!research.hasAccess[msg.sender], "Already has access");
        
        // 授予访问权限
        research.hasAccess[msg.sender] = true;
        research.downloadCount++;
        research.revenueGenerated += msg.value;
        
        // 分配收益给作者
        _distributeRevenue(_tokenId, msg.value);
    }
    
    /**
     * @dev 分配收益给作者
     */
    function _distributeRevenue(uint256 _tokenId, uint256 _amount) internal {
        Research storage research = researches[_tokenId];
        
        uint256 platformFee = (_amount * platformFeeRate) / 10000;
        uint256 authorRevenue = _amount - platformFee;
        
        address[] memory authors = research.authors;
        uint256[] memory shares = research.authorShares;
        uint256[] memory authorPayments = new uint256[](authors.length);
        
        // 计算每个作者的收益
        for (uint256 i = 0; i < authors.length; i++) {
            uint256 authorShare = (authorRevenue * shares[i]) / 10000;
            if (authorShare > 0) {
                payable(authors[i]).transfer(authorShare);
                authorPayments[i] = authorShare;
            }
        }
        
        emit RevenueDistributed(_tokenId, authors, authorPayments, authorRevenue);
    }
    
    /**
     * @dev 计算影响力分数
     */
    function calculateImpactScore(uint256 _tokenId) external view returns (uint256) {
        require(_exists(_tokenId), "Research does not exist");
        
        Research storage research = researches[_tokenId];
        
        // 基础分数 = 类型权重 × 影响力倍数
        uint256 baseScore = typeWeights[research.pubType] * impactMultipliers[research.impactLevel];
        
        // 引用加分 = 引用数 × 10
        uint256 citationBonus = research.citationCount * 10;
        
        // 下载加分 = 下载数 × 1
        uint256 downloadBonus = research.downloadCount;
        
        // 时间衰减因子（论文越新，衰减越少）
        uint256 timeDecay = 10000; // 基础为100%
        uint256 monthsOld = (block.timestamp - research.timestamp) / (30 * 24 * 3600);
        if (monthsOld > 0) {
            timeDecay = 10000 - (monthsOld * 10); // 每月衰减0.1%
            if (timeDecay < 5000) timeDecay = 5000; // 最低50%
        }
        
        uint256 totalScore = (baseScore + citationBonus + downloadBonus) * timeDecay / 10000;
        
        return totalScore;
    }
    
    /**
     * @dev 获取作者的所有作品
     */
    function getAuthorWorks(address _author) external view returns (uint256[] memory) {
        return authorWorks[_author];
    }
    
    /**
     * @dev 获取研究的评审记录
     */
    function getPeerReviews(uint256 _tokenId) external view returns (PeerReview[] memory) {
        require(_exists(_tokenId), "Research does not exist");
        return peerReviews[_tokenId];
    }
    
    /**
     * @dev 获取引用记录
     */
    function getCitations(uint256 _tokenId) external view returns (Citation[] memory) {
        require(_exists(_tokenId), "Research does not exist");
        return citations[_tokenId];
    }
    
    /**
     * @dev 检查访问权限
     */
    function hasAccessToResearch(uint256 _tokenId, address _user) external view returns (bool) {
        if (!_exists(_tokenId)) return false;
        
        Research storage research = researches[_tokenId];
        if (research.isOpenAccess) return true;
        
        // 检查是否是作者
        for (uint256 i = 0; i < research.authors.length; i++) {
            if (research.authors[i] == _user) return true;
        }
        
        return research.hasAccess[_user];
    }
    
    /**
     * @dev 添加授权评审员
     */
    function addAuthorizedReviewer(address _reviewer) external onlyOwner {
        authorizedReviewers[_reviewer] = true;
    }
    
    /**
     * @dev 移除授权评审员
     */
    function removeAuthorizedReviewer(address _reviewer) external onlyOwner {
        authorizedReviewers[_reviewer] = false;
    }
    
    /**
     * @dev 添加授权合约
     */
    function addAuthorizedContract(address _contract) external onlyOwner {
        authorizedContracts[_contract] = true;
    }
    
    /**
     * @dev 移除授权合约
     */
    function removeAuthorizedContract(address _contract) external onlyOwner {
        authorizedContracts[_contract] = false;
    }
    
    /**
     * @dev 设置平台费率
     */
    function setPlatformFeeRate(uint256 _feeRate) external onlyOwner {
        require(_feeRate <= 1000, "Fee rate too high"); // 最高10%
        platformFeeRate = _feeRate;
    }
    
    /**
     * @dev 设置评审奖励
     */
    function setReviewerReward(uint256 _reward) external onlyOwner {
        reviewerReward = _reward;
    }
    
    /**
     * @dev 设置最少评审员数量
     */
    function setMinReviewers(uint256 _minReviewers) external onlyOwner {
        require(_minReviewers >= 1, "Must have at least 1 reviewer");
        minReviewers = _minReviewers;
    }
    
    /**
     * @dev 获取平台统计
     */
    function getPlatformStats() external view returns (
        uint256 totalResearches,
        uint256 totalCitations,
        uint256 totalDownloads,
        uint256 totalRevenue,
        uint256 pendingReviews,
        uint256 approvedResearches
    ) {
        totalResearches = _tokenIds;
        
        for (uint256 i = 1; i <= totalResearches; i++) {
            if (_exists(i)) {
                Research storage research = researches[i];
                totalCitations += research.citationCount;
                totalDownloads += research.downloadCount;
                totalRevenue += research.revenueGenerated;
                
                if (research.reviewStatus == ReviewStatus.Pending || 
                    research.reviewStatus == ReviewStatus.UnderReview) {
                    pendingReviews++;
                } else if (research.reviewStatus == ReviewStatus.Approved) {
                    approvedResearches++;
                }
            }
        }
    }
    
    /**
     * @dev 按类型获取研究列表
     */
    function getResearchesByType(PublicationType _pubType) external view returns (uint256[] memory) {
        uint256 totalResearches = _tokenIds;
        uint256[] memory tempResult = new uint256[](totalResearches);
        uint256 count = 0;
        
        for (uint256 i = 1; i <= totalResearches; i++) {
            if (_exists(i) && researches[i].pubType == _pubType) {
                tempResult[count] = i;
                count++;
            }
        }
        
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = tempResult[i];
        }
        
        return result;
    }
    
    /**
     * @dev 提取平台收益
     */
    function withdrawPlatformFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        
        payable(owner()).transfer(balance);
    }
    
    /**
     * @dev 接收以太币
     */
    receive() external payable {}
}