#!/bin/bash

# DeSci Backend 演示脚本

echo "🚀 DeSci Backend API 演示"
echo "=========================="

# 检查服务是否运行
if ! curl -s http://localhost:8088/health >/dev/null 2>&1; then
    echo "❌ 后端服务未运行，请先启动服务："
    echo "   cd backend && PORT=8088 ./main_simple &"
    exit 1
fi

echo "✅ 后端服务运行正常"
echo ""

# 1. 健康检查
echo "📊 1. 健康检查"
echo "curl http://localhost:8088/health"
curl -s http://localhost:8088/health
echo -e "\n"

# 2. 查看研究数据
echo "📖 2. 查看研究数据"
echo "curl http://localhost:8088/api/v1/research/123"
curl -s http://localhost:8088/api/v1/research/123
echo -e "\n"

# 3. 查看数据集
echo "📊 3. 查看数据集"
echo "curl http://localhost:8088/api/v1/dataset/456"
curl -s http://localhost:8088/api/v1/dataset/456
echo -e "\n"

# 4. 验证研究内容
echo "🔍 4. 验证研究内容"
echo "curl -X POST http://localhost:8088/api/v1/verify/research/789 -H \"Content-Type: application/json\" -d '{\"raw\":\"test data\"}'"
curl -s -X POST http://localhost:8088/api/v1/verify/research/789 \
     -H "Content-Type: application/json" \
     -d '{"raw":"test data"}'
echo -e "\n"

echo "✅ 所有API接口测试完成！"
echo ""
echo "📝 注意: 当前是简化版本，使用模拟数据响应"
echo "   - 所有数据都是Mock数据"
echo "   - 未连接真实数据库"
echo "   - 验证总是返回成功"
echo ""
echo "🔧 下一步: 连接数据库和区块链监听器"