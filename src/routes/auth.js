const express = require('express');
const router = express.Router();
const User = require('../models/User');
const { generateToken, requireAuth } = require('../utils/auth');
const logger = require('../utils/logger');

/**
 * @route POST /api/auth/register
 * @description Register a new user
 */
router.post('/register', async(req, res) => {
  try {
    const { username, email, password, firstName, lastName } = req.body;

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return res.status(400).json({ error: 'Invalid email format' });
    }

    // Validate password strength
    if (password.length < 6) {
      return res.status(400).json({ error: 'Password must be at least 6 characters' });
    }

    // Check if user already exists
    const existingUser = await User.findOne({ $or: [{ email }, { username }] });
    if (existingUser) {
      return res.status(409).json({ error: 'User already exists with that email or username' });
    }

    // Create new user
    const user = new User({
      username,
      email,
      password, // Will be hashed by pre-save hook
      firstName,
      lastName
    });

    await user.save();
    logger.info(`New user registered: ${email}`);

    // Generate token
    const token = generateToken(user._id);

    // Return user info without password
    const userObj = user.toObject();
    delete userObj.password;

    res.status(201).json({
      token,
      user: userObj
    });
  } catch (error) {
    logger.error('Registration error:', error);
    res.status(500).json({ error: 'Registration failed' });
  }
});

/**
 * @route POST /api/auth/login
 * @description Authenticate user and get token
 */
router.post('/login', async(req, res) => {
  try {
    const { email, password } = req.body;

    // Find user by email
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Check password
    const isMatch = await user.comparePassword(password);
    if (!isMatch) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Update last login
    user.lastLogin = new Date();
    await user.save();

    // Generate token
    const token = generateToken(user._id);

    // Return user info without password
    const userObj = user.toObject();
    delete userObj.password;

    res.json({
      token,
      user: userObj
    });
  } catch (error) {
    logger.error('Login error:', error);
    res.status(500).json({ error: 'Login failed' });
  }
});

/**
 * @route GET /api/auth/profile
 * @description Get user profile
 */
router.get('/profile', requireAuth, async(req, res) => {
  try {
    // User is already available in req.user from requireAuth middleware
    const user = req.user;

    // Return user info without password
    const userObj = user.toObject();
    delete userObj.password;

    res.json({ user: userObj });
  } catch (error) {
    logger.error('Profile retrieval error:', error);
    res.status(500).json({ error: 'Failed to retrieve profile' });
  }
});

/**
 * @route PUT /api/auth/profile
 * @description Update user profile
 */
router.put('/profile', requireAuth, async(req, res) => {
  try {
    const { firstName, lastName, bio } = req.body;
    const user = req.user;

    // Update allowed fields
    if (firstName) user.firstName = firstName;
    if (lastName) user.lastName = lastName;
    if (bio) user.bio = bio;

    await user.save();

    // Return updated user info without password
    const userObj = user.toObject();
    delete userObj.password;

    res.json({ user: userObj });
  } catch (error) {
    logger.error('Profile update error:', error);
    res.status(500).json({ error: 'Failed to update profile' });
  }
});

/**
 * @route PUT /api/auth/password
 * @description Change password
 */
router.put('/password', requireAuth, async(req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;
    const user = req.user;

    // Validate current password
    const isMatch = await user.comparePassword(currentPassword);
    if (!isMatch) {
      return res.status(401).json({ error: 'Current password is incorrect' });
    }

    // Validate new password
    if (newPassword.length < 6) {
      return res.status(400).json({ error: 'New password must be at least 6 characters' });
    }

    // Update password
    user.password = newPassword;
    await user.save();

    res.json({ message: 'Password updated successfully' });
  } catch (error) {
    logger.error('Password change error:', error);
    res.status(500).json({ error: 'Failed to change password' });
  }
});

module.exports = router;
