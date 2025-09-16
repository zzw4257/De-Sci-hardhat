import dotenv from 'dotenv';

dotenv.config();

interface Config {
  nodeEnv: string;
  port: number;
  database: {
    host: string;
    port: number;
    name: string;
    user: string;
    password: string;
  };
  redis: {
    host: string;
    port: number;
    password?: string;
  };
  blockchain: {
    rpcUrl: string;
    privateKey?: string;
  };
  contracts: {
    researchNFT: string;
    datasetManager: string;
    userProfile: string;
    deSciRegistry: string;
  };
  logging: {
    level: string;
    file: string;
  };
  cache: {
    ttl: number;
    maxSize: number;
  };
}

export const config: Config = {
  nodeEnv: process.env.NODE_ENV || 'development',
  port: parseInt(process.env.PORT || '3001', 10),
  
  database: {
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '5432', 10),
    name: process.env.DB_NAME || 'desci_platform',
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || '',
  },
  
  redis: {
    host: process.env.REDIS_HOST || 'localhost',
    port: parseInt(process.env.REDIS_PORT || '6379', 10),
    password: process.env.REDIS_PASSWORD || undefined,
  },
  
  blockchain: {
    rpcUrl: process.env.RPC_URL || 'http://127.0.0.1:8545',
    privateKey: process.env.PRIVATE_KEY,
  },
  
  contracts: {
    researchNFT: process.env.RESEARCH_NFT_ADDRESS || '',
    datasetManager: process.env.DATASET_MANAGER_ADDRESS || '',
    userProfile: process.env.USER_PROFILE_ADDRESS || '',
    deSciRegistry: process.env.DESCI_REGISTRY_ADDRESS || '',
  },
  
  logging: {
    level: process.env.LOG_LEVEL || 'info',
    file: process.env.LOG_FILE || 'logs/app.log',
  },
  
  cache: {
    ttl: parseInt(process.env.CACHE_TTL || '3600', 10),
    maxSize: parseInt(process.env.CACHE_MAX_SIZE || '1000', 10),
  },
};

// 验证必要的配置
export function validateConfig(): void {
  const requiredFields = [
    'database.host',
    'database.name', 
    'database.user',
    'blockchain.rpcUrl',
  ];
  
  for (const field of requiredFields) {
    const value = field.split('.').reduce((obj, key) => obj?.[key], config as any);
    if (!value) {
      throw new Error(`Missing required configuration: ${field}`);
    }
  }
}
