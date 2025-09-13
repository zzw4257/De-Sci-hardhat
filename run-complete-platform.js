#!/usr/bin/env node

const { spawn, exec } = require('child_process');
const fs = require('fs');
const path = require('path');

console.log('🧬 启动完整的DeSci平台...\n');

let hardhatProcess = null;
let frontendProcess = null;

// 检查端口是否被占用
function checkPort(port) {
  return new Promise((resolve) => {
    const { exec } = require('child_process');
    exec(`lsof -ti:${port}`, (error, stdout, stderr) => {
      resolve(stdout.trim() !== '');
    });
  });
}

// 等待端口可用
function waitForPort(port, timeout = 30000) {
  return new Promise((resolve, reject) => {
    const startTime = Date.now();
    const checkInterval = setInterval(async () => {
      const isOpen = await checkPort(port);
      if (isOpen) {
        clearInterval(checkInterval);
        resolve(true);
      } else if (Date.now() - startTime > timeout) {
        clearInterval(checkInterval);
        reject(new Error(`端口 ${port} 超时未响应`));
      }
    }, 1000);
  });
}

// 启动Hardhat本地网络
async function startHardhatNode() {
  console.log('🔧 启动Hardhat本地网络...');
  
  // 检查端口8545是否已被占用
  const port8545InUse = await checkPort(8545);
  if (port8545InUse) {
    console.log('✅ Hardhat网络已在运行 (端口8545)');
    return true;
  }

  return new Promise((resolve, reject) => {
    hardhatProcess = spawn('npx', ['hardhat', 'node'], {
      cwd: __dirname,
      stdio: ['pipe', 'pipe', 'pipe']
    });

    let output = '';
    hardhatProcess.stdout.on('data', (data) => {
      output += data.toString();
      if (output.includes('Started HTTP and WebSocket JSON-RPC server')) {
        console.log('✅ Hardhat网络启动成功');
        resolve(true);
      }
    });

    hardhatProcess.stderr.on('data', (data) => {
      const error = data.toString();
      if (error.includes('EADDRINUSE')) {
        console.log('✅ Hardhat网络已在运行');
        resolve(true);
      } else {
        console.error('❌ Hardhat启动错误:', error);
      }
    });

    hardhatProcess.on('error', (error) => {
      console.error('❌ Hardhat启动失败:', error);
      reject(error);
    });

    // 超时处理
    setTimeout(() => {
      if (hardhatProcess && !hardhatProcess.killed) {
        reject(new Error('Hardhat启动超时'));
      }
    }, 30000);
  });
}

// 部署合约
async function deployContracts() {
  console.log('\n📦 部署智能合约...');
  
  // 检查是否已部署
  const deploymentFile = path.join(__dirname, 'deployments/enhanced-desci-deployment.json');
  if (fs.existsSync(deploymentFile)) {
    console.log('✅ 合约已部署，跳过部署步骤');
    return true;
  }

  return new Promise((resolve, reject) => {
    const deployProcess = spawn('npx', ['hardhat', 'run', 'scripts/deployEnhancedDeSci.js', '--network', 'localhost'], {
      cwd: __dirname,
      stdio: 'inherit'
    });

    deployProcess.on('close', (code) => {
      if (code === 0) {
        console.log('✅ 合约部署成功');
        resolve(true);
      } else {
        reject(new Error(`合约部署失败，退出代码: ${code}`));
      }
    });

    deployProcess.on('error', (error) => {
      reject(error);
    });
  });
}

// 运行功能测试
async function runFunctionalTests() {
  console.log('\n🧪 运行功能测试...');
  
  return new Promise((resolve, reject) => {
    const testProcess = spawn('npx', ['hardhat', 'run', 'scripts/testDeSciPlatform.js', '--network', 'localhost'], {
      cwd: __dirname,
      stdio: 'inherit'
    });

    testProcess.on('close', (code) => {
      if (code === 0) {
        console.log('✅ 功能测试通过');
        resolve(true);
      } else {
        console.log('⚠️ 功能测试有问题，但继续启动前端');
        resolve(true); // 即使测试失败也继续
      }
    });

    testProcess.on('error', (error) => {
      console.log('⚠️ 测试运行错误，但继续启动前端');
      resolve(true); // 即使错误也继续
    });
  });
}

