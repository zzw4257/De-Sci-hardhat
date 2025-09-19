const axios = require('axios');

// 配置
const API_BASE = 'http://localhost:8080';

// 颜色输出
const colors = {
    green: '\x1b[32m',
    red: '\x1b[31m', 
    blue: '\x1b[34m',
    yellow: '\x1b[33m',
    reset: '\x1b[0m'
};

function log(color, message) {
    console.log(`${colors[color]}${message}${colors.reset}`);
}

function logStep(stepNum, description) {
    log('blue', `\n=== 步骤 ${stepNum}: ${description} ===`);
}

async function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function demoMVP() {
    try {
        log('green', '🚀 开始 DeSci MVP 演示');

        // 步骤1: 健康检查
        logStep(1, '健康检查 - 显示 last_event_block');
        try {
            const health = await axios.get(`${API_BASE}/health`);
            log('green', `✅ 服务状态: ${health.data.status}`);
            log('green', `✅ 数据库状态: ${health.data.db}`);
            log('green', `✅ 最后事件块: ${health.data.last_event_block}`);
        } catch (error) {
            log('red', `❌ 健康检查失败: ${error.message}`);
            return;
        }

        // 步骤2: 查看初始数据（应该有演示数据）
        logStep(2, '查询最新研究列表');
        try {
            const latest = await axios.get(`${API_BASE}/api/research/latest?limit=5`);
            log('green', `✅ 找到 ${latest.data.count} 条研究记录:`);
            latest.data.list.forEach((item, index) => {
                console.log(`   ${index + 1}. TokenID: ${item.token_id}, 标题: ${item.title}`);
                console.log(`      作者: ${item.authors.join(', ')}`);
                console.log(`      数据哈希: ${item.content_hash.substring(0, 20)}...`);
            });
        } catch (error) {
            log('red', `❌ 查询失败: ${error.message}`);
        }

        // 步骤3: 按ID查询特定研究
        logStep(3, '按TokenID查询特定研究');
        try {
            const research = await axios.get(`${API_BASE}/api/research/demo-token-123`);
            log('green', `✅ 研究详情:`);
            console.log(`   TokenID: ${research.data.token_id}`);
            console.log(`   标题: ${research.data.title}`);
            console.log(`   作者: ${research.data.authors.join(', ')}`);
            console.log(`   内容哈希: ${research.data.content_hash}`);
            console.log(`   创建时间: ${research.data.created_at}`);
        } catch (error) {
            log('red', `❌ 查询研究失败: ${error.message}`);
        }

        // 步骤4: 按作者查询研究
        logStep(4, '按作者地址查询研究');
        try {
            const byAuthor = await axios.get(`${API_BASE}/api/research/by-author/0x742d35Cc6731C0532925a3b8D4Ca78fC6fD7F4dC?limit=10`);
            log('green', `✅ 作者的研究列表 (${byAuthor.data.count} 条):`);
            byAuthor.data.list.forEach((item, index) => {
                console.log(`   ${index + 1}. TokenID: ${item.token_id}, 标题: ${item.title}`);
            });
        } catch (error) {
            log('red', `❌ 按作者查询失败: ${error.message}`);
        }

        // 步骤5: 验证正确的原文内容
        logStep(5, '验证正确原文内容 (应该返回 match=true)');
        try {
            const correctContent = "区块链在科学数据管理中的应用研究\n\n摘要：本研究探讨了区块链技术在科学数据管理中的创新应用，提出了基于智能合约的数据完整性验证方案。\n\n关键词：区块链，科学数据，数据完整性，智能合约\n\n1. 引言\n区块链技术作为一种分布式账本技术，具有去中心化、不可篡改、可追溯等特点...\n\n2. 相关工作\n近年来，越来越多的研究关注区块链在科学研究中的应用...\n\n3. 方法\n本研究设计了一个基于以太坊的科学数据管理平台...\n\n4. 结论\n实验结果表明，所提出的方案能够有效保证科学数据的完整性和可信度。";
            
            const verifyCorrect = await axios.post(`${API_BASE}/api/research/demo-token-123/verify`, {
                rawContent: correctContent
            });
            log('green', `✅ 验证结果: match = ${verifyCorrect.data.match}`);
            if (verifyCorrect.data.match) {
                log('green', '🎉 内容验证成功！哈希匹配');
            }
        } catch (error) {
            log('red', `❌ 验证失败: ${error.message}`);
        }

        // 步骤6: 验证错误的内容（修改一个字符）
        logStep(6, '验证错误内容 (修改一个字符，应该返回 match=false)');
        try {
            const wrongContent = "区块链在科学数据管理中的应用研究\n\n摘要：本研究探讨了区块链技术在科学数据管理中的创新应用，提出了基于智能合约的数据完整性验证方案。\n\n关键词：区块链，科学数据，数据完整性，智能合约\n\n1. 引言\n区块链技术作为一种分布式账本技术，具有去中心化、不可篡改、可追溯等特点...\n\n2. 相关工作\n近年来，越来越多的研究关注区块链在科学研究中的应用...\n\n3. 方法\n本研究设计了一个基于以太坊的科学数据管理平台...\n\n4. 结论\n实验结果表明，所提出的方案能够有效保证科学数据的完整性和可信度！"; // 最后添加了感叹号
            
            const verifyWrong = await axios.post(`${API_BASE}/api/research/demo-token-123/verify`, {
                rawContent: wrongContent
            });
            log('yellow', `⚠️  验证结果: match = ${verifyWrong.data.match}`);
            if (!verifyWrong.data.match) {
                log('green', '✅ 预期结果：内容不匹配，哈希验证失败');
            }
        } catch (error) {
            log('red', `❌ 验证失败: ${error.message}`);
        }

        // 步骤7: 测试不存在的研究ID
        logStep(7, '测试查询不存在的研究ID');
        try {
            await axios.get(`${API_BASE}/api/research/nonexistent-id`);
        } catch (error) {
            if (error.response && error.response.status === 404) {
                log('green', '✅ 正确返回404 Not Found');
            } else {
                log('red', `❌ 意外错误: ${error.message}`);
            }
        }

        // 最后再次检查健康状态
        logStep(8, '最终健康检查');
        try {
            const finalHealth = await axios.get(`${API_BASE}/health`);
            log('green', `✅ 最终状态: ${finalHealth.data.status}`);
            log('green', `✅ 数据库: ${finalHealth.data.db}`);
            log('green', `✅ 最后事件块: ${finalHealth.data.last_event_block}`);
        } catch (error) {
            log('red', `❌ 最终健康检查失败: ${error.message}`);
        }

        log('green', '\n🎉 MVP演示完成！');
        log('blue', '\n📊 演示总结:');
        console.log('   ✅ 事件驱动架构 - 链上写链下读机制');
        console.log('   ✅ 数据可追溯 - DB记录包含txHash/blockNumber'); 
        console.log('   ✅ 哈希校验 - keccak256验证数据完整性');
        console.log('   ✅ 查询API - ID查/作者查/最新列表');
        console.log('   ✅ 健康状态 - 返回last_event_block');

    } catch (error) {
        log('red', `❌ 演示过程中发生错误: ${error.message}`);
    }
}

// 检查服务器是否运行
async function checkServer() {
    try {
        await axios.get(`${API_BASE}/health`);
        return true;
    } catch (error) {
        return false;
    }
}

// 主函数
async function main() {
    log('blue', '正在检查后端服务器...');
    
    const serverRunning = await checkServer();
    if (!serverRunning) {
        log('red', '❌ 后端服务器未运行！');
        log('yellow', '请先启动后端服务器:');
        log('yellow', '  cd backend && go run cmd/server/main.go');
        process.exit(1);
    }
    
    log('green', '✅ 后端服务器正在运行');
    await sleep(1000);
    
    await demoMVP();
}

if (require.main === module) {
    main();
}

module.exports = { demoMVP }; 