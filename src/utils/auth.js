const jwt = require('jsonwebtoken');
const User = require('../models/User');
const config = require('../config');
const logger = require('./logger');

/**
 * Generate JWT token for user
 * @param {string} userId - User ID
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
 * @param {string} token - JWT token
 * @returns {object} Decoded token payload
 */
function verifyToken(token) {
  try {
    return jwt.verify(token, config.jwtSecret);
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      throw new Error('Token expired');
    }
    throw new Error('Invalid token');
  }
}

/**
 * Middleware to require authentication
 * @param {object} req - Express request object
 * @param {object} res - Express response object
 * @param {function} next - Express next function
 */
async function requireAuth(req, res, next) {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader) {
      return res.status(401).json({ error: 'Access denied. No token provided.' });
    }

    let token;
    if (authHeader.startsWith('Bearer ')) {
      token = authHeader.substring(7);
    } else {
      return res.status(401).json({ error: 'Invalid token format. Use Bearer token.' });
    }

    const decoded = verifyToken(token);
    const user = await User.findById(decoded.userId);

    if (!user || !user.isActive) {
      return res.status(401).json({ error: 'User not found.' });
    }

    // Exclude password from user object
    const userObject = user.toObject();
    delete userObject.password;

    req.user = userObject;
    next();
  } catch (error) {
    // Only log authentication errors in non-test environments to reduce noise
    if (process.env.NODE_ENV !== 'test') {
      logger.error('Authentication error:', error);
    }
    return res.status(401).json({ error: 'Invalid token.' });
  }
}

/**
 * Middleware to require specific role(s)
 * @param {string|array} roles - Required role(s)
 * @returns {function} Express middleware function
 */
function requireRole(roles) {
  return async(req, res, next) => {
    try {
      if (!req.user) {
        return res.status(403).json({ error: 'Access denied. Insufficient permissions.' });
      }

      const userRoles = Array.isArray(req.user.role) ? req.user.role : [req.user.role];
      const requiredRoles = Array.isArray(roles) ? roles : [roles];

      const hasRole = requiredRoles.some(role => userRoles.includes(role));

      if (!hasRole) {
        if (process.env.NODE_ENV !== 'test') {
          logger.warn(`Authorization failed for user ${req.user._id}: required roles ${requiredRoles.join(',')}, user roles ${userRoles.join(',')}`);
        }
        return res.status(403).json({
          error: 'Access denied. Insufficient permissions.'
        });
      }

      next();
    } catch (error) {
      if (process.env.NODE_ENV !== 'test') {
        logger.error('Role authorization error:', error);
      }
      return res.status(500).json({ error: 'Authorization error' });
    }
  };
}

module.exports = {
  generateToken,
  verifyToken,
  requireAuth,
  requireRole
};