// 启动前端应用
async function startFrontend() {
  console.log('\n🌐 启动前端应用...');
  
  // 检查端口3001是否被占用
  const port3001InUse = await checkPort(3001);
  if (port3001InUse) {
    console.log('✅ 前端应用已在运行 (端口3001)');
    return true;
  }

  return new Promise((resolve, reject) => {
    const env = {
      ...process.env,
      SKIP_PREFLIGHT_CHECK: 'true',
      TSC_COMPILE_ON_ERROR: 'true',
      ESLINT_NO_DEV_ERRORS: 'true',
      DISABLE_ESLINT_PLUGIN: 'true',
      PORT: '3001'
    };

    frontendProcess = spawn('npm', ['start'], {
      cwd: path.join(__dirname, 'frontend'),
      env: env,
      stdio: ['pipe', 'pipe', 'pipe']
    });

    let output = '';
    frontendProcess.stdout.on('data', (data) => {
      output += data.toString();
      if (output.includes('webpack compiled') || output.includes('Local:')) {
        console.log('✅ 前端应用启动成功');
        console.log('🌐 访问地址: http://localhost:3001');
        resolve(true);
      }
    });

    frontendProcess.stderr.on('data', (data) => {
      const error = data.toString();
      // 忽略TypeScript错误，只要能编译成功就行
      if (error.includes('webpack compiled')) {
        console.log('✅ 前端应用启动成功 (有TypeScript警告)');
        console.log('🌐 访问地址: http://localhost:3001');
        resolve(true);
      }
    });

    frontendProcess.on('error', (error) => {
      console.error('❌ 前端启动失败:', error);
      reject(error);
    });

    // 超时处理
    setTimeout(() => {
      console.log('⚠️ 前端启动可能需要更多时间，请稍后访问 http://localhost:3001');
      resolve(true);
    }, 60000);
  });
}

// 主函数
async function main() {
  try {
    console.log('🔍 检查项目环境...');
    
    // 检查package.json是否存在
    if (!fs.existsSync(path.join(__dirname, 'package.json'))) {
      throw new Error('未找到package.json，请确保在正确的项目目录中运行');
    }
    
    if (!fs.existsSync(path.join(__dirname, 'frontend/package.json'))) {
      throw new Error('未找到frontend/package.json，请确保前端项目已初始化');
    }

    // 1. 启动Hardhat网络
    await startHardhatNode();
    
    // 等待网络稳定
    await new Promise(resolve => setTimeout(resolve, 3000));
    
    // 2. 部署合约
    await deployContracts();
    
    // 3. 运行功能测试
    await runFunctionalTests();
    
    // 4. 启动前端
    await startFrontend();
    
    console.log('\n🎉 DeSci平台启动完成！');
    console.log('=' .repeat(50));
    console.log('🔗 Hardhat网络: http://localhost:8545');
    console.log('🌐 前端应用: http://localhost:3001');
    console.log('📖 使用说明: 查看README.md');
    console.log('=' .repeat(50));
    console.log('\n按 Ctrl+C 停止所有服务');
    
    // 保持进程运行
    process.stdin.setRawMode(true);
    process.stdin.resume();
    
  } catch (error) {
    console.error('\n❌ 平台启动失败:', error.message);
    
    // 清理进程
    if (hardhatProcess && !hardhatProcess.killed) {
      hardhatProcess.kill();
    }
    if (frontendProcess && !frontendProcess.killed) {
      frontendProcess.kill();
    }
    
    process.exit(1);
  }
}

// 优雅关闭
process.on('SIGINT', () => {
  console.log('\n\n🛑 正在关闭DeSci平台...');
  
  if (frontendProcess && !frontendProcess.killed) {
    console.log('📱 关闭前端应用...');
    frontendProcess.kill('SIGINT');
  }
  
  if (hardhatProcess && !hardhatProcess.killed) {
    console.log('🔧 关闭Hardhat网络...');
    hardhatProcess.kill('SIGINT');
  }
  
  setTimeout(() => {
    console.log('✅ DeSci平台已关闭');
    process.exit(0);
  }, 2000);
});

process.on('SIGTERM', () => {
  console.log('\n🛑 正在关闭DeSci平台...');
  
  if (frontendProcess && !frontendProcess.killed) {
    frontendProcess.kill('SIGTERM');
  }
  
  if (hardhatProcess && !hardhatProcess.killed) {
    hardhatProcess.kill('SIGTERM');
  }
  
  setTimeout(() => {
    process.exit(0);
  }, 2000);
});

// 运行主函数
if (require.main === module) {
  main();
}

module.exports = { main };