const User = require('../models/User');
const { generateToken } = require('../utils/auth');

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
    }
  }
};

module.exports = resolvers;
