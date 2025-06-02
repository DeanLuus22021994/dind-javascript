const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const config = require('../config');
const logger = require('./logger');

class AuthService { /**
   * Generate JWT token
   */
  generateToken(payload) {
    try {
      // Ensure payload is an object
      const tokenPayload = typeof payload === 'string' ? { userId: payload } : payload;

      return jwt.sign(tokenPayload, config.jwtSecret, {
        expiresIn: config.jwtExpire,
        issuer: 'dind-javascript-api',
        audience: 'dind-javascript-client'
      });
    } catch (error) {
      logger.error('Error generating JWT token:', error);
      throw new Error('Token generation failed');
    }
  }

  /**
   * Verify JWT token
   */
  verifyToken(token) {
    try {
      return jwt.verify(token, config.jwtSecret, {
        issuer: 'dind-javascript-api',
        audience: 'dind-javascript-client'
      });
    } catch (error) {
      logger.error('Error verifying JWT token:', error);
      throw new Error('Invalid token');
    }
  }

  /**
   * Hash password
   */
  async hashPassword(password) {
    try {
      return await bcrypt.hash(password, config.bcryptRounds);
    } catch (error) {
      logger.error('Error hashing password:', error);
      throw new Error('Password hashing failed');
    }
  }

  /**
   * Compare password with hash
   */
  async comparePassword(password, hash) {
    try {
      return await bcrypt.compare(password, hash);
    } catch (error) {
      logger.error('Error comparing password:', error);
      throw new Error('Password comparison failed');
    }
  }

  /**
   * Extract token from request
   */
  extractToken(req) {
    const authHeader = req.header('Authorization');
    const cookieToken = req.cookies?.token;

    if (authHeader && authHeader.startsWith('Bearer ')) {
      return authHeader.substring(7);
    }

    if (cookieToken) {
      return cookieToken;
    }

    return null;
  }

  /**
   * Authentication middleware
   */
  authenticate() {
    return async(req, res, next) => {
      try {
        const token = this.extractToken(req);

        if (!token) {
          return res.status(401).json({
            error: 'Authentication required',
            message: 'No token provided',
            timestamp: new Date().toISOString()
          });
        }

        const decoded = this.verifyToken(token);
        req.user = decoded;

        logger.debug(`User authenticated: ${decoded.userId || decoded.email}`);
        next();
      } catch (error) {
        logger.warn('Authentication failed:', error.message);
        return res.status(401).json({
          error: 'Authentication failed',
          message: 'Invalid or expired token',
          timestamp: new Date().toISOString()
        });
      }
    };
  }

  /**
   * Authorization middleware (role-based)
   */
  authorize(roles = []) {
    return (req, res, next) => {
      if (!req.user) {
        return res.status(401).json({
          error: 'Authentication required',
          message: 'User not authenticated',
          timestamp: new Date().toISOString()
        });
      }

      if (roles.length === 0) {
        return next(); // No specific roles required
      }

      const userRoles = req.user.roles || [];
      const hasRole = roles.some(role => userRoles.includes(role));

      if (!hasRole) {
        logger.warn(`Authorization failed for user ${req.user.userId}: required roles ${roles}, user roles ${userRoles}`);
        return res.status(403).json({
          error: 'Authorization failed',
          message: 'Insufficient permissions',
          timestamp: new Date().toISOString()
        });
      }

      next();
    };
  }

  /**
   * Optional authentication middleware (doesn't fail if no token)
   */
  optionalAuth() {
    return async(req, res, next) => {
      try {
        const token = this.extractToken(req);

        if (token) {
          const decoded = this.verifyToken(token);
          req.user = decoded;
          logger.debug(`Optional auth successful: ${decoded.userId || decoded.email}`);
        }
      } catch (error) {
        // Silently fail for optional auth
        logger.debug('Optional authentication failed:', error.message);
      }

      next();
    };
  }
}

const authService = new AuthService();

// Export individual functions for backward compatibility
module.exports = authService;
module.exports.generateToken = authService.generateToken.bind(authService);
module.exports.verifyToken = authService.verifyToken.bind(authService);
module.exports.hashPassword = authService.hashPassword.bind(authService);
module.exports.comparePassword = authService.comparePassword.bind(authService);
module.exports.requireAuth = authService.authenticate.bind(authService);
module.exports.requireRole = authService.authorize.bind(authService);
module.exports.optionalAuth = authService.optionalAuth.bind(authService);
module.exports.AuthService = AuthService;
