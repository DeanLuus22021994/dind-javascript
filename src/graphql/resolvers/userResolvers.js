import { AuthenticationError, ForbiddenError, UserInputError } from 'apollo-server-express';
import User from '../../models/User.js';
import { generateToken } from '../../utils/auth.js';
import logger from '../../utils/logger.js';

const userResolvers = {
  Query: {
    me: async (parent, args, { user }) => {
      if (!user) {
        throw new AuthenticationError('Authentication required');
      }
      return user;
    },

    users: async (parent, args, { user }) => {
      if (!user || user.role !== 'admin') {
        throw new ForbiddenError('Admin access required');
      }
      return await User.find({ isActive: true });
    },

    user: async (parent, { id }, { user }) => {
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
    register: async (parent, { input }) => {
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

    login: async (parent, { email, password }) => {
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

    updateProfile: async (parent, { input }, { user }) => {
      if (!user) {
        throw new AuthenticationError('Authentication required');
      }

      try {
        const updatedUser = await User.findByIdAndUpdate(user._id, input, {
          new: true,
          runValidators: true
        });

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

    changePassword: async (parent, { currentPassword, newPassword }, { user }) => {
      if (!user) {
        throw new AuthenticationError('Authentication required');
      }

      try {
        // Get fresh user data from database with password
        const dbUser = await User.findById(user._id).select('+password');

        if (!dbUser) {
          throw new AuthenticationError('User not found');
        }

        // Verify current password
        const isValidPassword = await dbUser.comparePassword(currentPassword);

        if (!isValidPassword) {
          throw new UserInputError('Current password is incorrect');
        }

        // Validate new password
        if (!newPassword || newPassword.length < 6) {
          throw new UserInputError('New password must be at least 6 characters long');
        }

        // Update password (will be hashed by pre-save hook)
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

        if (error instanceof UserInputError || error instanceof AuthenticationError) {
          throw error;
        }

        throw new Error('Failed to change password');
      }
    },

    deleteUser: async (parent, { id }, { user }) => {
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

export default userResolvers;
