const User = require('../models/User');
const { ForbiddenError, AuthenticationError } = require('apollo-server-express');
const database = require('../utils/database');
const redisClient = require('../utils/redis');
const { register } = require('../utils/metrics');
const websocketServer = require('../utils/websocket');
const { generateToken } = require('../utils/auth');

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
    me: async(parent, args, context) => {
      if (!context.user) {
        throw new Error('Authentication required');
      }
      return context.user;
    },

    users: async(parent, args, context) => {
      if (!context.user || context.user.role !== 'admin') {
        throw new Error('Admin access required');
      }
      return await User.find({ isActive: true });
    },

    user: async(parent, { id }, context) => {
      if (!context.user || (context.user.role !== 'admin' && context.user._id.toString() !== id)) {
        throw new Error('Access denied');
      }
      return await User.findById(id);
    },

    files: async(_, { limit = 20, offset = 0 }, context) => {
      await getUser(context); // Verify user authentication
      // Implementation would depend on your file storage system
      // This is a placeholder
      return [];
    },

    file: async(_, { id }, context) => {
      await getUser(context); // Verify user authentication
      // Implementation would depend on your file storage system
      return null;
    },

    messages: async(_, { room, limit = 50, offset = 0 }, context) => {
      await getUser(context); // Verify user authentication
      // Implementation would depend on your message storage system
      return [];
    },

    health: async() => {
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

    metrics: async() => {
      return register.metrics();
    },

    systemStats: async(_, __, context) => {
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
    register: async(parent, { username, email, password, firstName, lastName }) => {
      // Check if user already exists
      const existingUser = await User.findOne({
        $or: [{ email }, { username }]
      });

      if (existingUser) {
        throw new Error('User already exists with this email or username');
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
      const token = generateToken(user._id);

      return {
        token,
        user: user.toJSON()
      };
    },

    login: async(parent, { email, password }) => {
      const user = await User.findOne({ email, isActive: true });

      if (!user) {
        throw new Error('Invalid credentials');
      }

      const isValidPassword = await user.comparePassword(password);

      if (!isValidPassword) {
        throw new Error('Invalid credentials');
      }

      // Update last login
      user.lastLogin = new Date();
      await user.save();

      const token = generateToken(user._id);

      return {
        token,
        user: user.toJSON()
      };
    },

    updateProfile: async(parent, { firstName, lastName }, context) => {
      if (!context.user) {
        throw new Error('Authentication required');
      }

      const user = await User.findByIdAndUpdate(
        context.user._id,
        { firstName, lastName },
        { new: true }
      );

      return user;
    },

    deleteAccount: async(parent, args, context) => {
      if (!context.user) {
        throw new Error('Authentication required');
      }

      await User.findByIdAndUpdate(
        context.user._id,
        { isActive: false }
      );

      return true;
    },

    uploadFile: async(_, { file }, context) => {
      // Get user but explicitly ignore it - only needed for authentication check
      /* eslint-disable-next-line no-unused-vars */
      const _user = await getUser(context);

      // This would be implemented with file storage
      return {
        id: 'file-id',
        filename: file.filename,
        mimetype: file.mimetype,
        url: `https://example.com/files/${file.filename}`
      };
    },

    deleteFile: async(_, { id }, context) => {
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
