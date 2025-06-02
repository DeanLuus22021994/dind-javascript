const jwt = require('jsonwebtoken');
const User = require('../models/User');
const config = require('../config');
const logger = require('./logger');

/**
 * Generate JWT token for a user
 * @param {string} userId - User ID to include in token
 * @returns {string} JWT token
 */
function generateToken(userId) {
  return jwt.sign(
    { userId: userId.toString() },
    config.jwtSecret,
    { expiresIn: config.jwtExpiresIn }
  );
}

/**
 * Verify JWT token
 * @param {string} token - JWT token to verify
 * @returns {Promise<Object>} Decoded token payload
 */
async function verifyToken(token) {
  try {
    return jwt.verify(token, config.jwtSecret);
  } catch (error) {
    // Re-throw the original error for better test expectations
    if (error.name === 'TokenExpiredError') {
      throw new Error('Token expired');
    } else if (error.name === 'JsonWebTokenError') {
      throw new Error('Invalid token');
    } else {
      throw error;
    }
  }
}

/**
 * Auth middleware to protect routes
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next function
 */
async function requireAuth(req, res, next) {
  try {
    // Get token from header
    const authHeader = req.headers.authorization;
    if (!authHeader) {
      req.user = null;
      return res.status(401).json({ error: 'Access denied. No token provided.' });
    }

    // Check if token has correct format
    if (!authHeader.startsWith('Bearer ')) {
      req.user = null;
      return res.status(401).json({ error: 'Invalid token format. Use Bearer token.' });
    }

    // Extract and verify token
    const token = authHeader.split(' ')[1];
    let decoded;
    try {
      decoded = await verifyToken(token);
    } catch (error) {
      req.user = null;
      return res.status(401).json({ error: 'Invalid token.' });
    }

    // Find user with decoded ID
    const user = await User.findById(decoded.userId);
    if (!user) {
      req.user = null;
      return res.status(401).json({ error: 'User not found.' });
    }

    // Set user in request
    req.user = user;
    next();
  } catch (error) {
    logger.error('Authentication error:', error);
    req.user = null;
    res.status(500).json({ error: 'Internal server error during authentication.' });
  }
}

/**
 * Role-based authorization middleware
 * @param {string|string[]} roles - Required role(s) to access the route
 */
function requireRole(roles) {
  return async (req, res, next) => {
    try {
      // Check if user exists in request (requireAuth should run first)
      if (!req.user) {
        return res.status(403).json({ error: 'Access denied. Insufficient permissions.' });
      }

      // Convert single role to array for consistent checking
      const requiredRoles = Array.isArray(roles) ? roles : [roles];

      // Check if user has any of the required roles
      const userRoles = Array.isArray(req.user.roles) ? req.user.roles : [req.user.role];
      const hasPermission = requiredRoles.some(role => userRoles.includes(role));

      if (!hasPermission) {
        logger.warn(`Authorization failed for user ${req.user._id}: required roles ${requiredRoles}, user roles ${userRoles}`);
        return res.status(403).json({ error: 'Access denied. Insufficient permissions.' });
      }

      next();
    } catch (error) {
      logger.error('Authorization error:', error);
      res.status(500).json({ error: 'Internal server error during authorization.' });
    }
  };
}

module.exports = {
  generateToken,
  verifyToken,
  requireAuth,
  requireRole
};
