#!/bin/bash

# 🛑 DeSci Platform 演示停止脚本

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo -e "${RED}🛑 停止 DeSci Platform 演示${NC}"
echo "==============================="

log_info "正在停止相关进程..."

# 停止Hardhat进程
log_info "停止 Hardhat 网络..."
pkill -f "hardhat node" && log_success "Hardhat 进程已停止" || log_info "没有找到 Hardhat 进程"

# 停止Go后端进程
log_info "停止 Go 后端服务..."
pkill -f "go run cmd/server/main.go" && log_success "Go后端进程已停止" || log_info "没有找到 Go后端进程"
pkill -f "main.go" && log_success "Go进程已停止" || log_info "没有找到 Go进程"

# 停止可能的npm进程
log_info "停止其他相关进程..."
pkill -f "npm run" || true

# 等待进程完全终止
sleep 2

# 清理日志文件
log_info "清理日志文件..."
rm -f hardhat.log backend.log

# 检查端口是否释放
log_info "检查端口状态..."
if lsof -i :8545 > /dev/null 2>&1; then
    log_error "端口 8545 仍被占用"
    lsof -i :8545
else
    log_success "端口 8545 已释放"
fi

if lsof -i :8080 > /dev/null 2>&1; then
    log_error "端口 8080 仍被占用"
    lsof -i :8080
else
    log_success "端口 8080 已释放"
fi

log_success "演示已完全停止"

# 可选：清理数据库文件
read -p "是否删除演示数据库文件? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -f backend/desci.db
    log_success "数据库文件已删除"
fi 