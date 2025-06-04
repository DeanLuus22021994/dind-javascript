import express from 'express';
import User from '../models/User.js';
import { generateToken, requireAuth } from '../utils/auth.js';
import logger from '../utils/logger.js';
const router = express.Router();

/**
 * @api {post} /api/auth/register Register a new user
 * @apiName RegisterUser
 * @apiGroup Authentication
 */
router.post('/register', async (req, res) => {
  try {
    const { username, email, password, firstName, lastName } = req.body;

    // Validate required fields
    if (!username || !email || !password) {
      return res.status(400).json({
        error: 'Username, email, and password are required'
      });
    }

    // Check if user already exists
    const existingUser = await User.findOne({
      $or: [{ email }, { username }]
    });

    if (existingUser) {
      return res.status(409).json({
        error: 'User already exists with this email or username'
      });
    }

    // Create new user
    const user = new User({
      username,
      email,
      password,
      firstName,
      lastName
    });

    await user.save();

    // Generate token
    const token = generateToken(user._id);

    // Only log successful registrations in non-test environments
    if (process.env.NODE_ENV !== 'test') {
      logger.info(`New user registered: ${email}`);
    }

    res.status(201).json({
      message: 'User registered successfully',
      token,
      user: user.toJSON()
    });
  } catch (error) {
    // Only log validation errors in non-test environments to reduce test noise
    if (process.env.NODE_ENV !== 'test') {
      logger.error('Registration error:', error);
    }

    if (error.name === 'ValidationError') {
      const errors = Object.values(error.errors).map(err => err.message);
      return res.status(400).json({ error: errors.join(', ') });
    }
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @api {post} /api/auth/login Login user
 * @apiName LoginUser
 * @apiGroup Authentication
 */
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    // Validate required fields
    if (!email || !password) {
      return res.status(400).json({
        error: 'Email and password are required'
      });
    }

    // Find user by email and include password field
    const user = await User.findOne({ email, isActive: true }).select('+password');

    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Compare password
    const isValidPassword = await user.comparePassword(password);

    if (!isValidPassword) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Update last login
    user.lastLogin = new Date();
    await user.save();

    // Generate token
    const token = generateToken(user._id);

    if (process.env.NODE_ENV !== 'test') {
      logger.info(`User logged in: ${email}`);
    }

    res.json({
      message: 'Login successful',
      token,
      user: user.toJSON()
    });
  } catch (error) {
    if (process.env.NODE_ENV !== 'test') {
      logger.error('Login error:', error);
    }
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @api {get} /api/auth/profile Get user profile
 * @apiName GetProfile
 * @apiGroup Authentication
 */
router.get('/profile', requireAuth, async (req, res) => {
  try {
    // Since req.user is already a plain object without password, we can return it directly
    res.json({
      user: req.user
    });
  } catch (error) {
    if (process.env.NODE_ENV !== 'test') {
      logger.error('Profile error:', error);
    }
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @api {put} /api/auth/profile Update user profile
 * @apiName UpdateProfile
 * @apiGroup Authentication
 */
router.put('/profile', requireAuth, async (req, res) => {
  try {
    const { firstName, lastName } = req.body;

    const user = await User.findByIdAndUpdate(
      req.user._id,
      { firstName, lastName },
      { new: true, runValidators: true }
    );

    res.json({
      message: 'Profile updated successfully',
      user: user.toJSON()
    });
  } catch (error) {
    if (process.env.NODE_ENV !== 'test') {
      logger.error('Profile update error:', error);
    }

    if (error.name === 'ValidationError') {
      const errors = Object.values(error.errors).map(err => err.message);
      return res.status(400).json({ error: errors.join(', ') });
    }

    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @api {post} /api/auth/logout Logout user
 * @apiName LogoutUser
 * @apiGroup Authentication
 */
router.post('/logout', requireAuth, async (req, res) => {
  try {
    // In a more sophisticated implementation, you might blacklist the token
    // For now, we'll just return success since JWT tokens are stateless
    if (process.env.NODE_ENV !== 'test') {
      logger.info(`User logged out: ${req.user.email}`);
    }

    res.json({ message: 'Logout successful' });
  } catch (error) {
    if (process.env.NODE_ENV !== 'test') {
      logger.error('Logout error:', error);
    }
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
