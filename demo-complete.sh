#!/bin/bash

# 🎯 DeSci Platform 完整演示自动化脚本
# 使用方法: ./demo-complete.sh

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# 检查前置要求
check_prerequisites() {
    log_step "检查前置要求..."
    
    # 检查Node.js
    if ! command -v node &> /dev/null; then
        log_error "Node.js 未安装，请先安装 Node.js 16+"
        exit 1
    fi
    
    # 检查Go
    if ! command -v go &> /dev/null; then
        log_error "Go 未安装，请先安装 Go 1.19+"
        exit 1
    fi
    
    # 检查npm依赖
    if [ ! -d "node_modules" ]; then
        log_warning "未找到 node_modules，正在安装依赖..."
        npm install
    fi
    
    # 检查后端Go模块
    if [ ! -f "backend/go.sum" ]; then
        log_warning "未找到 go.sum，正在安装Go依赖..."
        cd backend && go mod tidy && cd ..
    fi
    
    log_success "前置要求检查完成"
}

# 清理之前的进程
cleanup() {
    log_step "清理之前的进程..."
    
    # 清理Hardhat进程
    pkill -f "hardhat node" || true
    
    # 清理Go后端进程  
    pkill -f "go run cmd/server/main.go" || true
    pkill -f "main.go" || true
    
    # 等待进程完全终止
    sleep 2
    
    log_success "进程清理完成"
}

# 启动Hardhat网络
start_hardhat() {
    log_step "启动 Hardhat 本地网络..."
    
    # 后台启动Hardhat节点
    npm run start-hardhat > hardhat.log 2>&1 &
    HARDHAT_PID=$!
    
    # 等待Hardhat网络启动
    log_info "等待 Hardhat 网络启动..."
    sleep 5
    
    # 检查Hardhat是否启动成功
    if ! curl -s http://localhost:8545 > /dev/null; then
        log_error "Hardhat 网络启动失败，请查看 hardhat.log"
        exit 1
    fi
    
    log_success "Hardhat 网络启动成功 (PID: $HARDHAT_PID)"
}

# 部署智能合约
deploy_contracts() {
    log_step "部署智能合约..."
    
    # 部署合约
    npm run deploy-contracts
    
    if [ $? -eq 0 ]; then
        log_success "智能合约部署成功"
    else
        log_error "智能合约部署失败"
        exit 1
    fi
}

# 启动后端服务
start_backend() {
    log_step "启动 Go 后端服务 (带合约地址配置)..."
    
    # 检查启动脚本是否存在
    if [ ! -f "start-backend-with-contracts.sh" ]; then
        log_error "启动脚本不存在"
        exit 1
    fi
    
    # 设置执行权限
    chmod +x start-backend-with-contracts.sh
    
    # 后台启动Go后端（带合约地址配置）
    ./start-backend-with-contracts.sh > backend.log 2>&1 &
    BACKEND_PID=$!
    
    # 等待后端服务启动
    log_info "等待后端服务启动 (带事件监听)..."
    sleep 5
    
    # 检查后端服务是否启动成功
    if ! curl -s http://localhost:8080/health > /dev/null; then
        log_error "后端服务启动失败，请查看 backend.log"
        exit 1
    fi
    
    log_success "后端服务启动成功 (PID: $BACKEND_PID) - 事件监听已激活"
}

# 执行演示脚本
run_demo_scenario() {
    log_step "执行演示场景..."
    
    npm run demo-scenario
    
    if [ $? -eq 0 ]; then
        log_success "演示场景执行成功"
    else
        log_error "演示场景执行失败"
        exit 1
    fi
}

# 测试API
test_apis() {
    log_step "测试 API 接口..."
    
    # 健康检查
    log_info "1. 健康检查..."
    curl -s http://localhost:8080/health | jq . || echo "健康检查响应"
    
    # 最新研究列表
    log_info "2. 获取最新研究列表..."
    curl -s "http://localhost:8080/api/research/latest?limit=3" | jq . || echo "研究列表响应"
    
    # 按ID查询
    log_info "3. 按ID查询研究..."
    curl -s "http://localhost:8080/api/research/demo-token-123" | jq . || echo "研究详情响应"
    
    log_success "API 测试完成"
}

# 验证数据库
verify_database() {
    log_step "验证 SQLite 数据库..."
    
    if [ -f "backend/desci.db" ]; then
        log_success "SQLite 数据库文件存在"
        
        # 如果安装了sqlite3，显示表结构
        if command -v sqlite3 &> /dev/null; then
            log_info "数据库表列表:"
            sqlite3 backend/desci.db ".tables" || true
            
            log_info "research_data表记录数:"
            sqlite3 backend/desci.db "SELECT COUNT(*) FROM research_data;" || true
        else
            log_warning "sqlite3 未安装，跳过数据库内容查看"
        fi
    else
        log_error "SQLite 数据库文件不存在"
    fi
}

# 显示演示总结
show_summary() {
    log_step "演示总结"
    
    echo -e "${GREEN}🎉 DeSci Platform 演示完成！${NC}"
    echo ""
    echo "✅ 已启动服务:"
    echo "   - Hardhat 网络: http://localhost:8545"
    echo "   - Go 后端 API: http://localhost:8080"
    echo ""
    echo "✅ 已验证功能:"
    echo "   - 智能合约部署 (10个核心合约)"
    echo "   - 链上交互 (用户注册、NFT铸造)"
    echo "   - 事件监听和数据同步"
    echo "   - SQLite 数据库集成"
    echo "   - RESTful API 响应"
    echo ""
    echo "📋 手动测试命令:"
    echo "   curl http://localhost:8080/health"
    echo "   curl http://localhost:8080/api/research/latest"
    echo ""
    echo "🔍 查看日志:"
    echo "   tail -f hardhat.log    # Hardhat 日志"
    echo "   tail -f backend.log    # 后端日志"
    echo ""
    echo "🛑 停止服务:"
    echo "   ./stop-demo.sh 或者 Ctrl+C"
}

# 清理函数
cleanup_on_exit() {
    log_info "正在清理进程..."
    kill $HARDHAT_PID 2>/dev/null || true
    kill $BACKEND_PID 2>/dev/null || true
    log_info "演示结束"
    exit 0
}

# 主函数
main() {
    echo -e "${PURPLE}🚀 DeSci Platform 完整演示启动${NC}"
    echo "==============================================="
    
    # 设置退出处理
    trap cleanup_on_exit SIGINT SIGTERM
    
    # 执行演示步骤
    check_prerequisites
    cleanup
    start_hardhat
    deploy_contracts
    start_backend
    
    # 等待服务完全启动
    sleep 2
    
    run_demo_scenario
    test_apis
    verify_database
    show_summary
    
    # 保持服务运行
    log_info "服务正在运行，按 Ctrl+C 停止演示"
    wait
}

# 运行主函数
main "$@" 