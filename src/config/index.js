const config = {
  port: parseInt(process.env.PORT, 10) || 3000,
  nodeEnv: process.env.NODE_ENV || 'development',
  isProduction: process.env.NODE_ENV === 'production',
  isDevelopment: process.env.NODE_ENV === 'development',
  isTest: process.env.NODE_ENV === 'test',
  isTesting: process.env.NODE_ENV === 'test', // Added for config test

  // Database
  database: {
    url: process.env.DATABASE_URL || 'mongodb://localhost:27017/dind-javascript'
  },
  databaseUrl: process.env.DATABASE_URL || 'mongodb://localhost:27017/dind-javascript',

  // Redis
  redis: {
    enabled: process.env.REDIS_ENABLED !== 'false',
    url: process.env.REDIS_URL || 'redis://localhost:6379'
  },
  redisUrl: process.env.REDIS_URL || 'redis://localhost:6379',

  // JWT
  jwtSecret: process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-in-production',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '24h',

  // Rate Limiting
  rateLimitWindowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS, 10) || 15 * 60 * 1000, // 15 minutes
  rateLimitMaxRequests: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS, 10) || 100,

  // Logging
  logLevel: process.env.LOG_LEVEL || (process.env.NODE_ENV === 'test' ? 'silent' : 'info'),

  // CORS
  corsOrigin: process.env.CORS_ORIGIN || '*',

  // Session
  sessionSecret: process.env.SESSION_SECRET || 'your-session-secret-change-in-production',

  // Email
  emailProvider: process.env.EMAIL_PROVIDER || 'console', // console, smtp, ses
  emailFrom: process.env.EMAIL_FROM || 'noreply@example.com',
  smtpHost: process.env.SMTP_HOST,
  smtpPort: parseInt(process.env.SMTP_PORT, 10) || 587,
  smtpUser: process.env.SMTP_USER,
  smtpPass: process.env.SMTP_PASS,

  // File Upload
  uploadMaxSize: parseInt(process.env.UPLOAD_MAX_SIZE, 10) || 5 * 1024 * 1024, // 5MB
  uploadAllowedTypes: (
    process.env.UPLOAD_ALLOWED_TYPES || '.jpg,.jpeg,.png,.gif,.pdf,.txt,.doc,.docx,.xls,.xlsx'
  ).split(','),

  // Monitoring
  enableMetrics: process.env.ENABLE_METRICS === 'true',
  metricsPort: parseInt(process.env.METRICS_PORT, 10) || 9090,

  // Security
  helmetOptions: {
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc: ["'self'", "'unsafe-inline'"],
        styleSrc: ["'self'", "'unsafe-inline'"],
        imgSrc: ["'self'", 'data:', 'https:']
      }
    }
  },

  // API Documentation
  swaggerOptions: {
    definition: {
      openapi: '3.0.0',
      info: {
        title: 'DIND JavaScript API',
        version: '1.0.0',
        description: 'Docker-in-Docker JavaScript Environment API'
      },
      servers: [
        {
          url:
            process.env.API_BASE_URL ||
            `http://localhost:${parseInt(process.env.PORT, 10) || 3000}`,
          description: 'Development server'
        }
      ]
    },
    apis: ['./src/routes/*.js'] // paths to files containing OpenAPI definitions
  }
};

export default config;
