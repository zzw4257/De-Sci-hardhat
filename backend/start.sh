#!/bin/bash

# DeSci Backend 启动脚本

echo "🚀 启动 DeSci Backend 服务"
echo "========================="

# 检查依赖
if ! command -v go &> /dev/null; then
    echo "❌ Go 未安装，请先安装 Go"
    exit 1
fi

# 进入backend目录
cd "$(dirname "$0")"

# 安装依赖
echo "📦 安装依赖..."
go mod tidy

# 编译项目
echo "🔨 编译项目..."
go build -o main_simple cmd/server/main_simple.go

if [ $? -ne 0 ]; then
    echo "❌ 编译失败"
    exit 1
fi

# 启动服务
echo "✅ 编译成功"
echo "🌐 启动服务在端口 8088..."
PORT=8088 ./main_simple