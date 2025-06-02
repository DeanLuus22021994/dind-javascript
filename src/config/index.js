const dotenv = require('dotenv');

// Load environment variables
dotenv.config();

const config = {
  // Server Configuration
  port: process.env.PORT || 3000,
  nodeEnv: process.env.NODE_ENV || 'development',
  apiVersion: process.env.API_VERSION || 'v1',
  maxRequestSize: process.env.MAX_REQUEST_SIZE || '10mb',
  // Database Configuration
  database: {
    url: process.env.DATABASE_URL || 'mongodb://localhost:27017/dind-javascript',
    testUrl: process.env.DATABASE_TEST_URL || 'mongodb://localhost:27017/dind-javascript-test',
    useInMemory: process.env.USE_MEMORY_DB === 'true' || (process.env.NODE_ENV === 'development' && !process.env.DATABASE_URL)
  },

  // Redis Configuration
  redis: {
    url: process.env.REDIS_URL || 'redis://localhost:6379',
    password: process.env.REDIS_PASSWORD || ''
  },

  // Security
  jwtSecret: process.env.JWT_SECRET || 'fallback-secret-key',
  jwtExpire: process.env.JWT_EXPIRE || '7d',
  bcryptRounds: parseInt(process.env.BCRYPT_ROUNDS) || 12,
  sessionSecret: process.env.SESSION_SECRET || 'fallback-session-secret',

  // Rate Limiting
  rateLimitWindowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 900000, // 15 minutes
  rateLimitMaxRequests: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100,

  // Logging
  logLevel: process.env.LOG_LEVEL || 'info',
  logFileMaxSize: parseInt(process.env.LOG_FILE_MAX_SIZE) || 5242880, // 5MB
  logMaxFiles: parseInt(process.env.LOG_MAX_FILES) || 5,
  // Monitoring
  enableMetrics: process.env.ENABLE_METRICS === 'true',
  metricsPort: process.env.METRICS_PORT || 9090,

  // GraphQL
  enableGraphQL: process.env.ENABLE_GRAPHQL !== 'false', // Enabled by default

  // CORS
  corsOrigins: process.env.CORS_ORIGINS ? process.env.CORS_ORIGINS.split(',') : ['http://localhost:3000'],

  // Email Configuration
  email: {
    host: process.env.SMTP_HOST || 'smtp.gmail.com',
    port: parseInt(process.env.SMTP_PORT) || 587,
    user: process.env.SMTP_USER || '',
    password: process.env.SMTP_PASS || '',
    from: process.env.SMTP_FROM || 'noreply@example.com'
  },

  // File Upload
  upload: {
    maxFileSize: parseInt(process.env.MAX_FILE_SIZE) || 10485760, // 10MB
    uploadPath: process.env.UPLOAD_PATH || 'uploads/'
  },

  // WebSocket
  enableWebSocket: process.env.ENABLE_WEBSOCKET === 'true',
  websocketPort: process.env.WEBSOCKET_PORT || 3001,

  // Background Jobs
  enableBackgroundJobs: process.env.ENABLE_BACKGROUND_JOBS === 'true',
  jobConcurrency: parseInt(process.env.JOB_CONCURRENCY) || 5,

  // GraphQL
  // GraphQL
  graphqlIntrospection: process.env.GRAPHQL_INTROSPECTION === 'true',
  graphqlPlayground: process.env.GRAPHQL_PLAYGROUND === 'true',
  // External Services
  externalApi: {
    key: process.env.EXTERNAL_API_KEY || '',
    url: process.env.EXTERNAL_API_URL || 'https://api.example.com'
  },

  // Development flags
  enableSwagger: process.env.ENABLE_SWAGGER !== 'false', // Default to true
  enableDebug: process.env.ENABLE_DEBUG === 'true',
  isDevelopment: process.env.NODE_ENV === 'development',
  isProduction: process.env.NODE_ENV === 'production',
  isTesting: process.env.NODE_ENV === 'test'
};

module.exports = config;
