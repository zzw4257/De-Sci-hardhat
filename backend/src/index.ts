import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import { config } from './config';
import { logger } from './utils/logger';
import { errorHandler } from './middleware/errorHandler';
import { researchDataRouter } from './controllers/ResearchDataController';
import { datasetRouter } from './controllers/DatasetController';
import { userProfileRouter } from './controllers/UserProfileController';
import { verificationRouter } from './controllers/VerificationController';
import { EventListenerManager } from './listeners/EventListenerManager';

const app = express();

// 中间件配置
app.use(helmet());
app.use(cors());
app.use(compression());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// 请求日志
app.use((req, res, next) => {
  logger.info(`${req.method} ${req.path}`, {
    ip: req.ip,
    userAgent: req.get('User-Agent')
  });
  next();
});

// 健康检查
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    timestamp: new Date().toISOString(),
    version: process.env.npm_package_version || '1.0.0'
  });
});

// API 路由
app.use('/api/research', researchDataRouter);
app.use('/api/datasets', datasetRouter);
app.use('/api/users', userProfileRouter);
app.use('/api/verification', verificationRouter);

// 404 处理
app.use('*', (req, res) => {
  res.status(404).json({ error: 'API endpoint not found' });
});

// 错误处理中间件
app.use(errorHandler);

// 启动服务器
async function startServer() {
  try {
    // 启动事件监听器
    const eventManager = new EventListenerManager();
    await eventManager.startAllListeners();
    
    // 启动HTTP服务器
    app.listen(config.port, () => {
      logger.info(`DeSci Backend Server started on port ${config.port}`);
      logger.info(`Environment: ${config.nodeEnv}`);
    });
    
    // 优雅关闭处理
    process.on('SIGTERM', async () => {
      logger.info('Received SIGTERM, shutting down gracefully');
      await eventManager.stopAllListeners();
      process.exit(0);
    });
    
    process.on('SIGINT', async () => {
      logger.info('Received SIGINT, shutting down gracefully');
      await eventManager.stopAllListeners();
      process.exit(0);
    });
    
  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
}

// 处理未捕获的异常
process.on('uncaughtException', (error) => {
  logger.error('Uncaught Exception:', error);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});

// 启动应用
startServer();

export default app;
