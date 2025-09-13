// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title DatasetManager
 * @dev 科研数据集管理合约 - 支持数据上传、验证、访问控制和收益分成
 */
contract DatasetManager is ERC721, Ownable, ReentrancyGuard {
    
    uint256 private _datasetIds;
    
    // 数据集类型枚举
    enum DatasetType {
        Experimental,    // 实验数据
        Survey,         // 调查数据  
        Medical,        // 医学数据
        Genomic,        // 基因组数据
        Environmental,  // 环境数据
        Social,         // 社会科学数据
        Computational   // 计算数据
    }
    
    // 数据质量等级
    enum QualityLevel {
        Unverified,     // 未验证
        Basic,          // 基础验证
        Standard,       // 标准验证
        Premium,        // 高级验证
        Gold            // 金牌认证
    }
    
    // 访问权限类型
    enum AccessType {
        Public,         // 公开访问
        Restricted,     // 限制访问
        Premium,        // 付费访问
        Private         // 私有访问
    }
    
    // 数据集结构
    struct Dataset {
        uint256 id;
        address owner;
        string title;
        string description;
        string[] keywords;
        DatasetType dataType;
        QualityLevel quality;
        AccessType accessType;
        uint256 size;           // 数据大小（字节）
        string ipfsHash;        // IPFS存储哈希
        string metadataHash;    // 元数据IPFS哈希
        string zkpProofHash;    // ZKP质量证明哈希
        uint256 accessPrice;   // 访问价格（wei）
        uint256 uploadTime;
        uint256 downloadCount;
        uint256 citationCount;
        uint256 revenueGenerated;
        bool isActive;
    }
    
    // 访问记录
    struct AccessRecord {
        address user;
        uint256 timestamp;
        uint256 pricePaid;
        string purpose; // 使用目的
    }
    
    // 引用记录
    struct Citation {
        uint256 datasetId;
        address researcher;
        string publicationHash; // 发表成果的IPFS哈希
        uint256 timestamp;
    }
    
    // 存储
    mapping(uint256 => Dataset) public datasets;
    mapping(uint256 => AccessRecord[]) public accessRecords;
    mapping(uint256 => Citation[]) public citations;
    mapping(address => uint256[]) public userDatasets;
    mapping(uint256 => mapping(address => bool)) public hasAccess;
    mapping(uint256 => mapping(address => uint256)) public accessTimestamp;
    
    // 平台费率 (基点，10000 = 100%)
    uint256 public platformFeeRate = 250; // 2.5%
    uint256 public constant MAX_FEE_RATE = 1000; // 10%
    
    // 数据质量验证者
    mapping(address => bool) public qualityVerifiers;
    
    // 事件
    event DatasetUploaded(
        uint256 indexed datasetId,
        address indexed owner,
        string title,
        DatasetType dataType,
        uint256 size
    );
    
    event DatasetAccessed(
        uint256 indexed datasetId,
        address indexed user,
        uint256 pricePaid,
        uint256 timestamp
    );
    
    event DatasetCited(
        uint256 indexed datasetId,
        address indexed researcher,
        string publicationHash,
        uint256 timestamp
    );
    
    event QualityUpdated(
        uint256 indexed datasetId,
        QualityLevel oldLevel,
        QualityLevel newLevel,
        address verifier
    );
    
    event RevenueDistributed(
        uint256 indexed datasetId,
        address indexed owner,
        uint256 ownerShare,
        uint256 platformShare
    );
    
    constructor() ERC721("DeSci Dataset", "DSDT") Ownable(msg.sender) {}
    
    /**
     * @dev 检查数据集是否存在
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return tokenId > 0 && tokenId <= _datasetIds && datasets[tokenId].owner != address(0);
    }
    
    /**
     * @dev 上传数据集
     */
    function uploadDataset(
        string memory _title,
        string memory _description,
        string[] memory _keywords,
        DatasetType _dataType,
        uint256 _size,
        string memory _ipfsHash,
        string memory _metadataHash,
        string memory _zkpProofHash,
        AccessType _accessType,
        uint256 _accessPrice
    ) external returns (uint256) {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_ipfsHash).length > 0, "IPFS hash cannot be empty");
        require(_size > 0, "Dataset size must be greater than 0");
        
        _datasetIds++;
        uint256 datasetId = _datasetIds;
        
        datasets[datasetId] = Dataset({
            id: datasetId,
            owner: msg.sender,
            title: _title,
            description: _description,
            keywords: _keywords,
            dataType: _dataType,
            quality: QualityLevel.Unverified,
            accessType: _accessType,
            size: _size,
            ipfsHash: _ipfsHash,
            metadataHash: _metadataHash,
            zkpProofHash: _zkpProofHash,
            accessPrice: _accessPrice,
            uploadTime: block.timestamp,
            downloadCount: 0,
            citationCount: 0,
            revenueGenerated: 0,
            isActive: true
        });
        
        userDatasets[msg.sender].push(datasetId);
        
        // 铸造NFT代表数据集所有权
        _safeMint(msg.sender, datasetId);
        
        emit DatasetUploaded(datasetId, msg.sender, _title, _dataType, _size);
        
        return datasetId;
    }
    
    /**
     * @dev 购买数据集访问权限
     */
    function purchaseAccess(
        uint256 _datasetId,
        string memory _purpose
    ) external payable nonReentrant {
        require(_exists(_datasetId), "Dataset does not exist");
        require(datasets[_datasetId].isActive, "Dataset is not active");
        
        Dataset storage dataset = datasets[_datasetId];
        
        // 检查访问类型和价格
        if (dataset.accessType == AccessType.Public) {
            require(msg.value == 0, "Public dataset should be free");
        } else if (dataset.accessType == AccessType.Premium) {
            require(msg.value >= dataset.accessPrice, "Insufficient payment");
        } else if (dataset.accessType == AccessType.Private) {
            require(msg.sender == dataset.owner, "Private dataset access denied");
        }
        
        // 记录访问
        hasAccess[_datasetId][msg.sender] = true;
        accessTimestamp[_datasetId][msg.sender] = block.timestamp;
        accessRecords[_datasetId].push(AccessRecord({
            user: msg.sender,
            timestamp: block.timestamp,
            pricePaid: msg.value,
            purpose: _purpose
        }));
        
        // 更新下载计数
        dataset.downloadCount++;
        dataset.revenueGenerated += msg.value;
        
        // 分配收益
        if (msg.value > 0) {
            uint256 platformFee = (msg.value * platformFeeRate) / 10000;
            uint256 ownerShare = msg.value - platformFee;
            
            // 转账给数据集所有者
            if (ownerShare > 0) {
                payable(dataset.owner).transfer(ownerShare);
            }
            
            emit RevenueDistributed(_datasetId, dataset.owner, ownerShare, platformFee);
        }
        
        emit DatasetAccessed(_datasetId, msg.sender, msg.value, block.timestamp);
    }
    
    /**
     * @dev 引用数据集
     */
    function citeDataset(
        uint256 _datasetId,
        string memory _publicationHash
    ) external {
        require(_exists(_datasetId), "Dataset does not exist");
        require(hasAccess[_datasetId][msg.sender], "No access to dataset");
        require(bytes(_publicationHash).length > 0, "Publication hash cannot be empty");
        
        citations[_datasetId].push(Citation({
            datasetId: _datasetId,
            researcher: msg.sender,
            publicationHash: _publicationHash,
            timestamp: block.timestamp
        }));
        
        datasets[_datasetId].citationCount++;
        
        emit DatasetCited(_datasetId, msg.sender, _publicationHash, block.timestamp);
    }
    
    /**
     * @dev 更新数据质量等级（仅限质量验证者）
     */
    function updateQuality(
        uint256 _datasetId,
        QualityLevel _newLevel
    ) external {
        require(qualityVerifiers[msg.sender] || msg.sender == owner(), "Not authorized verifier");
        require(_exists(_datasetId), "Dataset does not exist");
        
        QualityLevel oldLevel = datasets[_datasetId].quality;
        datasets[_datasetId].quality = _newLevel;
        
        emit QualityUpdated(_datasetId, oldLevel, _newLevel, msg.sender);
    }
    
    /**
     * @dev 添加质量验证者
     */
    function addQualityVerifier(address _verifier) external onlyOwner {
        qualityVerifiers[_verifier] = true;
    }
    
    /**
     * @dev 移除质量验证者
     */
    function removeQualityVerifier(address _verifier) external onlyOwner {
        qualityVerifiers[_verifier] = false;
    }
    
    /**
     * @dev 设置平台费率
     */
    function setPlatformFeeRate(uint256 _feeRate) external onlyOwner {
        require(_feeRate <= MAX_FEE_RATE, "Fee rate too high");
        platformFeeRate = _feeRate;
    }
    
    /**
     * @dev 停用数据集
     */
    function deactivateDataset(uint256 _datasetId) external {
        require(_exists(_datasetId), "Dataset does not exist");
        require(ownerOf(_datasetId) == msg.sender, "Not the owner");
        
        datasets[_datasetId].isActive = false;
    }
    
    /**
     * @dev 激活数据集
     */
    function activateDataset(uint256 _datasetId) external {
        require(_exists(_datasetId), "Dataset does not exist");
        require(ownerOf(_datasetId) == msg.sender, "Not the owner");
        
        datasets[_datasetId].isActive = true;
    }
    
    /**
     * @dev 获取数据集详情
     */
    function getDataset(uint256 _datasetId) external view returns (Dataset memory) {
        require(_exists(_datasetId), "Dataset does not exist");
        return datasets[_datasetId];
    }
    
    /**
     * @dev 获取用户的数据集列表
     */
    function getUserDatasets(address _user) external view returns (uint256[] memory) {
        return userDatasets[_user];
    }
    
    /**
     * @dev 获取数据集的访问记录
     */
    function getAccessRecords(uint256 _datasetId) external view returns (AccessRecord[] memory) {
        require(_exists(_datasetId), "Dataset does not exist");
        return accessRecords[_datasetId];
    }
    
    /**
     * @dev 获取数据集的引用记录
     */
    function getCitations(uint256 _datasetId) external view returns (Citation[] memory) {
        require(_exists(_datasetId), "Dataset does not exist");
        return citations[_datasetId];
    }
    
    /**
     * @dev 检查用户是否有访问权限
     */
    function checkAccess(uint256 _datasetId, address _user) external view returns (bool) {
        if (!_exists(_datasetId)) return false;
        if (datasets[_datasetId].accessType == AccessType.Public) return true;
        return hasAccess[_datasetId][_user];
    }
    
    /**
     * @dev 获取平台统计数据
     */
    function getPlatformStats() external view returns (
        uint256 totalDatasets,
        uint256 totalDownloads,
        uint256 totalRevenue,
        uint256 totalCitations
    ) {
        totalDatasets = _datasetIds;
        
        for (uint256 i = 1; i <= totalDatasets; i++) {
            if (_exists(i)) {
                totalDownloads += datasets[i].downloadCount;
                totalRevenue += datasets[i].revenueGenerated;
                totalCitations += datasets[i].citationCount;
            }
        }
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
     * @dev 批量获取数据集信息（分页）
     */
    function getDatasetsPaginated(
        uint256 _offset,
        uint256 _limit
    ) external view returns (Dataset[] memory) {
        uint256 totalDatasets = _datasetIds;
        require(_offset < totalDatasets, "Offset out of bounds");
        
        uint256 end = _offset + _limit;
        if (end > totalDatasets) {
            end = totalDatasets;
        }
        
        Dataset[] memory result = new Dataset[](end - _offset);
        uint256 index = 0;
        
        for (uint256 i = _offset + 1; i <= end; i++) {
            if (_exists(i)) {
                result[index] = datasets[i];
                index++;
            }
        }
        
        return result;
    }
    
    /**
     * @dev 按类型搜索数据集
     */
    function getDatasetsByType(DatasetType _dataType) external view returns (uint256[] memory) {
        uint256 totalDatasets = _datasetIds;
        uint256[] memory tempResult = new uint256[](totalDatasets);
        uint256 count = 0;
        
        for (uint256 i = 1; i <= totalDatasets; i++) {
            if (_exists(i) && datasets[i].dataType == _dataType && datasets[i].isActive) {
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
     * @dev 按质量等级搜索数据集
     */
    function getDatasetsByQuality(QualityLevel _quality) external view returns (uint256[] memory) {
        uint256 totalDatasets = _datasetIds;
        uint256[] memory tempResult = new uint256[](totalDatasets);
        uint256 count = 0;
        
        for (uint256 i = 1; i <= totalDatasets; i++) {
            if (_exists(i) && datasets[i].quality == _quality && datasets[i].isActive) {
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
}