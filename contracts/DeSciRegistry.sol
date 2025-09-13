// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title DeSciRegistry
 * @dev 去中心化科学研究平台用户注册和角色管理合约
 */
contract DeSciRegistry is AccessControl, ReentrancyGuard, Pausable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    
    enum UserRole { None, Researcher, Reviewer, DataProvider, Institution }
    enum VerificationStatus { Pending, Verified, Rejected, Suspended }
    
    struct UserProfile {
        address userAddress;
        string name;
        string organization;
        string email;
        string researchFields;
        string credentials; // IPFS hash for credentials
        UserRole role;
        VerificationStatus status;
        uint256 reputation;
        uint256 registeredAt;
        uint256 verifiedAt;
        bool isActive;
    }
    
    struct VerificationRequest {
        address applicant;
        UserRole requestedRole;
        string evidence; // IPFS hash for supporting documents
        address verifier;
        string comments;
        uint256 submittedAt;
        uint256 processedAt;
        VerificationStatus status;
    }
    
    // 存储映射
    mapping(address => UserProfile) public userProfiles;
    mapping(address => bool) public isRegistered;
    mapping(UserRole => address[]) public usersByRole;
    mapping(uint256 => VerificationRequest) public verificationRequests;
    
    // 计数器
    uint256 public totalUsers;
    uint256 public nextRequestId;
    
    // 角色要求
    mapping(UserRole => uint256) public minimumReputation;
    mapping(UserRole => bool) public requiresVerification;
    
    // 事件
    event UserRegistered(
        address indexed user,
        string name,
        UserRole role,
        uint256 timestamp
    );
    
    event VerificationRequested(
        uint256 indexed requestId,
        address indexed applicant,
        UserRole requestedRole,
        uint256 timestamp
    );
    
    event UserVerified(
        address indexed user,
        UserRole role,
        address indexed verifier,
        uint256 timestamp
    );
    
    event ReputationUpdated(
        address indexed user,
        uint256 oldReputation,
        uint256 newReputation,
        string reason
    );
    
    event RoleChanged(
        address indexed user,
        UserRole oldRole,
        UserRole newRole,
        uint256 timestamp
    );
    
    modifier onlyRegisteredUser() {
        require(isRegistered[msg.sender], "User not registered");
        _;
    }
    
    modifier onlyActiveUser() {
        require(isRegistered[msg.sender] && userProfiles[msg.sender].isActive, 
                "User not active");
        _;
    }
    
    modifier onlyUserRole(UserRole _role) {
        require(userProfiles[msg.sender].role == _role, "Insufficient role");
        _;
    }
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(VERIFIER_ROLE, msg.sender);
        
        // 设置角色要求
        minimumReputation[UserRole.Researcher] = 0;
        minimumReputation[UserRole.Reviewer] = 100;
        minimumReputation[UserRole.DataProvider] = 50;
        minimumReputation[UserRole.Institution] = 200;
        
        requiresVerification[UserRole.Researcher] = false;
        requiresVerification[UserRole.Reviewer] = true;
        requiresVerification[UserRole.DataProvider] = false;
        requiresVerification[UserRole.Institution] = true;
        
        nextRequestId = 1;
    }
    
    /**
     * @dev 用户注册
     */
    function registerUser(
        string memory _name,
        string memory _organization,
        string memory _email,
        string memory _researchFields,
        string memory _credentials,
        UserRole _role
    ) external nonReentrant whenNotPaused {
        _registerUserInternal(
            msg.sender,
            _name,
            _organization,
            _email,
            _researchFields,
            _credentials,
            _role
        );
    }
    
    /**
     * @dev 代表用户注册（仅限管理员或授权合约）
     */
    function registerUserFor(
        address _user,
        string memory _name,
        string memory _organization,
        string memory _email,
        string memory _researchFields,
        string memory _credentials,
        UserRole _role
    ) external nonReentrant whenNotPaused {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        _registerUserInternal(
            _user,
            _name,
            _organization,
            _email,
            _researchFields,
            _credentials,
            _role
        );
    }
    
    /**
     * @dev 内部注册实现
     */
    function _registerUserInternal(
        address _userAddress,
        string memory _name,
        string memory _organization,
        string memory _email,
        string memory _researchFields,
        string memory _credentials,
        UserRole _role
    ) internal {
        require(!isRegistered[_userAddress], "User already registered");
        require(_role != UserRole.None, "Invalid role");
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_email).length > 0, "Email cannot be empty");
        
        VerificationStatus initialStatus = requiresVerification[_role] 
            ? VerificationStatus.Pending 
            : VerificationStatus.Verified;
        
        UserProfile memory newProfile = UserProfile({
            userAddress: _userAddress,
            name: _name,
            organization: _organization,
            email: _email,
            researchFields: _researchFields,
            credentials: _credentials,
            role: _role,
            status: initialStatus,
            reputation: 0,
            registeredAt: block.timestamp,
            verifiedAt: initialStatus == VerificationStatus.Verified ? block.timestamp : 0,
            isActive: true
        });
        
        userProfiles[_userAddress] = newProfile;
        isRegistered[_userAddress] = true;
        usersByRole[_role].push(_userAddress);
        totalUsers++;
        
        emit UserRegistered(_userAddress, _name, _role, block.timestamp);
        
        // 如果需要验证，自动创建验证请求
        if (requiresVerification[_role]) {
            _createVerificationRequest(_userAddress, _role, _credentials);
        }
    }
    
    /**
     * @dev 申请角色升级
     */
    function requestRoleUpgrade(
        UserRole _newRole,
        string memory _evidence
    ) external onlyRegisteredUser whenNotPaused {
        require(_newRole > userProfiles[msg.sender].role, "Cannot downgrade role");
        require(userProfiles[msg.sender].reputation >= minimumReputation[_newRole], 
                "Insufficient reputation");
        
        _createVerificationRequest(msg.sender, _newRole, _evidence);
    }
    
    /**
     * @dev 创建验证请求
     */
    function _createVerificationRequest(
        address _applicant,
        UserRole _role,
        string memory _evidence
    ) internal {
        uint256 requestId = nextRequestId++;
        
        verificationRequests[requestId] = VerificationRequest({
            applicant: _applicant,
            requestedRole: _role,
            evidence: _evidence,
            verifier: address(0),
            comments: "",
            submittedAt: block.timestamp,
            processedAt: 0,
            status: VerificationStatus.Pending
        });
        
        emit VerificationRequested(requestId, _applicant, _role, block.timestamp);
    }
    
    /**
     * @dev 处理验证请求
     */
    function processVerificationRequest(
        uint256 _requestId,
        bool _approved,
        string memory _comments
    ) external whenNotPaused {
        require(hasRole(VERIFIER_ROLE, msg.sender), "Caller is not a verifier");
        VerificationRequest storage request = verificationRequests[_requestId];
        require(request.status == VerificationStatus.Pending, "Request already processed");
        
        request.verifier = msg.sender;
        request.comments = _comments;
        request.processedAt = block.timestamp;
        request.status = _approved ? VerificationStatus.Verified : VerificationStatus.Rejected;
        
        if (_approved) {
            UserProfile storage profile = userProfiles[request.applicant];
            UserRole oldRole = profile.role;
            
            profile.role = request.requestedRole;
            profile.status = VerificationStatus.Verified;
            profile.verifiedAt = block.timestamp;
            
            // 更新角色映射
            usersByRole[request.requestedRole].push(request.applicant);
            
            emit UserVerified(request.applicant, request.requestedRole, msg.sender, block.timestamp);
            emit RoleChanged(request.applicant, oldRole, request.requestedRole, block.timestamp);
        } else {
            // 如果拒绝验证请求，更新用户状态为Rejected
            UserProfile storage profile = userProfiles[request.applicant];
            profile.status = VerificationStatus.Rejected;
            profile.verifiedAt = block.timestamp;
        }
    }
    
    /**
     * @dev 更新用户声誉
     */
    function updateReputation(
        address _user,
        uint256 _newReputation,
        string memory _reason
    ) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        require(isRegistered[_user], "User not registered");
        
        uint256 oldReputation = userProfiles[_user].reputation;
        userProfiles[_user].reputation = _newReputation;
        
        emit ReputationUpdated(_user, oldReputation, _newReputation, _reason);
    }
    
    /**
     * @dev 增加声誉（供其他合约调用）
     */
    function increaseReputation(address _user, uint256 _amount, string memory _reason) 
        external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        require(isRegistered[_user], "User not registered");
        
        uint256 oldReputation = userProfiles[_user].reputation;
        userProfiles[_user].reputation += _amount;
        
        emit ReputationUpdated(_user, oldReputation, userProfiles[_user].reputation, _reason);
    }
    
    /**
     * @dev 暂停/恢复用户
     */
    function setUserStatus(address _user, bool _isActive) 
        external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        require(isRegistered[_user], "User not registered");
        userProfiles[_user].isActive = _isActive;
    }
    
    /**
     * @dev 获取用户详细信息
     */
    function getUserProfile(address _user) 
        external view returns (UserProfile memory) {
        require(isRegistered[_user], "User not registered");
        return userProfiles[_user];
    }
    
    /**
     * @dev 获取特定角色的所有用户
     */
    function getUsersByRole(UserRole _role) 
        external view returns (address[] memory) {
        return usersByRole[_role];
    }
    
    /**
     * @dev 获取待处理的验证请求
     */
    function getPendingVerificationRequests() 
        external view returns (uint256[] memory) {
        uint256[] memory pendingIds = new uint256[](nextRequestId - 1);
        uint256 count = 0;
        
        for (uint256 i = 1; i < nextRequestId; i++) {
            if (verificationRequests[i].status == VerificationStatus.Pending) {
                pendingIds[count] = i;
                count++;
            }
        }
        
        // 调整数组大小
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = pendingIds[i];
        }
        
        return result;
    }
    
    /**
     * @dev 检查用户是否有特定角色
     */
    function hasUserRole(address _user, UserRole _role) 
        external view returns (bool) {
        return isRegistered[_user] && 
               userProfiles[_user].role == _role && 
               userProfiles[_user].isActive &&
               userProfiles[_user].status == VerificationStatus.Verified;
    }
    
    /**
     * @dev 获取平台统计信息
     */
    function getPlatformStats() external view returns (
        uint256 totalRegistered,
        uint256 totalResearchers,
        uint256 totalReviewers,
        uint256 totalDataProviders,
        uint256 totalInstitutions,
        uint256 pendingVerifications
    ) {
        totalRegistered = totalUsers;
        totalResearchers = usersByRole[UserRole.Researcher].length;
        totalReviewers = usersByRole[UserRole.Reviewer].length;
        totalDataProviders = usersByRole[UserRole.DataProvider].length;
        totalInstitutions = usersByRole[UserRole.Institution].length;
        
        // 计算待处理验证
        for (uint256 i = 1; i < nextRequestId; i++) {
            if (verificationRequests[i].status == VerificationStatus.Pending) {
                pendingVerifications++;
            }
        }
    }
    
    // 管理员功能
    function pause() external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        _pause();
    }
    
    function unpause() external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        _unpause();
    }
    
    function setRoleRequirements(
        UserRole _role,
        uint256 _minReputation,
        bool _requiresVerification
    ) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        minimumReputation[_role] = _minReputation;
        requiresVerification[_role] = _requiresVerification;
    }
}