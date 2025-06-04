import { ApolloServer } from 'apollo-server-express';
import { makeExecutableSchema } from '@graphql-tools/schema';
import jwt from 'jsonwebtoken';
import User from '../models/User.js';
import config from '../config/index.js';
import logger from '../utils/logger.js';
import typeDefs from './schema/index.js';
import userResolvers from './resolvers/userResolvers.js';

// Combine resolvers
const resolvers = {
  Query: {
    ...userResolvers.Query
  },
  Mutation: {
    ...userResolvers.Mutation
  }
};

// Create executable schema
const schema = makeExecutableSchema({
  typeDefs,
  resolvers
});

// Context function to handle authentication
const context = async ({ req }) => {
  let user = null;

  try {
    const authHeader = req.headers.authorization;
    if (authHeader) {
      const token = authHeader.replace('Bearer ', '');
      const decoded = jwt.verify(token, config.jwtSecret);
      user = await User.findById(decoded.userId);
    }
  } catch (error) {
    // Authentication failed, user remains null
    if (process.env.NODE_ENV !== 'test') {
      logger.warn('GraphQL authentication failed:', error.message);
    }
  }

  return { user };
};

// Create Apollo Server
async function createApolloServer() {
  const server = new ApolloServer({
    schema,
    context,
    // Disable introspection and playground in production
    introspection: !config.isProduction,
    playground: !config.isProduction,
    // Error formatting
    formatError: error => {
      if (process.env.NODE_ENV !== 'test') {
        logger.error('GraphQL Error:', error);
      }

      // Return sanitized error in production
      return config.isProduction ? new Error('Internal server error') : error;
    },
    // Handle CORS
    cors: {
      origin: config.corsOrigin,
      credentials: true
    }
  });

  return server;
}

export { createApolloServer, schema, resolvers };
