import User from '../models/User.js';
import { generateToken } from '../utils/auth.js';

const resolvers = {
  Query: {
    me: async (parent, args, context) => {
      if (!context.user) {
        throw new Error('Authentication required');
      }
      return context.user;
    },

    users: async (parent, args, context) => {
      if (!context.user || context.user.role !== 'admin') {
        throw new Error('Admin access required');
      }
      return await User.find({ isActive: true });
    },

    user: async (parent, { id }, context) => {
      if (!context.user || (context.user.role !== 'admin' && context.user._id.toString() !== id)) {
        throw new Error('Access denied');
      }
      return await User.findById(id);
    }
  },

  Mutation: {
    register: async (parent, { input }) => {
      const { username, email, password, firstName, lastName } = input;

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
        refreshToken: token, // In a real app, this would be a separate refresh token
        user: user.toJSON(),
        expiresIn: 86400 // 24 hours in seconds
      };
    },

    login: async (parent, { input }) => {
      const { email, password } = input;

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
        refreshToken: token, // In a real app, this would be a separate refresh token
        user: user.toJSON(),
        expiresIn: 86400 // 24 hours in seconds
      };
    },

    updateProfile: async (parent, { input }, context) => {
      if (!context.user) {
        throw new Error('Authentication required');
      }

      const { firstName, lastName } = input;

      const user = await User.findByIdAndUpdate(
        context.user._id,
        { firstName, lastName },
        { new: true }
      );

      return user;
    },

    changePassword: async (parent, { currentPassword, newPassword }, context) => {
      if (!context.user) {
        throw new Error('Authentication required');
      }

      const user = await User.findById(context.user._id);
      const isValidPassword = await user.comparePassword(currentPassword);

      if (!isValidPassword) {
        throw new Error('Current password is incorrect');
      }

      user.password = newPassword;
      await user.save();

      return true;
    },

    deleteAccount: async (parent, args, context) => {
      if (!context.user) {
        throw new Error('Authentication required');
      }

      await User.findByIdAndUpdate(context.user._id, { isActive: false });

      return true;
    }
  }
};

export default resolvers;
