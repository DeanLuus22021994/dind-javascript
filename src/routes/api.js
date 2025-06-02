const express = require('express');
const { body, query, validationResult } = require('express-validator');
const logger = require('../utils/logger');
const config = require('../config');

const router = express.Router();

// Validation error handler
const handleValidationErrors = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      error: 'Validation Error',
      details: errors.array(),
      timestamp: new Date().toISOString()
    });
  }
  next();
};

/**
 * @swagger
 * tags:
 *   name: API
 *   description: Main API endpoints
 */

/**
 * @swagger
 * /api/info:
 *   get:
 *     summary: Get API information
 *     tags: [API]
 *     responses:
 *       200:
 *         description: API information
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 version:
 *                   type: string
 *                 name:
 *                   type: string
 *                 environment:
 *                   type: string
 *                 uptime:
 *                   type: number
 *                 timestamp:
 *                   type: string
 */
router.get('/info', (req, res) => {
  // Only log in non-test environments
  if (process.env.NODE_ENV !== 'test') {
    logger.info('API info requested');
  }

  res.json({
    name: 'DIND JavaScript API',
    version: '1.0.0',
    environment: config.nodeEnv,
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
    nodeVersion: process.version,
    features: {
      authentication: false, // Can be enhanced later
      rateLimit: true,
      monitoring: config.enableMetrics,
      documentation: true,
      validation: true
    }
  });
});

/**
 * @swagger
 * /api/echo:
 *   post:
 *     summary: Echo service for testing
 *     tags: [API]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               message:
 *                 type: string
 *                 description: Message to echo back
 *               metadata:
 *                 type: object
 *                 description: Additional metadata
 *     responses:
 *       200:
 *         description: Echo response
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 echo:
 *                   type: object
 *                 timestamp:
 *                   type: string
 *                 requestId:
 *                   type: string
 *       400:
 *         description: Validation error
 */
router.post('/echo',
  [
    body('message').notEmpty().withMessage('Message is required'),
    body('message').isLength({ max: 1000 }).withMessage('Message must be less than 1000 characters')
  ],
  handleValidationErrors,
  (req, res) => {
    const requestId = Math.random().toString(36).substring(2, 15);

    // Only log in non-test environments
    if (process.env.NODE_ENV !== 'test') {
      logger.info(`Echo request received: ${requestId}`, {
        requestId,
        messageLength: req.body.message?.length || 0
      });
    }

    res.json({
      echo: {
        message: req.body.message,
        metadata: req.body.metadata || {},
        headers: {
          userAgent: req.get('User-Agent'),
          contentType: req.get('Content-Type')
        }
      },
      timestamp: new Date().toISOString(),
      requestId
    });
  }
);

/**
 * @swagger
 * /api/data:
 *   get:
 *     summary: Get sample data with pagination
 *     tags: [API]
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           minimum: 1
 *           default: 1
 *         description: Page number
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           minimum: 1
 *           maximum: 100
 *           default: 10
 *         description: Number of items per page
 *       - in: query
 *         name: search
 *         schema:
 *           type: string
 *         description: Search term
 *     responses:
 *       200:
 *         description: Paginated data
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   type: array
 *                   items:
 *                     type: object
 *                 pagination:
 *                   type: object
 *                   properties:
 *                     page:
 *                       type: integer
 *                     limit:
 *                       type: integer
 *                     total:
 *                       type: integer
 *                     pages:
 *                       type: integer
 */
router.get('/data',
  [
    query('page').optional().isInt({ min: 1 }).withMessage('Page must be a positive integer'),
    query('limit').optional().isInt({ min: 1, max: 100 }).withMessage('Limit must be between 1 and 100'),
    query('search').optional().isLength({ max: 100 }).withMessage('Search term must be less than 100 characters')
  ],
  handleValidationErrors,
  (req, res) => {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const search = req.query.search || '';

    // Generate sample data
    const sampleData = Array.from({ length: 150 }, (_, i) => ({
      id: i + 1,
      name: `Item ${i + 1}`,
      description: `Description for item ${i + 1}`,
      category: ['electronics', 'books', 'clothing', 'home', 'sports'][i % 5],
      price: Math.floor(Math.random() * 1000) + 10,
      inStock: Math.random() > 0.3,
      createdAt: new Date(Date.now() - Math.random() * 365 * 24 * 60 * 60 * 1000).toISOString()
    }));

    // Apply search filter
    let filteredData = sampleData;
    if (search) {
      filteredData = sampleData.filter(item =>
        item.name.toLowerCase().includes(search.toLowerCase()) ||
        item.description.toLowerCase().includes(search.toLowerCase()) ||
        item.category.toLowerCase().includes(search.toLowerCase())
      );
    }

    const total = filteredData.length;
    const pages = Math.ceil(total / limit);
    const offset = (page - 1) * limit;
    const paginatedData = filteredData.slice(offset, offset + limit);

    // Only log in non-test environments
    if (process.env.NODE_ENV !== 'test') {
      logger.info(`Data request: page=${page}, limit=${limit}, search="${search}", results=${paginatedData.length}`);
    }

    res.json({
      data: paginatedData,
      pagination: {
        page,
        limit,
        total,
        pages,
        hasNext: page < pages,
        hasPrev: page > 1
      },
      filters: {
        search: search || null
      },
      timestamp: new Date().toISOString()
    });
  }
);

/**
 * @swagger
 * /api/status:
 *   get:
 *     summary: Get detailed API status
 *     tags: [API]
 *     responses:
 *       200:
 *         description: API status information
 */
router.get('/status', (req, res) => {
  const memoryUsage = process.memoryUsage();
  const cpuUsage = process.cpuUsage();

  res.json({
    status: 'operational',
    timestamp: new Date().toISOString(),
    uptime: {
      seconds: process.uptime(),
      human: formatUptime(process.uptime())
    },
    memory: {
      rss: `${Math.round(memoryUsage.rss / 1024 / 1024 * 100) / 100} MB`,
      heapTotal: `${Math.round(memoryUsage.heapTotal / 1024 / 1024 * 100) / 100} MB`,
      heapUsed: `${Math.round(memoryUsage.heapUsed / 1024 / 1024 * 100) / 100} MB`,
      external: `${Math.round(memoryUsage.external / 1024 / 1024 * 100) / 100} MB`
    },
    cpu: {
      user: cpuUsage.user,
      system: cpuUsage.system
    },
    environment: config.nodeEnv,
    nodeVersion: process.version,
    platform: process.platform,
    arch: process.arch
  });
});

// Helper function to format uptime
function formatUptime(uptime) {
  const days = Math.floor(uptime / 86400);
  const hours = Math.floor((uptime % 86400) / 3600);
  const minutes = Math.floor((uptime % 3600) / 60);
  const seconds = Math.floor(uptime % 60);

  const parts = [];
  if (days > 0) parts.push(`${days}d`);
  if (hours > 0) parts.push(`${hours}h`);
  if (minutes > 0) parts.push(`${minutes}m`);
  parts.push(`${seconds}s`);

  return parts.join(' ');
}

module.exports = router;
