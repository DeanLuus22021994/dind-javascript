const express = require('express');
const { body, validationResult } = require('express-validator');
const rateLimit = require('express-rate-limit');
const User = require('../models/User');
const authService = require('../utils/auth');
const logger = require('../utils/logger');
const redisClient = require('../utils/redis');

const router = express.Router();

// Rate limiting for auth endpoints
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // 5 attempts per window
  message: {
    error: 'Too many authentication attempts',
    message: 'Please try again later',
    retryAfter: '15 minutes'
  },
  standardHeaders: true,
  legacyHeaders: false
});

// Validation middleware
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
 *   name: Authentication
 *   description: User authentication endpoints
 */

/**
 * @swagger
 * /auth/register:
 *   post:
 *     summary: Register a new user
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - username
 *               - password
 *               - firstName
 *               - lastName
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *               username:
 *                 type: string
 *                 minLength: 3
 *                 maxLength: 30
 *               password:
 *                 type: string
 *                 minLength: 6
 *               firstName:
 *                 type: string
 *               lastName:
 *                 type: string
 *     responses:
 *       201:
 *         description: User registered successfully
 *       400:
 *         description: Validation error
 *       409:
 *         description: User already exists
 */
router.post('/register',
  authLimiter,
  [
    body('email').isEmail().normalizeEmail().withMessage('Valid email is required'),
    body('username').isLength({ min: 3, max: 30 }).matches(/^[a-zA-Z0-9_]+$/).withMessage('Username must be 3-30 characters and contain only letters, numbers, and underscores'),
    body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters'),
    body('firstName').trim().isLength({ min: 1, max: 50 }).withMessage('First name is required'),
    body('lastName').trim().isLength({ min: 1, max: 50 }).withMessage('Last name is required')
  ],
  handleValidationErrors,
  async (req, res) => {
    try {
      const { email, username, password, firstName, lastName } = req.body;

      // Check if user already exists
      const existingUser = await User.findByEmailOrUsername(email);
      if (existingUser) {
        return res.status(409).json({
          error: 'User already exists',
          message: 'A user with this email or username already exists',
          timestamp: new Date().toISOString()
        });
      }

      // Hash password
      const hashedPassword = await authService.hashPassword(password);

      // Create user
      const user = new User({
        email,
        username,
        password: hashedPassword,
        firstName,
        lastName,
        metadata: {
          lastIpAddress: req.ip,
          userAgent: req.get('User-Agent')
        }
      });

      await user.save();

      // Generate token
      const token = authService.generateToken({
        userId: user._id,
        email: user.email,
        username: user.username,
        roles: user.roles
      });

      logger.info(`New user registered: ${user.email}`);

      res.status(201).json({
        message: 'User registered successfully',
        user: user.publicProfile,
        token,
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      logger.error('Registration error:', error);
      res.status(500).json({
        error: 'Registration failed',
        message: 'An error occurred during registration',
        timestamp: new Date().toISOString()
      });
    }
  }
);

/**
 * @swagger
 * /auth/login:
 *   post:
 *     summary: Login user
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - identifier
 *               - password
 *             properties:
 *               identifier:
 *                 type: string
 *                 description: Email or username
 *               password:
 *                 type: string
 *     responses:
 *       200:
 *         description: Login successful
 *       400:
 *         description: Validation error
 *       401:
 *         description: Invalid credentials
 */
router.post('/login',
  authLimiter,
  [
    body('identifier').notEmpty().withMessage('Email or username is required'),
    body('password').notEmpty().withMessage('Password is required')
  ],
  handleValidationErrors,
  async (req, res) => {
    try {
      const { identifier, password } = req.body;

      // Find user by email or username
      const user = await User.findByEmailOrUsername(identifier);
      if (!user) {
        return res.status(401).json({
          error: 'Invalid credentials',
          message: 'Email/username or password is incorrect',
          timestamp: new Date().toISOString()
        });
      }

      // Check if user is active
      if (!user.isActive) {
        return res.status(401).json({
          error: 'Account deactivated',
          message: 'Your account has been deactivated',
          timestamp: new Date().toISOString()
        });
      }

      // Compare password
      const isPasswordValid = await authService.comparePassword(password, user.password);
      if (!isPasswordValid) {
        return res.status(401).json({
          error: 'Invalid credentials',
          message: 'Email/username or password is incorrect',
          timestamp: new Date().toISOString()
        });
      }

      // Update login info
      user.updateLoginInfo(req.ip, req.get('User-Agent'));
      await user.save();

      // Generate token
      const token = authService.generateToken({
        userId: user._id,
        email: user.email,
        username: user.username,
        roles: user.roles
      });

      // Store token in Redis for session management
      await redisClient.set(`session:${user._id}`, {
        token,
        loginAt: new Date(),
        ipAddress: req.ip,
        userAgent: req.get('User-Agent')
      }, 24 * 60 * 60); // 24 hours

      logger.info(`User logged in: ${user.email}`);

      res.json({
        message: 'Login successful',
        user: user.publicProfile,
        token,
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      logger.error('Login error:', error);
      res.status(500).json({
        error: 'Login failed',
        message: 'An error occurred during login',
        timestamp: new Date().toISOString()
      });
    }
  }
);

/**
 * @swagger
 * /auth/logout:
 *   post:
 *     summary: Logout user
 *     tags: [Authentication]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Logout successful
 *       401:
 *         description: Not authenticated
 */
router.post('/logout',
  authService.authenticate(),
  async (req, res) => {
    try {
      // Remove session from Redis
      await redisClient.del(`session:${req.user.userId}`);

      logger.info(`User logged out: ${req.user.email}`);

      res.json({
        message: 'Logout successful',
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      logger.error('Logout error:', error);
      res.status(500).json({
        error: 'Logout failed',
        message: 'An error occurred during logout',
        timestamp: new Date().toISOString()
      });
    }
  }
);

/**
 * @swagger
 * /auth/profile:
 *   get:
 *     summary: Get user profile
 *     tags: [Authentication]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: User profile
 *       401:
 *         description: Not authenticated
 */
router.get('/profile',
  authService.authenticate(),
  async (req, res) => {
    try {
      const user = await User.findById(req.user.userId);
      if (!user) {
        return res.status(404).json({
          error: 'User not found',
          message: 'User profile not found',
          timestamp: new Date().toISOString()
        });
      }

      res.json({
        user: user.toSafeObject(),
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      logger.error('Profile fetch error:', error);
      res.status(500).json({
        error: 'Profile fetch failed',
        message: 'An error occurred while fetching profile',
        timestamp: new Date().toISOString()
      });
    }
  }
);

/**
 * @swagger
 * /auth/refresh:
 *   post:
 *     summary: Refresh JWT token
 *     tags: [Authentication]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Token refreshed
 *       401:
 *         description: Invalid token
 */
router.post('/refresh',
  authService.authenticate(),
  async (req, res) => {
    try {
      // Generate new token
      const token = authService.generateToken({
        userId: req.user.userId,
        email: req.user.email,
        username: req.user.username,
        roles: req.user.roles
      });

      // Update session in Redis
      await redisClient.set(`session:${req.user.userId}`, {
        token,
        refreshedAt: new Date(),
        ipAddress: req.ip,
        userAgent: req.get('User-Agent')
      }, 24 * 60 * 60); // 24 hours

      res.json({
        message: 'Token refreshed successfully',
        token,
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      logger.error('Token refresh error:', error);
      res.status(500).json({
        error: 'Token refresh failed',
        message: 'An error occurred while refreshing token',
        timestamp: new Date().toISOString()
      });
    }
  }
);

module.exports = router;
