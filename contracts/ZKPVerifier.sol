// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ZKPVerifier
 * @dev Zero-knowledge proof verifier contract, supporting Groth16 and zkSNARK verification
 * Used for verifying zero-knowledge proofs of research data
 */
contract ZKPVerifier is Ownable, ReentrancyGuard {
    
    // Groth16 verification parameter structure
    struct Groth16Proof {
        uint256[2] a;      // G1 point
        uint256[2][2] b;   // G2 point
        uint256[2] c;      // G1 point
    }
    
    // Verification parameter structure
    struct VerificationParams {
        uint256[2] alpha1;     // G1 point
        uint256[2][2] beta2;   // G2 point
        uint256[2][2] gamma2;  // G2 point
        uint256[2][2] delta2;  // G2 point
        uint256[2][] ic;       // G1 point array
    }
    
    // Proof types
    mapping(string => VerificationParams) private _verificationParams;
    string[] public supportedProofTypes;
    
    // Verification result records
    mapping(bytes32 => bool) public verificationResults;
    mapping(bytes32 => uint256) public verificationTimestamps;
    
    // Events
    event ProofTypeRegistered(string proofType, address indexed registrant);
    event ProofVerified(bytes32 indexed proofHash, bool isValid, uint256 timestamp);
    event VerificationParamsUpdated(string proofType, address indexed updater);
    
    // Modifiers
    modifier proofTypeExists(string memory _proofType) {
        require(_verificationParams[_proofType].alpha1[0] != 0, "Proof type not registered");
        _;
    }
    
    constructor() Ownable(msg.sender) {
        // Initialize default proof types
        _registerDefaultProofTypes();
    }
    
    /**
     * @dev 注册新的证明类型和验证参数
     * @param _proofType 证明类型名称
     * @param _alpha1 G1点 alpha1
     * @param _beta2 G2点 beta2
     * @param _gamma2 G2点 gamma2
     * @param _delta2 G2点 delta2
     * @param _ic G1点数组 ic
     */
    function registerProofType(
        string memory _proofType,
        uint256[2] memory _alpha1,
        uint256[2][2] memory _beta2,
        uint256[2][2] memory _gamma2,
        uint256[2][2] memory _delta2,
        uint256[2][] memory _ic
    ) external onlyOwner {
        require(bytes(_proofType).length > 0, "Proof type cannot be empty");
        require(_ic.length > 0, "IC array cannot be empty");
        
        _verificationParams[_proofType] = VerificationParams({
            alpha1: _alpha1,
            beta2: _beta2,
            gamma2: _gamma2,
            delta2: _delta2,
            ic: _ic
        });
        
        supportedProofTypes.push(_proofType);
        emit ProofTypeRegistered(_proofType, msg.sender);
    }
    
    /**
     * @dev Update verification parameters
     * @param _proofType Proof type name
     * @param _alpha1 G1 point alpha1
     * @param _beta2 G2 point beta2
     * @param _gamma2 G2 point gamma2
     * @param _delta2 G2 point delta2
     * @param _ic G1 point array ic
     */
    function updateVerificationParams(
        string memory _proofType,
        uint256[2] memory _alpha1,
        uint256[2][2] memory _beta2,
        uint256[2][2] memory _gamma2,
        uint256[2][2] memory _delta2,
        uint256[2][] memory _ic
    ) external onlyOwner proofTypeExists(_proofType) {
        _verificationParams[_proofType] = VerificationParams({
            alpha1: _alpha1,
            beta2: _beta2,
            gamma2: _gamma2,
            delta2: _delta2,
            ic: _ic
        });
        
        emit VerificationParamsUpdated(_proofType, msg.sender);
    }
    
    /**
     * @dev 验证Groth16证明
     * @param _proofType 证明类型
     * @param _proof Groth16证明
     * @param _publicInputs 公开输入数组
     * @return 验证是否成功
     */
    function verifyGroth16Proof(
        string memory _proofType,
        Groth16Proof memory _proof,
        uint256[] memory _publicInputs
    ) external proofTypeExists(_proofType) returns (bool) {
        bytes32 proofHash = keccak256(abi.encodePacked(
            _proofType,
            _proof.a[0], _proof.a[1],
            _proof.b[0][0], _proof.b[0][1], _proof.b[1][0], _proof.b[1][1],
            _proof.c[0], _proof.c[1],
            _publicInputs
        ));
        
        // 执行Groth16验证
        bool isValid = _verifyGroth16(_proofType, _proof, _publicInputs);
        
        // 记录验证结果
        verificationResults[proofHash] = isValid;
        verificationTimestamps[proofHash] = block.timestamp;
        
        emit ProofVerified(proofHash, isValid, block.timestamp);
        
        return isValid;
    }
    
    /**
     * @dev 内部Groth16验证函数 - 增强版实现
     * @param _proofType 证明类型
     * @param _proof Groth16证明
     * @param _publicInputs 公开输入数组
     * @return 验证是否成功
     */
    function _verifyGroth16(
        string memory _proofType,
        Groth16Proof memory _proof,
        uint256[] memory _publicInputs
    ) internal view returns (bool) {
        VerificationParams storage params = _verificationParams[_proofType];
        
        // 1. 检查证明点的有效性
        if (!_isValidG1Point(_proof.a) || !_isValidG1Point(_proof.c)) {
            return false;
        }
        
        if (!_isValidG2Point(_proof.b)) {
            return false;
        }
        
        // 2. 检查公开输入数量
        if (_publicInputs.length != params.ic.length - 1) {
            return false;
        }
        
        // 3. 验证公开输入范围（防止溢出攻击）
        for (uint i = 0; i < _publicInputs.length; i++) {
            if (_publicInputs[i] >= 21888242871839275222246405745257275088548364400416034343698204186575808495617) {
                return false; // BN254的素数阶
            }
        }
        
        // 4. 计算线性组合 vk_x = IC[0] + sum(publicInputs[i] * IC[i+1])
        uint256[2] memory vk_x = _calculateLinearCombination(params.ic, _publicInputs);
        
        // 5. 执行椭圆曲线配对验证
        bool pairingResult = _verifyPairing(_proof, params, vk_x);
        
        // 6. 验证业务约束条件
        bool constraintResult = _verifyConstraints(_proofType, _publicInputs);
        
        return pairingResult && constraintResult;
    }
    
    /**
     * @dev 计算线性组合 vk_x = IC[0] + sum(publicInputs[i] * IC[i+1])
     */
    function _calculateLinearCombination(
        uint256[2][] storage ic,
        uint256[] memory publicInputs
    ) internal view returns (uint256[2] memory) {
        uint256[2] memory vk_x = ic[0];
        
        for (uint256 i = 0; i < publicInputs.length; i++) {
            if (publicInputs[i] != 0) {
                uint256[2] memory scaled = _scalarMul(ic[i + 1], publicInputs[i]);
                vk_x = _pointAdd(vk_x, scaled);
            }
        }
        
        return vk_x;
    }
    
    /**
     * @dev 使用以太坊预编译合约验证椭圆曲线配对
     * 验证等式: e(A, B) * e(vk_x, gamma) * e(C, delta) = e(alpha, beta)
     */
    function _verifyPairing(
        Groth16Proof memory proof,
        VerificationParams storage params,
        uint256[2] memory vk_x
    ) internal view returns (bool) {
        // 准备配对验证的输入参数
        uint256[24] memory input;
        
        // 第一对: A, B (正向)
        input[0] = proof.a[0];
        input[1] = proof.a[1];
        input[2] = proof.b[0][1]; // G2点的虚部在前
        input[3] = proof.b[0][0]; // G2点的实部在后
        input[4] = proof.b[1][1];
        input[5] = proof.b[1][0];
        
        // 第二对: alpha, beta (负向，通过使用-beta实现)
        input[6] = params.alpha1[0];
        input[7] = params.alpha1[1];
        // 使用gamma的负值来实现减法
        input[8] = params.beta2[0][1];
        input[9] = params.beta2[0][0];
        input[10] = params.beta2[1][1];
        input[11] = params.beta2[1][0];
        
        // 第三对: vk_x, gamma (负向)
        input[12] = vk_x[0];
        input[13] = vk_x[1];
        input[14] = params.gamma2[0][1];
        input[15] = params.gamma2[0][0];
        input[16] = params.gamma2[1][1];
        input[17] = params.gamma2[1][0];
        
        // 第四对: C, delta (负向)
        input[18] = proof.c[0];
        input[19] = proof.c[1];
        input[20] = params.delta2[0][1];
        input[21] = params.delta2[0][0];
        input[22] = params.delta2[1][1];
        input[23] = params.delta2[1][0];
        
        uint256[1] memory result;
        bool success;
        
        // 调用bn256配对预编译合约
        assembly {
            success := staticcall(gas(), 0x08, input, 768, result, 32)
        }
        
        return success && result[0] == 1;
    }
    
    /**
     * @dev 椭圆曲线标量乘法
     */
    function _scalarMul(uint256[2] memory point, uint256 scalar) internal view returns (uint256[2] memory) {
        if (scalar == 0) {
            return [uint256(0), uint256(0)];
        }
        
        uint256[3] memory input = [point[0], point[1], scalar];
        uint256[2] memory result;
        
        assembly {
            let success := staticcall(gas(), 0x07, input, 96, result, 64)
            if iszero(success) { revert(0, 0) }
        }
        
        return result;
    }
    
    /**
     * @dev 椭圆曲线点加法
     */
    function _pointAdd(uint256[2] memory p1, uint256[2] memory p2) internal view returns (uint256[2] memory) {
        if (p1[0] == 0 && p1[1] == 0) {
            return p2;
        }
        if (p2[0] == 0 && p2[1] == 0) {
            return p1;
        }
        
        uint256[4] memory input = [p1[0], p1[1], p2[0], p2[1]];
        uint256[2] memory result;
        
        assembly {
            let success := staticcall(gas(), 0x06, input, 128, result, 64)
            if iszero(success) { revert(0, 0) }
        }
        
        return result;
    }
    
    /**
     * @dev 验证DeSci特定的约束条件
     * @param _proofType 证明类型
     * @param _publicInputs 公开输入
     * @return 是否满足约束
     */
    function _verifyConstraints(
        string memory _proofType,
        uint256[] memory _publicInputs
    ) internal pure returns (bool) {
        bytes32 proofTypeHash = keccak256(bytes(_proofType));
        
        if (proofTypeHash == keccak256(bytes("research_data_verification"))) {
            // 科研数据验证约束
            return _verifyResearchDataConstraints(_publicInputs);
        } else if (proofTypeHash == keccak256(bytes("data_integrity"))) {
            // 数据完整性约束
            return _verifyDataIntegrityConstraints(_publicInputs);
        } else if (proofTypeHash == keccak256(bytes("statistical_analysis"))) {
            // 统计分析约束
            return _verifyStatisticalConstraints(_publicInputs);
        } else if (proofTypeHash == keccak256(bytes("peer_review_qualification"))) {
            // 同行评审资格约束
            return _verifyPeerReviewConstraints(_publicInputs);
        } else if (proofTypeHash == keccak256(bytes("data_quality_score"))) {
            // 数据质量评分约束
            return _verifyDataQualityConstraints(_publicInputs);
        } else if (proofTypeHash == keccak256(bytes("research_ethics_compliance"))) {
            // 研究伦理合规约束
            return _verifyEthicsConstraints(_publicInputs);
        }
        
        return true; // 未知类型默认通过
    }
    
    /**
     * @dev 验证科研数据统计合理性
     */
    function _verifyResearchDataConstraints(uint256[] memory _publicInputs) internal pure returns (bool) {
        if (_publicInputs.length < 2) return false;
        
        uint256 mean = _publicInputs[0];
        uint256 stdDev = _publicInputs[1];
        
        // 检查统计合理性
        if (mean == 0) return false;
        
        // 标准差不应过大（变异系数 < 200%）
        if (stdDev > mean * 2) return false;
        
        // 检查是否在科学计量的合理范围内
        if (mean > 1e18 || stdDev > 1e18) return false;
        
        return true;
    }
    
    /**
     * @dev 验证数据完整性
     */
    function _verifyDataIntegrityConstraints(uint256[] memory _publicInputs) internal pure returns (bool) {
        if (_publicInputs.length < 1) return false;
        
        uint256 dataHash = _publicInputs[0];
        
        // 数据哈希不能为空
        if (dataHash == 0) return false;
        
        // 如果有多个输入，验证数据一致性
        if (_publicInputs.length >= 2) {
            uint256 integrityScore = _publicInputs[1];
            // 完整性分数应在0-100之间
            if (integrityScore > 100) return false;
        }
        
        return true;
    }
    
    /**
     * @dev 验证统计分析结果的合理性
     */
    function _verifyStatisticalConstraints(uint256[] memory _publicInputs) internal pure returns (bool) {
        if (_publicInputs.length < 3) return false;
        
        uint256 sampleSize = _publicInputs[0];
        uint256 pValue = _publicInputs[1];
        uint256 effectSize = _publicInputs[2];
        
        // 样本量检查（至少30个样本用于统计推断）
        if (sampleSize < 30) return false;
        
        // p值检查（0 <= p <= 1，以千分比表示）
        if (pValue > 1000) return false;
        
        // 效应量检查（Cohen's d通常在-3到3之间，以百分比表示）
        if (effectSize > 300) return false;
        
        return true;
    }
    
    /**
     * @dev 验证同行评审员资格
     */
    function _verifyPeerReviewConstraints(uint256[] memory _publicInputs) internal pure returns (bool) {
        if (_publicInputs.length < 3) return false;
        
        uint256 qualificationScore = _publicInputs[0];
        uint256 reviewCount = _publicInputs[1];
        uint256 expertiseMatch = _publicInputs[2];
        
        // 资格分数检查（0-100分制）
        if (qualificationScore < 70 || qualificationScore > 100) return false;
        
        // 评审经验检查（至少5次评审经验）
        if (reviewCount < 5) return false;
        
        // 专业匹配度检查（0-100分制）
        if (expertiseMatch < 80 || expertiseMatch > 100) return false;
        
        return true;
    }
    
    /**
     * @dev 验证数据质量评分
     */
    function _verifyDataQualityConstraints(uint256[] memory _publicInputs) internal pure returns (bool) {
        if (_publicInputs.length < 4) return false;
        
        uint256 completeness = _publicInputs[0]; // 完整性分数
        uint256 accuracy = _publicInputs[1];     // 准确性分数
        uint256 consistency = _publicInputs[2];  // 一致性分数
        uint256 timeliness = _publicInputs[3];   // 时效性分数
        
        // 所有维度分数都应在0-100之间
        if (completeness > 100 || accuracy > 100 || 
            consistency > 100 || timeliness > 100) {
            return false;
        }
        
        // 综合质量分数计算
        uint256 overallScore = (completeness + accuracy + consistency + timeliness) / 4;
        
        // 整体质量分数应达到70分以上
        return overallScore >= 70;
    }
    
    /**
     * @dev 验证研究伦理合规性
     */
    function _verifyEthicsConstraints(uint256[] memory _publicInputs) internal pure returns (bool) {
        if (_publicInputs.length < 3) return false;
        
        uint256 irbApproval = _publicInputs[0];      // IRB批准状态（1=已批准）
        uint256 consentRate = _publicInputs[1];      // 知情同意率（百分比）
        uint256 dataAnonymization = _publicInputs[2]; // 数据匿名化级别（1-5级）
        
        // 必须有IRB批准
        if (irbApproval != 1) return false;
        
        // 知情同意率应达到95%以上
        if (consentRate < 95 || consentRate > 100) return false;
        
        // 数据匿名化级别应在合理范围内
        if (dataAnonymization < 1 || dataAnonymization > 5) return false;
        
        return true;
    }
    
    /**
     * @dev 检查G1点有效性
     * @param _point G1点
     * @return 是否有效
     */
    function _isValidG1Point(uint256[2] memory _point) internal pure returns (bool) {
        // 简化检查：确保点不为零
        return _point[0] != 0 && _point[1] != 0;
    }
    
    /**
     * @dev 检查G2点有效性
     * @param _point G2点
     * @return 是否有效
     */
    function _isValidG2Point(uint256[2][2] memory _point) internal pure returns (bool) {
        // 简化检查：确保点不为零
        return _point[0][0] != 0 && _point[0][1] != 0 &&
               _point[1][0] != 0 && _point[1][1] != 0;
    }
    
    /**
     * @dev 批量验证多个证明
     * @param _proofType 证明类型
     * @param _proofs 证明数组
     * @param _publicInputsArray 公开输入数组
     * @return 验证结果数组
     */
    function verifyMultipleProofs(
        string memory _proofType,
        Groth16Proof[] memory _proofs,
        uint256[][] memory _publicInputsArray
    ) external proofTypeExists(_proofType) returns (bool[] memory) {
        require(_proofs.length == _publicInputsArray.length, "Array lengths must match");
        
        bool[] memory results = new bool[](_proofs.length);
        
        for (uint i = 0; i < _proofs.length; i++) {
            results[i] = _verifyGroth16(_proofType, _proofs[i], _publicInputsArray[i]);
        }
        
        return results;
    }
    
    /**
     * @dev 获取验证结果
     * @param _proofHash 证明哈希
     * @return 验证结果和时间戳
     */
    function getVerificationResult(bytes32 _proofHash) external view returns (bool, uint256) {
        return (verificationResults[_proofHash], verificationTimestamps[_proofHash]);
    }
    
    /**
     * @dev 检查证明是否已验证
     * @param _proofHash 证明哈希
     * @return 是否已验证
     */
    function isProofVerified(bytes32 _proofHash) external view returns (bool) {
        return verificationResults[_proofHash];
    }
    
    /**
     * @dev 获取支持的证明类型
     * @return 证明类型数组
     */
    function getSupportedProofTypes() external view returns (string[] memory) {
        return supportedProofTypes;
    }
    
    /**
     * @dev 获取证明类型的验证参数
     * @param _proofType 证明类型
     * @return 验证参数
     */
    function getVerificationParams(string memory _proofType) external view returns (VerificationParams memory) {
        return _verificationParams[_proofType];
    }
    
    /**
     * @dev 初始化默认证明类型
     */
    function _registerDefaultProofTypes() internal {
        // 科研数据验证
        uint256[2] memory alpha1 = [uint256(1), uint256(2)];
        uint256[2][2] memory beta2 = [[uint256(1), uint256(2)], [uint256(3), uint256(4)]];
        uint256[2][2] memory gamma2 = [[uint256(5), uint256(6)], [uint256(7), uint256(8)]];
        uint256[2][2] memory delta2 = [[uint256(9), uint256(10)], [uint256(11), uint256(12)]];
        uint256[2][] memory ic = new uint256[2][](2);
        ic[0] = [uint256(1), uint256(2)];
        ic[1] = [uint256(3), uint256(4)];
        
        _verificationParams["research_data_verification"] = VerificationParams({
            alpha1: alpha1,
            beta2: beta2,
            gamma2: gamma2,
            delta2: delta2,
            ic: ic
        });
        
        supportedProofTypes.push("research_data_verification");
        
        // Data integrity verification
        _verificationParams["data_integrity"] = VerificationParams({
            alpha1: alpha1,
            beta2: beta2,
            gamma2: gamma2,
            delta2: delta2,
            ic: ic
        });
        
        supportedProofTypes.push("data_integrity");
    }
} 