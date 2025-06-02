const jwt = require('jsonwebtoken');
const { generateToken, verifyToken, requireAuth, requireRole } = require('../../utils/auth');
const User = require('../../models/User');
const config = require('../../config');

// Mock User model
jest.mock('../../models/User');

describe('Authentication Utilities', () => {
  describe('generateToken', () => {
    test('should generate a valid JWT token', () => {
      const userId = '507f1f77bcf86cd799439011';
      const token = generateToken(userId);

      expect(token).toBeDefined();
      expect(typeof token).toBe('string');

      // Verify the token is valid
      const decoded = jwt.verify(token, config.jwtSecret);
      expect(decoded.userId).toBe(userId);
    });

    test('should include expiration in token', () => {
      const userId = '507f1f77bcf86cd799439011';
      const token = generateToken(userId);

      const decoded = jwt.verify(token, config.jwtSecret);
      expect(decoded.exp).toBeDefined();
      expect(decoded.iat).toBeDefined();
    });
  });

  describe('verifyToken', () => {
    test('should verify a valid token', () => {
      const userId = '507f1f77bcf86cd799439011';
      const token = generateToken(userId);

      const decoded = verifyToken(token);
      expect(decoded.userId).toBe(userId);
    });

    test('should reject an invalid token', () => {
      expect(() => {
        verifyToken('invalid-token');
      }).toThrow('Invalid token');
    });

    test('should reject an expired token', (done) => {
      // Create an expired token
      const expiredToken = jwt.sign(
        { userId: '507f1f77bcf86cd799439011' },
        config.jwtSecret,
        { expiresIn: '0s' }
      );

      // Wait a bit to ensure expiration
      setTimeout(() => {
        expect(() => {
          verifyToken(expiredToken);
        }).toThrow('Token expired');
        done();
      }, 100);
    });
  });

  describe('requireAuth middleware', () => {
    let req, res, next;

    beforeEach(() => {
      req = {
        headers: {},
        user: null
      };
      res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn()
      };
      next = jest.fn();

      // Reset mocks
      User.findById.mockReset();
    });

    test('should authenticate user with valid token', async() => {
      const userId = '507f1f77bcf86cd799439011';
      const token = generateToken(userId);
      const mockUser = {
        _id: userId,
        email: 'test@example.com',
        username: 'testuser',
        isActive: true,
        toObject: jest.fn().mockReturnValue({
          _id: userId,
          email: 'test@example.com',
          username: 'testuser',
          isActive: true,
          password: 'hashedpassword'
        })
      };

      User.findById.mockResolvedValue(mockUser);
      req.headers.authorization = `Bearer ${token}`;

      await requireAuth(req, res, next);

      expect(req.user).toEqual({
        _id: userId,
        email: 'test@example.com',
        username: 'testuser',
        isActive: true
      });
      expect(next).toHaveBeenCalled();
    });

    test('should reject request without token', async() => {
      await requireAuth(req, res, next);

      expect(req.user).toBeNull();
      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith({ error: 'Access denied. No token provided.' });
      expect(next).not.toHaveBeenCalled();
    });

    test('should reject request with invalid token', async() => {
      req.headers.authorization = 'Bearer invalid-token';

      await requireAuth(req, res, next);

      expect(req.user).toBeNull();
      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith({ error: 'Invalid token.' });
      expect(next).not.toHaveBeenCalled();
    });

    test('should handle token without Bearer prefix', async() => {
      const userId = '507f1f77bcf86cd799439011';
      const token = generateToken(userId);
      req.headers.authorization = token; // No Bearer prefix

      await requireAuth(req, res, next);

      expect(req.user).toBeNull();
      expect(res.status).toHaveBeenCalledWith(401);
      expect(next).not.toHaveBeenCalled();
    });

    test('should handle non-existent user', async() => {
      const userId = '507f1f77bcf86cd799439011';
      const token = generateToken(userId);

      User.findById.mockResolvedValue(null);
      req.headers.authorization = `Bearer ${token}`;

      await requireAuth(req, res, next);

      expect(req.user).toBeNull();
      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith({ error: 'User not found.' });
      expect(next).not.toHaveBeenCalled();
    });
  });

  describe('requireRole middleware', () => {
    let req, res, next;

    beforeEach(() => {
      req = {
        user: null
      };
      res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn()
      };
      next = jest.fn();
    });

    test('should allow access for user with correct role', async() => {
      req.user = {
        _id: '507f1f77bcf86cd799439011',
        role: 'admin'
      };

      const middleware = requireRole('admin');
      await middleware(req, res, next);

      expect(next).toHaveBeenCalled();
    });

    test('should deny access for user with incorrect role', async() => {
      req.user = {
        _id: 'd8ac872f-523a-42e0-91e8-da86de118e98',
        role: 'user'
      };

      const middleware = requireRole('admin');
      await middleware(req, res, next);

      expect(res.status).toHaveBeenCalledWith(403);
      expect(res.json).toHaveBeenCalledWith({ error: 'Access denied. Insufficient permissions.' });
      expect(next).not.toHaveBeenCalled();
    });

    test('should deny access when no user is present', async() => {
      const middleware = requireRole('admin');
      await middleware(req, res, next);

      expect(res.status).toHaveBeenCalledWith(403);
      expect(res.json).toHaveBeenCalledWith({ error: 'Access denied. Insufficient permissions.' });
      expect(next).not.toHaveBeenCalled();
    });

    test('should allow access for multiple valid roles', async() => {
      req.user = {
        _id: '507f1f77bcf86cd799439011',
        role: 'moderator'
      };

      const middleware = requireRole(['admin', 'moderator']);
      await middleware(req, res, next);

      expect(next).toHaveBeenCalled();
    });
  });
});
