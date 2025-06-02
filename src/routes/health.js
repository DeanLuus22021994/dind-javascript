const express = require('express');
const logger = require('../utils/logger');
const config = require('../config');
const database = require('../utils/database');
const redisClient = require('../utils/redis');
const emailService = require('../utils/email');
const websocketServer = require('../utils/websocket');

const router = express.Router();

/**
 * @swagger
 * tags:
 *   name: Health
 *   description: Health check endpoints
 */

/**
 * @swagger
 * /health:
 *   get:
 *     summary: Basic health check
 *     tags: [Health]
 *     responses:
 *       200:
 *         description: Service is healthy
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 status:
 *                   type: string
 *                   example: healthy
 *                 timestamp:
 *                   type: string
 *                   format: date-time
 *                 uptime:
 *                   type: number
 *                 memory:
 *                   type: object
 */
router.get('/', (req, res) => {
  const healthData = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    environment: config.nodeEnv,
    version: '1.0.0'
  };

  logger.debug('Health check performed');
  res.json(healthData);
});

/**
 * @swagger
 * /health/detailed:
 *   get:
 *     summary: Detailed health check with system information
 *     tags: [Health]
 *     responses:
 *       200:
 *         description: Detailed system health information
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 status:
 *                   type: string
 *                 checks:
 *                   type: object
 *                 system:
 *                   type: object
 */
router.get('/detailed', async (req, res) => {
  const startTime = Date.now();

  try {
    // Perform various health checks
    const checks = {
      memory: checkMemoryUsage(),
      uptime: checkUptime(),
      environment: checkEnvironment(),
      dependencies: await checkDependencies()
    };

    const allChecksPass = Object.values(checks).every(check => check.status === 'pass');
    const responseTime = Date.now() - startTime;

    const healthData = {
      status: allChecksPass ? 'healthy' : 'degraded',
      timestamp: new Date().toISOString(),
      responseTime: `${responseTime}ms`,
      checks,
      system: {
        nodeVersion: process.version,
        platform: process.platform,
        arch: process.arch,
        pid: process.pid,
        ppid: process.ppid,
        cwd: process.cwd(),
        execPath: process.execPath,
        argv: process.argv,
        env: config.nodeEnv
      },
      resources: {
        memory: process.memoryUsage(),
        cpuUsage: process.cpuUsage(),
        uptime: process.uptime()
      }
    };

    const statusCode = allChecksPass ? 200 : 503;
    logger.info(`Detailed health check completed: ${healthData.status}`, {
      responseTime,
      status: healthData.status
    });

    res.status(statusCode).json(healthData);
  } catch (error) {
    logger.error('Health check failed:', error);
    res.status(500).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: error.message,
      responseTime: `${Date.now() - startTime}ms`
    });
  }
});

/**
 * @swagger
 * /health/ready:
 *   get:
 *     summary: Readiness probe for container orchestration
 *     tags: [Health]
 *     responses:
 *       200:
 *         description: Service is ready to receive traffic
 *       503:
 *         description: Service is not ready
 */
router.get('/ready', (req, res) => {
  // Check if the application is ready to serve requests
  const isReady = checkReadiness();

  if (isReady.ready) {
    res.json({
      status: 'ready',
      timestamp: new Date().toISOString(),
      checks: isReady.checks
    });
  } else {
    res.status(503).json({
      status: 'not-ready',
      timestamp: new Date().toISOString(),
      checks: isReady.checks,
      message: 'Service is not ready to receive traffic'
    });
  }
});

/**
 * @swagger
 * /health/live:
 *   get:
 *     summary: Liveness probe for container orchestration
 *     tags: [Health]
 *     responses:
 *       200:
 *         description: Service is alive
 *       503:
 *         description: Service should be restarted
 */
router.get('/live', (req, res) => {
  // Check if the application is alive and functioning
  const isAlive = checkLiveness();

  if (isAlive.alive) {
    res.json({
      status: 'alive',
      timestamp: new Date().toISOString(),
      checks: isAlive.checks
    });
  } else {
    res.status(503).json({
      status: 'dead',
      timestamp: new Date().toISOString(),
      checks: isAlive.checks,
      message: 'Service should be restarted'
    });
  }
});

/**
 * @swagger
 * /health/services:
 *   get:
 *     summary: Check status of all integrated services
 *     tags: [Health]
 *     responses:
 *       200:
 *         description: Service status information
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 status:
 *                   type: string
 *                 services:
 *                   type: object
 *                 timestamp:
 *                   type: string
 */
