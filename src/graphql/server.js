const { ApolloServer } = require('apollo-server-express');
const { makeExecutableSchema } = require('@graphql-tools/schema');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const config = require('../config');
const logger = require('../utils/logger');

// Import type definitions and resolvers
const typeDefs = require('./schema');
const userResolvers = require('./resolvers/userResolvers');

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
const context = async({ req }) => {
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
    formatError: (error) => {
      if (process.env.NODE_ENV !== 'test') {
        logger.error('GraphQL Error:', error);
      }

      // Return sanitized error in production
      return config.isProduction
        ? new Error('Internal server error')
        : error;
    },
    // Handle CORS
    cors: {
      origin: config.corsOrigin,
      credentials: true
    }
  });

  return server;
}

module.exports = {
  createApolloServer,
  schema,
  resolvers
};
