const User = require('../models/User');
const { ForbiddenError, AuthenticationError, UserInputError } = require('apollo-server-express');
const logger = require('../utils/logger');
const database = require('../utils/database');
const redisClient = require('../utils/redis');
const { register } = require('../utils/metrics');
const websocketServer = require('../utils/websocket');

// Helper function to get authenticated user from context
async function getUser(context) {
  if (!context.user) {
    throw new AuthenticationError('No token provided');
  }
  return context.user;
}

// Helper function to require admin role
function requireAdmin(user) {
  if (user.role !== 'admin') {
    throw new ForbiddenError('Admin access required');
  }
}

const resolvers = {
  Query: {
    me: async (_, __, context) => {
      return await getUser(context);
    },

    users: async (_, { limit = 10, offset = 0 }, context) => {
      const user = await getUser(context);

      // Only admins can view all users
      if (user.role !== 'admin') {
        throw new ForbiddenError('Admin access required');
      }

      return await User.find()
        .skip(offset)
        .limit(limit)
        .sort({ createdAt: -1 });
    },

    user: async (_, { id }, context) => {
      const user = await getUser(context);

      // Users can only view their own profile unless they're admin
      if (user._id.toString() !== id && user.role !== 'admin') {
        throw new ForbiddenError('Access denied');
      }

      return await User.findById(id);
    },

    files: async (_, { limit = 20, offset = 0 }, context) => {
      await getUser(context); // Verify user authentication
      // Implementation would depend on your file storage system
      // This is a placeholder
      return [];
    },

    file: async (_, { id }, context) => {
      await getUser(context); // Verify user authentication
      // Implementation would depend on your file storage system
      return null;
    },

    messages: async (_, { room, limit = 50, offset = 0 }, context) => {
      await getUser(context); // Verify user authentication
      // Implementation would depend on your message storage system
      return [];
    },

    health: async () => {
      const memUsage = process.memoryUsage();

      return {
        status: 'healthy',
        timestamp: new Date(),
        uptime: process.uptime(),
        memory: {
          rss: memUsage.rss / 1024 / 1024,
          heapTotal: memUsage.heapTotal / 1024 / 1024,
          heapUsed: memUsage.heapUsed / 1024 / 1024,
          external: memUsage.external / 1024 / 1024
        },
        services: {
          database: {
            status: database.getConnectionStatus() === 1 ? 'healthy' : 'unhealthy',
            connected: database.getConnectionStatus() === 1,
            details: database.getConnectionStatus() === 1 ? 'Connected' : 'Disconnected'
          },
          redis: {
            status: redisClient.isConnected() ? 'healthy' : 'unhealthy',
            connected: redisClient.isConnected(),
            details: redisClient.isConnected() ? 'Connected' : 'Disconnected'
          },
          email: {
            status: 'not-configured',
            connected: false,
            details: 'Email service not configured'
          },
          websocket: {
            status: 'healthy',
            connected: true,
            details: `${websocketServer.getConnectedUsers()} users connected`
          }
        }
      };
    },

    metrics: async () => {
      return register.metrics();
    },

    systemStats: async (_, __, context) => {
      const user = await getUser(context);
      requireAdmin(user);

      const totalUsers = await User.countDocuments();
      const activeUsers = await User.countDocuments({ isActive: true });

      return {
        totalUsers,
        activeUsers,
        totalFiles: 0, // Implement based on your file storage
        totalMessages: 0, // Implement based on your message storage
        systemUptime: process.uptime(),
        memoryUsage: {
          rss: process.memoryUsage().rss / 1024 / 1024,
          heapTotal: process.memoryUsage().heapTotal / 1024 / 1024,
          heapUsed: process.memoryUsage().heapUsed / 1024 / 1024,
          external: process.memoryUsage().external / 1024 / 1024
        }
      };
    }
  },

  Mutation: {
    register: async (_, { input }) => {
      const { username, email, password, firstName, lastName } = input;

      // Check if user already exists
      const existingUser = await User.findOne({ $or: [{ email }, { username }] });
      if (existingUser) {
        throw new UserInputError('User already exists with that email or username');
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
      logger.info(`New user registered: ${email}`);

      // Generate token and return user data
      const token = generateToken(user._id);
      return {
        token,
        user
      };
    },

    login: async (_, { email, password }) => {
      // Find user by email
      const user = await User.findOne({ email });
      if (!user) {
        throw new UserInputError('Invalid email or password');
      }

      // Check password
      const isMatch = await user.comparePassword(password);
      if (!isMatch) {
        throw new UserInputError('Invalid email or password');
      }

      // Update last login
      user.lastLogin = new Date();
      await user.save();

      // Generate token and return user data
      const token = generateToken(user._id);
      return {
        token,
        user
      };
    },

    updateProfile: async (_, { input }, context) => {
      const user = await getUser(context);

      // Check required fields
      if (!input || Object.keys(input).length === 0) {
        throw new UserInputError('No profile data provided');
      }

      // Update allowed fields
      const allowedFields = ['firstName', 'lastName', 'bio', 'avatar'];
      const updateData = {};

      allowedFields.forEach(field => {
        if (input[field] !== undefined) {
          updateData[field] = input[field];
        }
      });

      // Apply updates
      Object.assign(user, updateData);
      await user.save();

      return user;
    },

    changePassword: async (_, { currentPassword, newPassword }, context) => {
      const user = await getUser(context);

      // Validate current password
      const isMatch = await user.comparePassword(currentPassword);
      if (!isMatch) {
        throw new UserInputError('Current password is incorrect');
      }

      // Validate new password
      if (!newPassword || newPassword.length < 6) {
        throw new UserInputError('New password must be at least 6 characters');
      }

      // Update password
      user.password = newPassword;
      await user.save();

      return true;
    },

    deleteAccount: async (_, { password }, context) => {
      const user = await getUser(context);

      // Validate password
      const isMatch = await user.comparePassword(password);
      if (!isMatch) {
        throw new UserInputError('Password is incorrect');
      }

      // Delete user
      await User.findByIdAndDelete(user._id);
      return true;
    },

    uploadFile: async (_, { file }, context) => {
      // Get user but mark as unused with comment to avoid linting errors
      const _user = await getUser(context); // Authentication check only

      // This would be implemented with file storage
      return {
        id: 'file-id',
        filename: file.filename,
        mimetype: file.mimetype,
        url: `https://example.com/files/${file.filename}`
      };
    },

    deleteFile: async (_, { id }, context) => {
      await getUser(context);

      // This would be implemented with file storage
      return true;
    }
  },

  User: {
    // Resolve computed fields or handle references
    fullName: (user) => {
      return `${user.firstName || ''} ${user.lastName || ''}`.trim();
    }
  },

  Subscription: {
    messageAdded: {
      subscribe: () => {
        return {
          [Symbol.asyncIterator]: async function* () {
            // Implementation would go here
          }
        };
      }
    },

    userTyping: {
      subscribe: () => {
        return {
          [Symbol.asyncIterator]: async function* () {
            // Implementation would go here
          }
        };
      }
    },

    systemAlert: {
      subscribe: () => {
        return {
          [Symbol.asyncIterator]: async function* () {
            // Implementation would go here
          }
        };
      }
    }
  }
};

module.exports = resolvers;

// Helper function to generate token (imported from auth utils)
function generateToken(userId) {
  const jwt = require('jsonwebtoken');
  const config = require('../config');
  return jwt.sign(
    { userId: userId.toString() },
    config.jwtSecret,
    { expiresIn: config.jwtExpiresIn }
  );
}
