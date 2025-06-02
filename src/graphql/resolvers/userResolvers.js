const { AuthenticationError, ForbiddenError, UserInputError } = require('apollo-server-express');
const User = require('../../models/User');
const { generateToken } = require('../../utils/auth');
const logger = require('../../utils/logger');

const userResolvers = {
  Query: {
    me: async(parent, args, { user }) => {
      if (!user) {
        // Don't log authentication errors in test environment - they're expected
        if (!process.env.NODE_ENV || process.env.NODE_ENV !== 'test') {
          logger.error('GraphQL Error: Authentication required');
        }
        throw new AuthenticationError('Authentication required');
      }
      return user;
    },

    users: async(parent, args, { user }) => {
      if (!user || user.role !== 'admin') {
        // Don't log authorization errors in test environment - they're expected
        if (!process.env.NODE_ENV || process.env.NODE_ENV !== 'test') {
          logger.error('GraphQL Error: Admin access required');
        }
        throw new ForbiddenError('Admin access required');
      }
      return await User.find({ isActive: true });
    },

    user: async(parent, { id }, { user }) => {
      if (!user) {
        throw new AuthenticationError('Authentication required');
      }

      // Users can only access their own profile unless they are admin
      if (user._id.toString() !== id && user.role !== 'admin') {
        throw new ForbiddenError('Access denied');
      }

      return await User.findById(id);
    }
  },

  Mutation: {
    register: async(parent, { input }) => {
      try {
        const { username, email, password, firstName, lastName } = input;

        // Check if user already exists
        const existingUser = await User.findOne({
          $or: [{ email }, { username }]
        });

        if (existingUser) {
          throw new UserInputError('User already exists with this email or username');
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

        if (process.env.NODE_ENV !== 'test') {
          logger.info(`New user registered via GraphQL: ${email}`);
        }

        return {
          token,
          user
        };
      } catch (error) {
        if (process.env.NODE_ENV !== 'test') {
          logger.error('GraphQL registration error:', error);
        }

        if (error.name === 'ValidationError') {
          const errors = Object.values(error.errors).map(err => err.message);
          throw new UserInputError(errors.join(', '));
        }
        throw error;
      }
    },

    login: async(parent, { email, password }) => {
      try {
        const user = await User.findOne({ email, isActive: true });

        if (!user) {
          throw new AuthenticationError('Invalid credentials');
        }

        const isValidPassword = await user.comparePassword(password);

        if (!isValidPassword) {
          throw new AuthenticationError('Invalid credentials');
        }

        // Update last login
        user.lastLogin = new Date();
        await user.save();

        // Generate token
        const token = generateToken(user._id);

        if (process.env.NODE_ENV !== 'test') {
          logger.info(`User logged in via GraphQL: ${email}`);
        }

        return {
          token,
          user
        };
      } catch (error) {
        if (process.env.NODE_ENV !== 'test') {
          logger.error('GraphQL login error:', error);
        }
        throw error;
      }
    },

    updateProfile: async(parent, { input }, { user }) => {
      if (!user) {
        // Don't log authentication errors in test environment
        if (!process.env.NODE_ENV || process.env.NODE_ENV !== 'test') {
          logger.error('GraphQL Error: Authentication required');
        }
        throw new AuthenticationError('Authentication required');
      }

      try {
        const updatedUser = await User.findByIdAndUpdate(
          user._id,
          input,
          { new: true, runValidators: true }
        );

        if (process.env.NODE_ENV !== 'test') {
          logger.info(`User profile updated via GraphQL: ${user.email}`);
        }

        return updatedUser;
      } catch (error) {
        if (process.env.NODE_ENV !== 'test') {
          logger.error('GraphQL profile update error:', error);
        }

        if (error.name === 'ValidationError') {
          const errors = Object.values(error.errors).map(err => err.message);
          throw new UserInputError(errors.join(', '));
        }
        throw error;
      }
    },

    changePassword: async(parent, { currentPassword, newPassword }, { user }) => {
      if (!user) {
        throw new AuthenticationError('Authentication required');
      }

      try {
        const dbUser = await User.findById(user._id);

        if (!dbUser) {
          throw new AuthenticationError('User not found');
        }

        const isValidPassword = await dbUser.comparePassword(currentPassword);

        if (!isValidPassword) {
          // Don't log password errors in test environment - they're expected
          if (!process.env.NODE_ENV || process.env.NODE_ENV !== 'test') {
            logger.error('GraphQL Error: Current password is incorrect');
          }
          throw new UserInputError('Current password is incorrect');
        }

        dbUser.password = newPassword;
        await dbUser.save();

        if (process.env.NODE_ENV !== 'test') {
          logger.info(`Password changed via GraphQL for user: ${user.email}`);
        }

        return {
          success: true,
          message: 'Password changed successfully'
        };
      } catch (error) {
        if (process.env.NODE_ENV !== 'test') {
          logger.error('GraphQL change password error:', error);
        }
        throw error;
      }
    },

    deleteUser: async(parent, { id }, { user }) => {
      if (!user || user.role !== 'admin') {
        throw new ForbiddenError('Admin access required');
      }

      try {
        const userToDelete = await User.findById(id);

        if (!userToDelete) {
          throw new UserInputError('User not found');
        }

        // Soft delete by setting isActive to false
        userToDelete.isActive = false;
        await userToDelete.save();

        if (process.env.NODE_ENV !== 'test') {
          logger.info(`User deleted via GraphQL: ${userToDelete.email}`);
        }

        return {
          success: true,
          message: 'User deleted successfully'
        };
      } catch (error) {
        if (process.env.NODE_ENV !== 'test') {
          logger.error('GraphQL delete user error:', error);
        }
        throw error;
      }
    }
  }
};

module.exports = userResolvers;
