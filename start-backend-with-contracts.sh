#!/bin/bash

# 🚀 DeSci 后端启动脚本 - 自动配置合约地址

set -e

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo -e "${GREEN}🚀 启动 DeSci 后端服务 (带合约地址配置)${NC}"
echo "=================================================="

# 检查合约部署文件是否存在
DEPLOYMENT_FILE="deployments/enhanced-desci-deployment.json"

if [ ! -f "$DEPLOYMENT_FILE" ]; then
    log_error "未找到合约部署文件: $DEPLOYMENT_FILE"
    log_info "请先运行合约部署："
    echo "  npm run deploy-contracts"
    exit 1
fi

log_info "读取合约地址配置..."

# 使用jq读取JSON配置 (如果没有jq，则使用python)
if command -v jq &> /dev/null; then
    # 使用jq解析JSON
    DESCI_REGISTRY_ADDRESS=$(jq -r '.contracts.userRegistry' "$DEPLOYMENT_FILE")
    RESEARCH_NFT_ADDRESS=$(jq -r '.contracts.researchNFT' "$DEPLOYMENT_FILE")
    DATASET_MANAGER_ADDRESS=$(jq -r '.contracts.datasetManager' "$DEPLOYMENT_FILE")
    INFLUENCE_RANKING_ADDRESS=$(jq -r '.contracts.influenceRanking' "$DEPLOYMENT_FILE")
    DESCI_PLATFORM_ADDRESS=$(jq -r '.contracts.platform' "$DEPLOYMENT_FILE")
else
    # 使用python解析JSON
    log_warning "jq未安装，使用python解析JSON..."
    ADDRESSES=$(python3 -c "
import json
with open('$DEPLOYMENT_FILE', 'r') as f:
    data = json.load(f)
    contracts = data['contracts']
    print(f\"{contracts['userRegistry']}|{contracts['researchNFT']}|{contracts['datasetManager']}|{contracts['influenceRanking']}|{contracts['platform']}\")
")
    
    IFS='|' read -ra ADDR_ARRAY <<< "$ADDRESSES"
    DESCI_REGISTRY_ADDRESS="${ADDR_ARRAY[0]}"
    RESEARCH_NFT_ADDRESS="${ADDR_ARRAY[1]}"
    DATASET_MANAGER_ADDRESS="${ADDR_ARRAY[2]}"
    INFLUENCE_RANKING_ADDRESS="${ADDR_ARRAY[3]}"
    DESCI_PLATFORM_ADDRESS="${ADDR_ARRAY[4]}"
fi

# 验证地址不为空
if [ -z "$DESCI_REGISTRY_ADDRESS" ] || [ "$DESCI_REGISTRY_ADDRESS" = "null" ]; then
    log_error "无法读取合约地址，请检查部署文件格式"
    exit 1
fi

log_success "合约地址读取成功！"
echo ""
echo "📋 合约地址配置："
echo "   DeSciRegistry    : $DESCI_REGISTRY_ADDRESS"
echo "   ResearchNFT      : $RESEARCH_NFT_ADDRESS" 
echo "   DatasetManager   : $DATASET_MANAGER_ADDRESS"
echo "   InfluenceRanking : $INFLUENCE_RANKING_ADDRESS"
echo "   DeSciPlatform    : $DESCI_PLATFORM_ADDRESS"
echo ""

# 设置环境变量并启动Go后端
log_info "启动Go后端服务..."

cd backend

# 导出环境变量
export PORT=8080
export ETHEREUM_RPC=http://localhost:8545
export START_BLOCK=0
export DATABASE_URL=sqlite://desci.db
export DESCI_REGISTRY_ADDRESS="$DESCI_REGISTRY_ADDRESS"
export RESEARCH_NFT_ADDRESS="$RESEARCH_NFT_ADDRESS"
export DATASET_MANAGER_ADDRESS="$DATASET_MANAGER_ADDRESS"  
export INFLUENCE_RANKING_ADDRESS="$INFLUENCE_RANKING_ADDRESS"
export DESCI_PLATFORM_ADDRESS="$DESCI_PLATFORM_ADDRESS"

log_success "环境变量已设置"
log_info "正在启动Go服务器..."

# 启动Go后端服务
exec go run cmd/server/main.go 