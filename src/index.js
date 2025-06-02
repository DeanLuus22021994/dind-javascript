const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const swaggerJsdoc = require('swagger-jsdoc');
const swaggerUi = require('swagger-ui-express');
const cookieParser = require('cookie-parser');
const session = require('express-session');
const http = require('http');

const config = require('./config');
const logger = require('./utils/logger');
const database = require('./utils/database');
const redisClient = require('./utils/redis');
const websocketServer = require('./utils/websocket');
const { register, metricsMiddleware } = require('./utils/metrics');
const { createApolloServer } = require('./graphql/server');

// Import routes
const apiRoutes = require('./routes/api');
const healthRoutes = require('./routes/health');
const authRoutes = require('./routes/auth');
const uploadRoutes = require('./routes/upload');

const app = express();
const server = http.createServer(app);

// Initialize connections
async function initializeConnections() {
  try {
    // Connect to database
    if (config.database && config.database.url) {
      await database.connect();
    } else if (config.databaseUrl) {
      await database.connect();
    }

    // Connect to Redis
    if (config.redis && config.redis.enabled && config.redis.url) {
      await redisClient.connect();
    } else if (config.redisUrl) {
      logger.info('Redis configuration found but not enabled');
    } else {
      logger.info('Redis disabled or not configured');
    }

    // Initialize WebSocket server
    websocketServer.initialize(server);

    logger.info('✅ All connections initialized successfully');
  } catch (error) {
    logger.error('Failed to initialize connections:', error);
    if (config.isProduction) {
      process.exit(1);
    }
  }
}

// Security middleware
app.use(helmet(config.helmetOptions));

// CORS
app.use(cors({
  origin: config.corsOrigin,
  credentials: true
}));

// Compression
app.use(compression());

// Request logging
if (!config.isTest) {
  app.use(morgan('combined', {
    stream: {
      write: (message) => logger.info(message.trim())
    }
  }));
}

// Rate limiting
const limiter = rateLimit({
  windowMs: config.rateLimitWindowMs,
  max: config.rateLimitMaxRequests,
  message: {
    error: 'Too many requests from this IP, please try again later.',
    retryAfter: Math.ceil(config.rateLimitWindowMs / 1000)
  },
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    logger.warn(`Rate limit exceeded for IP: ${req.ip}`);
    res.status(429).json({
      error: 'Too many requests from this IP, please try again later.',
      retryAfter: Math.ceil(config.rateLimitWindowMs / 1000)
    });
  }
});

app.use('/api', limiter);

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(cookieParser());

// Session middleware
app.use(session({
  secret: config.sessionSecret,
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: config.isProduction,
    httpOnly: true,
    maxAge: 24 * 60 * 60 * 1000 // 24 hours
  }
}));

// Metrics middleware
if (config.enableMetrics) {
  app.use(metricsMiddleware);
}

// API Documentation
if (!config.isProduction) {
  const specs = swaggerJsdoc(config.swaggerOptions);
  app.use('/docs', swaggerUi.serve, swaggerUi.setup(specs, {
    explorer: true,
    customCss: '.swagger-ui .topbar { display: none }',
    customSiteTitle: 'DIND JavaScript API Documentation'
  }));
}

// GraphQL
if (!config.isTest) {
  (async() => {
    try {
      const apolloServer = await createApolloServer();
      await apolloServer.start();
      apolloServer.applyMiddleware({ app, path: '/graphql' });
      logger.info('🔗 GraphQL server initialized');
    } catch (error) {
      logger.error('Failed to initialize GraphQL server:', error);
    }
  })();
}

/**
 * @swagger
 * /:
 *   get:
 *     summary: Get application information
 *     description: Returns basic information about the API and available features
 *     responses:
 *       200:
 *         description: Application information
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                 timestamp:
 *                   type: string
 *                   format: date-time
 *                 environment:
 *                   type: string
 *                 nodeVersion:
 *                   type: string
 *                 features:
 *                   type: array
 *                   items:
 *                     type: string
 */
app.get('/', (req, res) => {
  logger.info('Root endpoint accessed');
  res.json({
    message: 'Enhanced Docker-in-Docker JavaScript Environment',
    timestamp: new Date().toISOString(),
    environment: config.nodeEnv,
    nodeVersion: process.version,
    features: [
      'Security Headers (Helmet)',
      'Rate Limiting',
      'CORS Support',
      'Request Logging',
      'API Documentation (Swagger)',
      'Health Monitoring',
      'Metrics Collection',
      'Error Handling',
      'Input Validation'
    ],
    documentation: '/docs',
    health: '/health',
    metrics: config.enableMetrics ? '/metrics' : 'disabled'
  });
});

// Routes
app.use('/health', healthRoutes);
app.use('/api', apiRoutes);
app.use('/auth', authRoutes);
app.use('/upload', uploadRoutes);

// Metrics endpoint
if (config.enableMetrics) {
  app.get('/metrics', async(req, res) => {
    try {
      res.set('Content-Type', register.contentType);
      res.end(await register.metrics());
    } catch (error) {
      res.status(500).end(error.message);
    }
  });
}

// 404 handler
app.use('*', (req, res) => {
  logger.warn(`404 - Route not found: ${req.method} ${req.originalUrl}`);
  res.status(404).json({
    error: 'Route not found',
    message: `Cannot ${req.method} ${req.originalUrl}`,
    timestamp: new Date().toISOString()
  });
});

// Global error handler
app.use((error, req, res, next) => {
  logger.error('Unhandled error:', {
    error: error.message,
    stack: error.stack,
    url: req.url,
    method: req.method,
    ip: req.ip
  });

  const isDev = config.isDevelopment;

  res.status(error.status || 500).json({
    error: 'Internal Server Error',
    message: isDev ? error.message : 'Something went wrong!',
    ...(isDev && { stack: error.stack }),
    timestamp: new Date().toISOString()
  });
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM signal received: closing HTTP server');
  server.close(() => {
    logger.info('HTTP server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  logger.info('SIGINT signal received: closing HTTP server');
  server.close(() => {
    logger.info('HTTP server closed');
    process.exit(0);
  });
});

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  logger.error('Uncaught Exception:', error);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});

// Start server
async function startServer() {
  try {
    await initializeConnections();

    const serverInstance = server.listen(config.port, () => {
      logger.info(`🚀 Server running on port ${config.port}`);
      logger.info(`📋 Environment: ${config.nodeEnv}`);

      if (!config.isProduction) {
        logger.info('📚 API Documentation: http://localhost:' + config.port + '/docs');
      }
      if (!config.isTest) {
        logger.info('🔗 GraphQL Playground: http://localhost:' + config.port + '/graphql');
      }
      logger.info('💊 Health Check: http://localhost:' + config.port + '/health');
      if (config.enableMetrics) {
        logger.info('📊 Metrics: http://localhost:' + config.port + '/metrics');
      }
      logger.info('🔌 WebSocket: ws://localhost:' + config.port);

      if (config.database && config.database.url) {
        logger.info('🗄️  Database: Connected');
      }
      if (config.redis && config.redis.url) {
        logger.info('🔴 Redis: Connected');
      }
    });

    return serverInstance;
  } catch (error) {
    logger.error('Failed to start server:', error);
    throw error;
  }
}

// Only start server if not in test environment or not being required as module
if (!config.isTest && require.main === module) {
  startServer().catch(error => {
    logger.error('Failed to start server:', error);
    process.exit(1);
  });
}

module.exports = { app, startServer };
