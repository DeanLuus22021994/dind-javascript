/* Resuming problem checks */
const mongoose = require('mongoose');
const logger = require('./logger');
const config = require('../config');
const memoryDatabase = require('./memoryDatabase');

class Database {
  constructor() {
    this.connection = null;
    this.isConnected = false;
  }

  async connect() {
    try {
      if (this.isConnected) {
        logger.info('Database already connected');
        return this.connection;
      } let dbUrl;

      // Use in-memory database if configured
      if (config.database.useInMemory) {
        dbUrl = await memoryDatabase.start();
        logger.info('Using in-memory MongoDB for development');
      } else {
        dbUrl = config.isTesting ? config.database.testUrl : config.database.url;
      }

      logger.info(`Connecting to database: ${dbUrl.replace(/\/\/.*@/, '//***:***@')}`);

      // Connection options
      const options = {
        maxPoolSize: 10,
        serverSelectionTimeoutMS: 5000,
        socketTimeoutMS: 45000,
        family: 4, // Use IPv4, skip trying IPv6
        retryWrites: true
      };

      this.connection = await mongoose.connect(dbUrl, options);
      this.isConnected = true;

      logger.info('✅ Database connected successfully');

      // Handle connection events
      mongoose.connection.on('error', (error) => {
        logger.error('Database connection error:', error);
      });

      mongoose.connection.on('disconnected', () => {
        logger.warn('Database disconnected');
        this.isConnected = false;
      });

      mongoose.connection.on('reconnected', () => {
        logger.info('Database reconnected');
        this.isConnected = true;
      });

      return this.connection;
    } catch (error) {
      logger.error('Failed to connect to database:', error);
      throw error;
    }
  }

  async disconnect() {
    try {
      if (!this.isConnected) {
        logger.info('Database not connected');
        return;
      } await mongoose.disconnect();
      this.isConnected = false;

      // Stop in-memory database if it was used
      if (config.database.useInMemory) {
        await memoryDatabase.stop();
      }

      logger.info('Database disconnected successfully');
    } catch (error) {
      logger.error('Error disconnecting from database:', error);
      throw error;
    }
  }

  async clearDatabase() {
    if (!config.isTesting) {
      throw new Error('Database clearing is only allowed in test environment');
    }

    try {
      const collections = await mongoose.connection.db.collections();

      for (const collection of collections) {
        await collection.deleteMany({});
      }

      logger.info('Test database cleared');
    } catch (error) {
      logger.error('Error clearing test database:', error);
      throw error;
    }
  }

  getStatus() {
    return {
      isConnected: this.isConnected,
      readyState: mongoose.connection.readyState,
      host: mongoose.connection.host,
      port: mongoose.connection.port,
      name: mongoose.connection.name
    };
  }
}

module.exports = new Database();
