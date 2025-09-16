-- 数据库初始化脚本
-- 创建 DeSci 平台链下数据库

-- 研究数据表
CREATE TABLE research_data (
    id BIGSERIAL PRIMARY KEY,
    token_id BIGINT NOT NULL UNIQUE,
    title VARCHAR(500) NOT NULL,
    description TEXT,
    data_hash VARCHAR(66) NOT NULL,
    ipfs_hash VARCHAR(100),
    author_address VARCHAR(42) NOT NULL,
    category VARCHAR(100),
    tags TEXT[],
    citation_count INTEGER DEFAULT 0,
    download_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    block_number BIGINT NOT NULL,
    transaction_hash VARCHAR(66) NOT NULL,
    
    -- 索引
    CONSTRAINT research_data_token_id_key UNIQUE (token_id),
    CONSTRAINT research_data_data_hash_key UNIQUE (data_hash)
);

-- 用户档案表
CREATE TABLE user_profiles (
    id BIGSERIAL PRIMARY KEY,
    user_address VARCHAR(42) UNIQUE NOT NULL,
    username VARCHAR(100),
    bio TEXT,
    avatar_url VARCHAR(500),
    research_areas TEXT[],
    affiliation VARCHAR(200),
    orcid_id VARCHAR(50),
    h_index INTEGER DEFAULT 0,
    total_citations INTEGER DEFAULT 0,
    total_publications INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- 索引
    CONSTRAINT user_profiles_user_address_key UNIQUE (user_address)
);

-- 数据集表
CREATE TABLE datasets (
    id BIGSERIAL PRIMARY KEY,
    dataset_id BIGINT NOT NULL UNIQUE,
    name VARCHAR(500) NOT NULL,
    description TEXT,
    category VARCHAR(100),
    data_hash VARCHAR(66) NOT NULL,
    ipfs_hash VARCHAR(100),
    creator_address VARCHAR(42) NOT NULL,
    is_public BOOLEAN DEFAULT false,
    file_size BIGINT,
    file_format VARCHAR(50),
    license VARCHAR(100),
    access_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    block_number BIGINT NOT NULL,
    transaction_hash VARCHAR(66) NOT NULL,
    
    -- 索引
    CONSTRAINT datasets_dataset_id_key UNIQUE (dataset_id),
    CONSTRAINT datasets_data_hash_key UNIQUE (data_hash)
);

-- 数据集访问权限表
CREATE TABLE dataset_permissions (
    id BIGSERIAL PRIMARY KEY,
    dataset_id BIGINT NOT NULL,
    user_address VARCHAR(42) NOT NULL,
    permission_type VARCHAR(20) NOT NULL, -- 'read', 'write', 'admin'
    granted_by VARCHAR(42) NOT NULL,
    granted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    
    -- 外键约束
    FOREIGN KEY (dataset_id) REFERENCES datasets(dataset_id) ON DELETE CASCADE,
    -- 唯一约束
    UNIQUE (dataset_id, user_address, permission_type)
);

-- 影响力排名表
CREATE TABLE influence_rankings (
    id BIGSERIAL PRIMARY KEY,
    user_address VARCHAR(42) NOT NULL,
    rank_position INTEGER NOT NULL,
    influence_score DECIMAL(10, 2) NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- 索引
    UNIQUE (user_address, period_start, period_end)
);

-- 研究数据引用关系表
CREATE TABLE research_citations (
    id BIGSERIAL PRIMARY KEY,
    citing_token_id BIGINT NOT NULL,
    cited_token_id BIGINT NOT NULL,
    citation_type VARCHAR(50), -- 'reference', 'dataset', 'methodology'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- 外键约束
    FOREIGN KEY (citing_token_id) REFERENCES research_data(token_id) ON DELETE CASCADE,
    FOREIGN KEY (cited_token_id) REFERENCES research_data(token_id) ON DELETE CASCADE,
    -- 唯一约束，防止重复引用
    UNIQUE (citing_token_id, cited_token_id)
);

-- 区块链事件日志表
CREATE TABLE blockchain_events (
    id BIGSERIAL PRIMARY KEY,
    event_name VARCHAR(100) NOT NULL,
    contract_address VARCHAR(42) NOT NULL,
    transaction_hash VARCHAR(66) NOT NULL,
    block_number BIGINT NOT NULL,
    log_index INTEGER NOT NULL,
    event_data JSONB NOT NULL,
    processed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- 唯一约束，防止重复处理同一事件
    UNIQUE (transaction_hash, log_index)
);

-- 数据验证记录表
CREATE TABLE data_verifications (
    id BIGSERIAL PRIMARY KEY,
    content_type VARCHAR(50) NOT NULL, -- 'research_data', 'dataset'
    content_id BIGINT NOT NULL,
    verification_type VARCHAR(50) NOT NULL, -- 'hash_check', 'ipfs_check'
    verification_result BOOLEAN NOT NULL,
    error_message TEXT,
    verified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- 索引
    INDEX idx_content_verification (content_type, content_id, verified_at)
);

-- 创建索引以提高查询性能
CREATE INDEX idx_research_data_author ON research_data(author_address);
CREATE INDEX idx_research_data_category ON research_data(category);
CREATE INDEX idx_research_data_created_at ON research_data(created_at);
CREATE INDEX idx_research_data_tags ON research_data USING GIN(tags);

CREATE INDEX idx_datasets_creator ON datasets(creator_address);
CREATE INDEX idx_datasets_category ON datasets(category);
CREATE INDEX idx_datasets_public ON datasets(is_public);
CREATE INDEX idx_datasets_created_at ON datasets(created_at);

CREATE INDEX idx_user_profiles_research_areas ON user_profiles USING GIN(research_areas);

CREATE INDEX idx_blockchain_events_contract ON blockchain_events(contract_address);
CREATE INDEX idx_blockchain_events_block ON blockchain_events(block_number);
CREATE INDEX idx_blockchain_events_name ON blockchain_events(event_name);

CREATE INDEX idx_influence_rankings_period ON influence_rankings(period_start, period_end);
CREATE INDEX idx_influence_rankings_score ON influence_rankings(influence_score DESC);

-- 创建全文搜索索引
CREATE INDEX idx_research_data_fulltext ON research_data USING gin(to_tsvector('english', title || ' ' || description));
CREATE INDEX idx_datasets_fulltext ON datasets USING gin(to_tsvector('english', name || ' ' || description));

-- 创建视图以简化常用查询
CREATE VIEW research_data_with_author AS
SELECT 
    rd.*,
    up.username,
    up.affiliation,
    up.orcid_id
FROM research_data rd
LEFT JOIN user_profiles up ON rd.author_address = up.user_address;

CREATE VIEW dataset_with_creator AS
SELECT 
    d.*,
    up.username,
    up.affiliation
FROM datasets d
LEFT JOIN user_profiles up ON d.creator_address = up.user_address;

-- 创建函数以更新时间戳
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 创建触发器自动更新 updated_at 字段
CREATE TRIGGER update_research_data_updated_at BEFORE UPDATE ON research_data FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON user_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_datasets_updated_at BEFORE UPDATE ON datasets FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
