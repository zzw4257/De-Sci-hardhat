#!/bin/bash

# 测试覆盖率脚本
# 运行所有测试并生成覆盖率报告

echo "🧪 运行Go后端测试套件..."
echo "================================="

# 设置测试环境
export GO_ENV=test
export GIN_MODE=test

# 清理之前的覆盖率文件
rm -f coverage.out coverage.html

echo "📦 下载测试依赖..."
go mod tidy

echo ""
echo "🔍 运行单元测试和集成测试..."
echo "--------------------------------"

# 运行所有测试并生成覆盖率
go test -v -race -coverprofile=coverage.out -covermode=atomic ./internal/...

# 检查测试是否通过
if [ $? -ne 0 ]; then
    echo "❌ 测试失败！"
    exit 1
fi

echo ""
echo "📊 生成覆盖率报告..."
echo "----------------------"

# 生成覆盖率统计
go tool cover -func=coverage.out

# 生成HTML覆盖率报告
go tool cover -html=coverage.out -o coverage.html

# 提取总覆盖率
COVERAGE=$(go tool cover -func=coverage.out | grep total | awk '{print $3}' | sed 's/%//')

echo ""
echo "📈 测试覆盖率结果："
echo "==================="
echo "总覆盖率: ${COVERAGE}%"

# 检查是否达到80%覆盖率要求
if (( $(echo "$COVERAGE >= 80" | bc -l) )); then
    echo "✅ 测试覆盖率达标！(>= 80%)"
    echo "📄 详细报告已生成: coverage.html"
else
    echo "⚠️  测试覆盖率未达标！要求 >= 80%，当前 ${COVERAGE}%"
    echo "📄 详细报告已生成: coverage.html"
    exit 1
fi

echo ""
echo "🎯 测试完成！"
echo "============="
echo "- 所有测试通过 ✅"
echo "- 覆盖率达标 ✅"
echo "- 详细报告: coverage.html"
