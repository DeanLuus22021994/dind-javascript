const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const swaggerJsdoc = require('swagger-jsdoc');
const swaggerUi = require('swagger-ui-express');

const config = require('./config');
const logger = require('./utils/logger');
const { register, metricsMiddleware } = require('./utils/metrics');

// Import routes
const apiRoutes = require('./routes/api');
const healthRoutes = require('./routes/health');

const app = express();

// Trust proxy (important for rate limiting behind reverse proxy)
app.set('trust proxy', 1);

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'", "fonts.googleapis.com"],
      fontSrc: ["'self'", "fonts.gstatic.com"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"]
    }
  }
}));

// CORS configuration
app.use(cors({
  origin: config.corsOrigins,
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: config.rateLimitWindowMs,
  max: config.rateLimitMaxRequests,
  message: {
    error: 'Too many requests from this IP, please try again later.',
    retryAfter: Math.ceil(config.rateLimitWindowMs / 1000)
  },
  standardHeaders: true,
  legacyHeaders: false
});

app.use('/api/', limiter);

// Compression middleware
app.use(compression());

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Logging middleware
app.use(morgan('combined', {
  stream: { write: message => logger.info(message.trim()) }
}));

// Metrics middleware
if (config.enableMetrics) {
  app.use(metricsMiddleware);
}

// Swagger documentation setup
const swaggerOptions = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'DIND JavaScript API',
      version: '1.0.0',
      description: 'Enhanced Docker-in-Docker JavaScript API with full-stack capabilities',
      contact: {
        name: 'Development Team',
        email: 'dev@example.com'
      }
    },
    servers: [
      {
        url: `http://localhost:${config.port}`,
        description: 'Development server'
      }
    ]
  },
  apis: ['./src/routes/*.js', './src/index.js']
};

const swaggerSpec = swaggerJsdoc(swaggerOptions);

// Swagger UI
app.use('/docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec, {
  customCss: '.swagger-ui .topbar { display: none }',
  customSiteTitle: 'DIND JavaScript API Docs'
}));

// Swagger JSON endpoint
app.get('/api-docs.json', (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.send(swaggerSpec);
});

/**
 * @swagger
 * /:
 *   get:
 *     summary: Welcome endpoint
 *     description: Returns basic application information
 *     tags: [General]
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

// Metrics endpoint
if (config.enableMetrics) {
  app.get('/metrics', async (req, res) => {
    try {
      res.set('Content-Type', register.contentType);
      res.end(await register.metrics());
    } catch (error) {
      logger.error('Error generating metrics:', error);
      res.status(500).end();
    }
  });
}

// 404 handler
app.use((req, res) => {
  logger.warn(`404 - Route not found: ${req.method} ${req.path}`);
  res.status(404).json({
    error: 'Route not found',
    message: `The requested endpoint ${req.method} ${req.path} does not exist`,
    timestamp: new Date().toISOString(),
    documentation: '/docs'
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

const server = app.listen(config.port, '0.0.0.0', () => {
  logger.info(`🚀 Server running on http://localhost:${config.port}`);
  logger.info(`📦 Node.js version: ${process.version}`);
  logger.info(`🌍 Environment: ${config.nodeEnv}`);
  logger.info(`📚 API Documentation: http://localhost:${config.port}/docs`);
  logger.info(`💊 Health Check: http://localhost:${config.port}/health`);

  if (config.enableMetrics) {
    logger.info(`📊 Metrics: http://localhost:${config.port}/metrics`);
  }
});

module.exports = app;
