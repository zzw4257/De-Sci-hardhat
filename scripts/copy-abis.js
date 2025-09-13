const fs = require('fs');
const path = require('path');

// 定义需要复制的合约列表
const contracts = [
  'DeSciRegistry',
  'DatasetManager',
  'ResearchNFT',
  'InfluenceRanking',
  'ZKProof',
  'DeSciPlatform'
];

// 源目录和目标目录
const sourceDir = path.join(__dirname, '..', 'artifacts', 'contracts');
const targetDir = path.join(__dirname, '..', 'frontend', 'src', 'contracts');

// 确保目标目录存在
if (!fs.existsSync(targetDir)) {
  fs.mkdirSync(targetDir, { recursive: true });
}

// 复制每个合约的ABI文件
contracts.forEach(contractName => {
  const sourcePath = path.join(sourceDir, `${contractName}.sol`, `${contractName}.json`);
  const targetPath = path.join(targetDir, `${contractName}.json`);
  
  try {
    if (fs.existsSync(sourcePath)) {
      const contractData = JSON.parse(fs.readFileSync(sourcePath, 'utf8'));
      const abiData = {
        abi: contractData.abi
      };
      
      fs.writeFileSync(targetPath, JSON.stringify(abiData, null, 2));
      console.log(`✅ 成功复制 ${contractName} ABI 到前端项目`);
    } else {
      console.log(`❌ 未找到 ${contractName} 合约文件: ${sourcePath}`);
    }
  } catch (error) {
    console.error(`❌ 复制 ${contractName} 时出错:`, error.message);
  }
});

console.log('ABI 文件复制完成！');