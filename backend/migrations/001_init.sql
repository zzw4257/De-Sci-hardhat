-- 初始化数据库表结构

-- 研究数据表
CREATE TABLE IF NOT EXISTS research_data (
    id SERIAL PRIMARY KEY,
    token_id VARCHAR(255) NOT NULL UNIQUE,
    title TEXT NOT NULL,
    authors TEXT[] DEFAULT '{}',
    content_hash VARCHAR(255) NOT NULL,
    metadata_hash VARCHAR(255),
    block_number BIGINT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 数据集记录表
CREATE TABLE IF NOT EXISTS dataset_records (
    id SERIAL PRIMARY KEY,
    dataset_id VARCHAR(255) NOT NULL UNIQUE,
    title TEXT NOT NULL,
    description TEXT,
    owner VARCHAR(255) NOT NULL,
    data_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 事件日志表
CREATE TABLE IF NOT EXISTS event_logs (
    id SERIAL PRIMARY KEY,
    tx_hash VARCHAR(255) NOT NULL,
    log_index INTEGER NOT NULL,
    block_number BIGINT NOT NULL,
    event_name VARCHAR(255) NOT NULL,
    contract_address VARCHAR(255) NOT NULL,
    payload_raw TEXT,
    processed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- 复合唯一索引确保幂等性
    UNIQUE(tx_hash, log_index)
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_research_data_token_id ON research_data(token_id);
CREATE INDEX IF NOT EXISTS idx_dataset_records_dataset_id ON dataset_records(dataset_id);
CREATE INDEX IF NOT EXISTS idx_dataset_records_owner ON dataset_records(owner);
CREATE INDEX IF NOT EXISTS idx_event_logs_tx_hash ON event_logs(tx_hash);
CREATE INDEX IF NOT EXISTS idx_event_logs_block_number ON event_logs(block_number);
CREATE INDEX IF NOT EXISTS idx_event_logs_event_name ON event_logs(event_name);
CREATE INDEX IF NOT EXISTS idx_event_logs_processed ON event_logs(processed);