router.get('/services', async (req, res) => {
  const startTime = Date.now();

  try {
    const serviceChecks = await Promise.allSettled([
      checkDatabaseStatus(),
      checkRedisStatus(),
      checkEmailServiceStatus(),
      checkWebSocketStatus()
    ]);

    const services = {
      database: serviceChecks[0].status === 'fulfilled' ? serviceChecks[0].value : { status: 'error', error: serviceChecks[0].reason?.message },
      redis: serviceChecks[1].status === 'fulfilled' ? serviceChecks[1].value : { status: 'error', error: serviceChecks[1].reason?.message },
      email: serviceChecks[2].status === 'fulfilled' ? serviceChecks[2].value : { status: 'error', error: serviceChecks[2].reason?.message },
      websocket: serviceChecks[3].status === 'fulfilled' ? serviceChecks[3].value : { status: 'error', error: serviceChecks[3].reason?.message }
    };

    const allHealthy = Object.values(services).every(service => service.status === 'healthy');
    const responseTime = Date.now() - startTime;

    res.json({
      status: allHealthy ? 'healthy' : 'degraded',
      services,
      responseTime: `${responseTime}ms`,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    logger.error('Service status check failed:', error);
    res.status(500).json({
      status: 'error',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Health check functions
function checkMemoryUsage() {
  const memoryUsage = process.memoryUsage();
  const heapUsedMB = memoryUsage.heapUsed / 1024 / 1024;
  const heapTotalMB = memoryUsage.heapTotal / 1024 / 1024;
  const usagePercentage = (heapUsedMB / heapTotalMB) * 100;

  return {
    status: usagePercentage < 90 ? 'pass' : 'warn',
    usage: `${Math.round(heapUsedMB)} MB / ${Math.round(heapTotalMB)} MB`,
    percentage: `${Math.round(usagePercentage)}%`,
    details: memoryUsage
  };
}

function checkUptime() {
  const uptimeSeconds = process.uptime();
  const uptimeMinutes = uptimeSeconds / 60;

  return {
    status: uptimeSeconds > 5 ? 'pass' : 'warn', // At least 5 seconds uptime
    uptime: `${Math.round(uptimeSeconds)}s`,
    uptimeMinutes: `${Math.round(uptimeMinutes)}m`
  };
}

function checkEnvironment() {
  const requiredEnvVars = ['NODE_ENV'];
  const missingVars = requiredEnvVars.filter(varName => !process.env[varName]);

  return {
    status: missingVars.length === 0 ? 'pass' : 'fail',
    environment: config.nodeEnv,
    missingVariables: missingVars
  };
}

async function checkDependencies() {
  // Here you could check database connections, external services, etc.
  // For now, we'll just check if our main dependencies are available

  try {
    // Check if express is working (we're using it right now)
    const express = require('express');

    return {
      status: 'pass',
      dependencies: {
        express: 'available',
        logger: 'available',
        config: 'available'
      }
    };
  } catch (error) {
    return {
      status: 'fail',
      error: error.message
    };
  }
}

function checkReadiness() {
  // Application is ready if:
  // 1. It has been running for at least 1 second
  // 2. Memory usage is reasonable
  // 3. Required environment variables are set

  const checks = {
    uptime: process.uptime() > 1,
    memory: process.memoryUsage().heapUsed / process.memoryUsage().heapTotal < 0.9,
    environment: !!config.nodeEnv
  };

  const ready = Object.values(checks).every(check => check);

  return { ready, checks };
}

function checkLiveness() {
  // Application is alive if:
  // 1. It can respond to requests (we're responding now)
  // 2. Memory usage is not critically high
  // 3. Event loop is not blocked (implicit in being able to respond)

  const memoryUsage = process.memoryUsage();
  const memoryPressure = memoryUsage.heapUsed / memoryUsage.heapTotal;

  const checks = {
    responding: true, // If we're here, we're responding
    memoryPressure: memoryPressure < 0.95, // Not critically high
    eventLoop: true // Implicit - we can respond
  };

  const alive = Object.values(checks).every(check => check);

  return { alive, checks };
}

// Service check functions
async function checkDatabaseStatus() {
  try {
    const dbStatus = database.getStatus();
    return {
      status: dbStatus.isConnected ? 'healthy' : 'unhealthy',
      connected: dbStatus.isConnected,
      readyState: dbStatus.readyState,
      host: dbStatus.host,
      port: dbStatus.port,
      name: dbStatus.name
    };
  } catch (error) {
    return {
      status: 'error',
      error: error.message
    };
  }
}

async function checkRedisStatus() {
  try {
    const redisStatus = redisClient.getStatus();
    return {
      status: redisStatus.isConnected ? 'healthy' : 'unhealthy',
      connected: redisStatus.isConnected,
      client: redisStatus.client
    };
  } catch (error) {
    return {
      status: 'error',
      error: error.message
    };
  }
}

async function checkEmailServiceStatus() {
  try {
    const emailStatus = emailService.getStatus();
    return {
      status: emailStatus.isConfigured ? 'healthy' : 'not-configured',
      configured: emailStatus.isConfigured,
      host: emailStatus.host,
      port: emailStatus.port,
      user: emailStatus.user
    };
  } catch (error) {
    return {
      status: 'error',
      error: error.message
    };
  }
}

async function checkWebSocketStatus() {
  try {
    if (!config.enableWebSocket) {
      return {
        status: 'disabled',
        enabled: false
      };
    }

    const wsStats = websocketServer.getStats();
    return {
      status: 'healthy',
      enabled: true,
      connectedUsers: wsStats.connectedUsers,
      authenticatedUsers: wsStats.authenticatedUsers,
      activeRooms: wsStats.activeRooms
    };
  } catch (error) {
    return {
      status: 'error',
      error: error.message
    };
  }
}

module.exports = router;
