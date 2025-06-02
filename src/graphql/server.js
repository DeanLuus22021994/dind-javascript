const { ApolloServer } = require('apollo-server-express');
const { makeExecutableSchema } = require('@graphql-tools/schema');
const jwt = require('jsonwebtoken');

const typeDefs = require('./schema');
const resolvers = require('./resolvers');
const config = require('../config');
const logger = require('../utils/logger');
const User = require('../models/User');

// Create executable schema
const schema = makeExecutableSchema({
  typeDefs,
  resolvers
});

// Apollo Server configuration
function createApolloServer() {
  const server = new ApolloServer({
    schema,
    context: async({ req, res, connection }) => {
      // For subscriptions
      if (connection) {
        return connection.context;
      }

      // For queries and mutations
      let user = null;
      const token = req.headers.authorization?.replace('Bearer ', '');

      if (token) {
        try {
          const decoded = jwt.verify(token, config.jwtSecret);
          user = await User.findById(decoded.userId);
        } catch (error) {
          // Invalid token, user remains null
        }
      }

      return {
        req,
        res,
        user
      };
    },
    subscriptions: {
      onConnect: async(connectionParams) => {
        // Handle authentication for subscriptions
        const token = connectionParams.authorization?.replace('Bearer ', '');
        if (!token) {
          throw new Error('Missing auth token!');
        }

        try {
          const decoded = jwt.verify(token, config.jwtSecret);
          const user = await User.findById(decoded.userId);
          if (!user || !user.isActive) {
            throw new Error('Invalid user!');
          }

          return { user };
        } catch (error) {
          throw new Error('Invalid token!');
        }
      },
      onDisconnect: () => {
        logger.info('GraphQL subscription disconnected');
      }
    },
    formatError: (error) => {
      // Log the error
      logger.error('GraphQL Error:', {
        message: error.message,
        locations: error.locations,
        path: error.path,
        stack: error.stack
      });

      // Don't expose internal errors in production
      if (config.isProduction && error.message.startsWith('Database')) {
        return new Error('Internal server error');
      }

      return error;
    },
    formatResponse: (response, { request, context }) => {
      // Log slow queries
      if (request.operationName && context.startTime) {
        const duration = Date.now() - context.startTime;
        if (duration > 1000) { // Log queries taking more than 1 second
          logger.warn('Slow GraphQL query:', {
            operationName: request.operationName,
            duration: `${duration}ms`,
            user: context.user?.email || 'anonymous'
          });
        }
      }

      return response;
    },
    plugins: [
      // Custom plugin to track execution time
      {
        requestDidStart() {
          return {
            didResolveOperation({ context }) {
              context.startTime = Date.now();
            },
            willSendResponse({ response, context }) {
              const duration = Date.now() - (context.startTime || Date.now());
              response.extensions = response.extensions || {};
              response.extensions.executionTime = `${duration}ms`;
            }
          };
        }
      }
    ],
    introspection: !config.isProduction,
    playground: !config.isProduction
      ? {
        settings: {
          'request.credentials': 'include'
        }
      }
      : false,
    debug: !config.isProduction
  });

  return server;
}

module.exports = { createApolloServer };
