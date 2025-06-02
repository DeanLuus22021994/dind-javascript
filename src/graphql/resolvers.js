const { AuthenticationError, ForbiddenError, UserInputError } = require('apollo-server-express');
const { GraphQLUpload } = require('graphql-upload');
const { GraphQLDateTime } = require('graphql-scalars');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const fs = require('fs').promises;
const path = require('path');

const User = require('../models/User');
const config = require('../config');
const logger = require('../utils/logger');
const websocketServer = require('../utils/websocket');
const database = require('../utils/database');
const redisClient = require('../utils/redis');
const { register } = require('../utils/metrics');

// Authentication helper
const getUser = async(context) => {
  const token = context.req.headers.authorization?.replace('Bearer ', '');
  if (!token) {
    throw new AuthenticationError('No token provided');
  }

  try {
    const decoded = jwt.verify(token, config.jwtSecret);
    const user = await User.findById(decoded.userId);
    if (!user || !user.isActive) {
      throw new AuthenticationError('Invalid or inactive user');
    }
    return user;
  } catch (error) {
    throw new AuthenticationError('Invalid token');
  }
};

// Check admin role
const requireAdmin = (user) => {
  if (user.role !== 'admin') {
    throw new ForbiddenError('Admin access required');
  }
};

const resolvers = {
  Upload: GraphQLUpload,
  Date: GraphQLDateTime,

  Query: {
    me: async(_, __, context) => {
      return await getUser(context);
    },

    users: async(_, { limit = 20, offset = 0, search }, context) => {
      const user = await getUser(context);
      requireAdmin(user);

      const query = search
        ? {
          $or: [
            { username: { $regex: search, $options: 'i' } },
            { email: { $regex: search, $options: 'i' } },
            { firstName: { $regex: search, $options: 'i' } },
            { lastName: { $regex: search, $options: 'i' } }
          ]
        }
        : {};

      return await User.find(query)
        .skip(offset)
        .limit(limit)
        .sort({ createdAt: -1 });
    },

    user: async(_, { id }, context) => {
      const user = await getUser(context);

      // Users can only view their own profile unless they're admin
      if (user._id.toString() !== id && user.role !== 'admin') {
        throw new ForbiddenError('Access denied');
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
        },
        diskUsage: {
          total: 0, // Implement disk usage calculation
          used: 0,
          free: 0,
          percentage: 0
        }
      };
    }
  },

  Mutation: {
    register: async(_, { input }) => {
      const { username, email, password, firstName, lastName } = input;

      // Check if user already exists
      const existingUser = await User.findOne({
        $or: [{ email }, { username }]
      });

      if (existingUser) {
        throw new UserInputError('User already exists with this email or username');
      }

      // Hash password
      const hashedPassword = await bcrypt.hash(password, 12);

      // Create user
      const user = new User({
        username,
        email,
        password: hashedPassword,
        firstName,
        lastName,
        role: 'user',
        isActive: true
      });

      await user.save();

      // Generate tokens
      const token = jwt.sign(
        { userId: user._id, email: user.email },
        config.jwtSecret,
        { expiresIn: config.jwtExpiresIn }
      );

      const refreshToken = jwt.sign(
        { userId: user._id },
        config.jwtRefreshSecret,
        { expiresIn: config.jwtRefreshExpiresIn }
      );

      return {
        token,
        refreshToken,
        user,
        expiresIn: 3600 // 1 hour
      };
    },

    login: async(_, { input }) => {
      const { email, password } = input;

      // Find user
      const user = await User.findOne({ email });
      if (!user || !user.isActive) {
        throw new AuthenticationError('Invalid credentials');
      }

      // Check password
      const isValid = await bcrypt.compare(password, user.password);
      if (!isValid) {
        throw new AuthenticationError('Invalid credentials');
      }

      // Update last login
      user.lastLogin = new Date();
      await user.save();

      // Generate tokens
      const token = jwt.sign(
        { userId: user._id, email: user.email },
        config.jwtSecret,
        { expiresIn: config.jwtExpiresIn }
      );

      const refreshToken = jwt.sign(
        { userId: user._id },
        config.jwtRefreshSecret,
        { expiresIn: config.jwtRefreshExpiresIn }
      );

      return {
        token,
        refreshToken,
        user,
        expiresIn: 3600
      };
    },

    logout: async(_, __, context) => {
      // In a real implementation, you might want to blacklist the token
      return true;
    },

    refreshToken: async(_, __, context) => {
      const refreshToken = context.req.headers['x-refresh-token'];
      if (!refreshToken) {
        throw new AuthenticationError('No refresh token provided');
      }

      try {
        const decoded = jwt.verify(refreshToken, config.jwtRefreshSecret);
        const user = await User.findById(decoded.userId);

        if (!user || !user.isActive) {
          throw new AuthenticationError('Invalid user');
        }

        const newToken = jwt.sign(
          { userId: user._id, email: user.email },
          config.jwtSecret,
          { expiresIn: config.jwtExpiresIn }
        );

        const newRefreshToken = jwt.sign(
          { userId: user._id },
          config.jwtRefreshSecret,
          { expiresIn: config.jwtRefreshExpiresIn }
        );

        return {
          token: newToken,
          refreshToken: newRefreshToken,
          user,
          expiresIn: 3600
        };
      } catch (error) {
        throw new AuthenticationError('Invalid refresh token');
      }
    },

    updateProfile: async(_, { input }, context) => {
      const user = await getUser(context);

      Object.keys(input).forEach(key => {
        if (key in ['firstName', 'lastName']) {
          user[key] = input[key];
        } else if (user.profile) {
          user.profile[key] = input[key];
        } else {
          user.profile = { [key]: input[key] };
        }
      });

      await user.save();
      return user;
    },

    updatePreferences: async(_, { input }, context) => {
      const user = await getUser(context);

      if (!user.preferences) {
        user.preferences = {};
      }

      Object.keys(input).forEach(key => {
        user.preferences[key] = input[key];
      });

      await user.save();
      return user;
    },

    uploadAvatar: async(_, { file }, context) => {
      const user = await getUser(context);

      try {
        const { createReadStream, filename, mimetype } = await file;

        // Validate file
        if (!mimetype.startsWith('image/')) {
          throw new UserInputError('Only image files are allowed');
        }

        // Save file (implementation depends on your upload system)
        const stream = createReadStream();
        const filePath = path.join('uploads', 'avatars', `${user._id}-${Date.now()}-${filename}`);

        // Create directory if it doesn't exist
        await fs.mkdir(path.dirname(filePath), { recursive: true });

        // Save file
        const writeStream = require('fs').createWriteStream(filePath);
        stream.pipe(writeStream);

        await new Promise((resolve, reject) => {
          writeStream.on('finish', resolve);
          writeStream.on('error', reject);
        });

        // Update user avatar
        user.avatar = `/upload/files/${path.basename(filePath)}`;
        await user.save();

        return user;
      } catch (error) {
        logger.error('Avatar upload failed:', error);
        throw new UserInputError('Failed to upload avatar');
      }
    },

    uploadFile: async(_, { file }, context) => {
      const user = await getUser(context);

      try {
        const { createReadStream, filename, mimetype } = await file;

        // Save file (implementation depends on your upload system)
        const stream = createReadStream();
        const filePath = path.join('uploads', 'files', `${Date.now()}-${filename}`);

        await fs.mkdir(path.dirname(filePath), { recursive: true });

        const writeStream = require('fs').createWriteStream(filePath);
        stream.pipe(writeStream);

        await new Promise((resolve, reject) => {
          writeStream.on('finish', resolve);
          writeStream.on('error', reject);
        });

        // Return file info (you might want to save this to database)
        return {
          id: Date.now().toString(),
          filename: path.basename(filePath),
          originalName: filename,
          mimetype,
          size: 0, // You might want to calculate actual size
          path: filePath,
          url: `/upload/files/${path.basename(filePath)}`,
          uploadedBy: user,
          uploadedAt: new Date()
        };
      } catch (error) {
        logger.error('File upload failed:', error);
        throw new UserInputError('Failed to upload file');
      }
    },
    uploadFiles: async(_, { files }, context) => {
      await getUser(context); // Verify user authentication
      const uploadedFiles = [];

      for (const file of files) {
        try {
          const result = await resolvers.Mutation.uploadFile(_, { file }, context);
          uploadedFiles.push(result);
        } catch (error) {
          logger.error('Failed to upload file:', error);
        }
      }

      return uploadedFiles;
    },

    sendMessage: async(_, { room, content }, context) => {
      const user = await getUser(context);

      const message = {
        id: Date.now().toString(),
        content,
        user,
        room,
        timestamp: new Date(),
        edited: false
      };

      // Broadcast to WebSocket clients
      websocketServer.broadcastToRoom(room, 'new_message', message);

      return message;
    },

    updateUserRole: async(_, { userId, role }, context) => {
      const currentUser = await getUser(context);
      requireAdmin(currentUser);

      const user = await User.findById(userId);
      if (!user) {
        throw new UserInputError('User not found');
      }

      user.role = role.toLowerCase();
      await user.save();

      return user;
    },

    deactivateUser: async(_, { userId }, context) => {
      const currentUser = await getUser(context);
      requireAdmin(currentUser);

      const user = await User.findById(userId);
      if (!user) {
        throw new UserInputError('User not found');
      }

      user.isActive = false;
      await user.save();

      return user;
    },

    activateUser: async(_, { userId }, context) => {
      const currentUser = await getUser(context);
      requireAdmin(currentUser);

      const user = await User.findById(userId);
      if (!user) {
        throw new UserInputError('User not found');
      }

      user.isActive = true;
      await user.save();

      return user;
    },

    deleteUser: async(_, { userId }, context) => {
      const currentUser = await getUser(context);
      requireAdmin(currentUser);

      if (currentUser._id.toString() === userId) {
        throw new UserInputError('Cannot delete your own account');
      }

      const result = await User.findByIdAndDelete(userId);
      return !!result;
    }
  },
  Subscription: {
    // Basic subscription placeholders - would need proper implementation
    messageAdded: {
      subscribe: () => {
        // Placeholder for message subscription
        return {
          [Symbol.asyncIterator]: async function * () {
            // Implementation would go here
          }
        };
      }
    },

    userJoined: {
      subscribe: () => {
        return {
          [Symbol.asyncIterator]: async function * () {
            // Implementation would go here
          }
        };
      }
    },

    userLeft: {
      subscribe: () => {
        return {
          [Symbol.asyncIterator]: async function * () {
            // Implementation would go here
          }
        };
      }
    },

    userTyping: {
      subscribe: () => {
        return {
          [Symbol.asyncIterator]: async function * () {
            // Implementation would go here
          }
        };
      }
    },

    systemAlert: {
      subscribe: () => {
        return {
          [Symbol.asyncIterator]: async function * () {
            // Implementation would go here
          }
        };
      }
    }
  }
};

module.exports = resolvers;
