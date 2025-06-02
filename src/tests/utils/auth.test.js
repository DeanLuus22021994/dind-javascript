const jwt = require('jsonwebtoken');
const { generateToken, verifyToken, requireAuth, requireRole } = require('../../utils/auth');
const User = require('../../models/User');
const config = require('../../config');

describe('Authentication Utilities', () => {
  let user;

  beforeEach(async() => {
    user = new User({
      username: 'testuser',
      email: 'test@example.com',
      password: 'password123',
      firstName: 'Test',
      lastName: 'User',
      role: 'user'
    });
    await user.save();
  });

  afterEach(async() => {
    await User.deleteMany({});
  });

  describe('generateToken', () => {
    test('should generate a valid JWT token', () => {
      const token = generateToken(user._id);

      expect(typeof token).toBe('string');
      expect(token.split('.')).toHaveLength(3); // JWT has 3 parts

      // Verify the token
      const decoded = jwt.verify(token, config.jwtSecret);
      expect(decoded.userId).toBe(user._id.toString());
    });

    test('should include expiration in token', () => {
      const token = generateToken(user._id);
      const decoded = jwt.verify(token, config.jwtSecret);

      expect(decoded.exp).toBeDefined();
      expect(decoded.iat).toBeDefined();
      expect(decoded.exp > decoded.iat).toBe(true);
    });
  });

  describe('verifyToken', () => {
    test('should verify a valid token', async() => {
      const token = generateToken(user._id);
      const decoded = await verifyToken(token);

      expect(decoded).toBeTruthy();
      expect(decoded.userId).toBe(user._id.toString());
    });

    test('should reject an invalid token', async() => {
      const invalidToken = 'invalid.token.here';

      await expect(verifyToken(invalidToken)).rejects.toThrow();
    });

    test('should reject an expired token', async() => {
      // Create a token that expires immediately
      const expiredToken = jwt.sign(
        { userId: user._id },
        config.jwtSecret,
        { expiresIn: '0s' }
      );

      // Wait a moment to ensure expiration
      await new Promise(resolve => setTimeout(resolve, 100));

      await expect(verifyToken(expiredToken)).rejects.toThrow();
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
    });

    test('should authenticate user with valid token', async() => {
      const token = generateToken(user._id);
      req.headers.authorization = `Bearer ${token}`;

      await requireAuth(req, res, next);

      expect(req.user).toBeTruthy();
      expect(req.user._id.toString()).toBe(user._id.toString());
      expect(next).toHaveBeenCalled();
      expect(res.status).not.toHaveBeenCalled();
    });

    test('should reject request without token', async() => {
      await requireAuth(req, res, next);

      expect(req.user).toBeNull();
      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith({ error: 'Access denied. No token provided.' });
      expect(next).not.toHaveBeenCalled();
    });

    test('should reject request with invalid token', async() => {
      req.headers.authorization = 'Bearer invalid.token.here';

      await requireAuth(req, res, next);

      expect(req.user).toBeNull();
      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith({ error: 'Invalid token.' });
      expect(next).not.toHaveBeenCalled();
    });

    test('should handle token without Bearer prefix', async() => {
      const token = generateToken(user._id);
      req.headers.authorization = token; // No "Bearer " prefix

      await requireAuth(req, res, next);

      expect(req.user).toBeNull();
      expect(res.status).toHaveBeenCalledWith(401);
      expect(next).not.toHaveBeenCalled();
    });

    test('should handle non-existent user', async() => {
      // Delete the user but use a valid token format
      await User.findByIdAndDelete(user._id);
      const token = generateToken(user._id);
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
      // Create admin user
      const adminUser = new User({
        username: 'admin',
        email: 'admin@example.com',
        password: 'password123',
        firstName: 'Admin',
        lastName: 'User',
        role: 'admin'
      });
      await adminUser.save();

      req.user = adminUser;

      const middleware = requireRole('admin');
      await middleware(req, res, next);

      expect(next).toHaveBeenCalled();
      expect(res.status).not.toHaveBeenCalled();
    });

    test('should deny access for user with incorrect role', async() => {
      req.user = user; // Regular user

      const middleware = requireRole('admin');
      await middleware(req, res, next);

      expect(res.status).toHaveBeenCalledWith(403);
      expect(res.json).toHaveBeenCalledWith({ error: 'Access denied. Insufficient permissions.' });
      expect(next).not.toHaveBeenCalled();
    });

    test('should deny access when no user is present', async() => {
      req.user = null;

      const middleware = requireRole('admin');
      await middleware(req, res, next);

      expect(res.status).toHaveBeenCalledWith(403);
      expect(res.json).toHaveBeenCalledWith({ error: 'Access denied. Insufficient permissions.' });
      expect(next).not.toHaveBeenCalled();
    });

    test('should allow access for multiple valid roles', async() => {
      // Create moderator user
      const moderatorUser = new User({
        username: 'moderator',
        email: 'mod@example.com',
        password: 'password123',
        firstName: 'Mod',
        lastName: 'User',
        role: 'moderator'
      });
      await moderatorUser.save();

      req.user = moderatorUser;

      const middleware = requireRole(['admin', 'moderator']);
      await middleware(req, res, next);

      expect(next).toHaveBeenCalled();
      expect(res.status).not.toHaveBeenCalled();
    });
  });
});
