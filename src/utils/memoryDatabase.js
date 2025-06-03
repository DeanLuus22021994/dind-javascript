const { MongoMemoryServer } = require('mongodb-memory-server');
const logger = require('./logger');

class MemoryDatabase {
  constructor() {
    this.mongoServer = null;
    this.uri = null;
  }

  async start() {
    try {
      logger.info('Starting in-memory MongoDB server...');

      this.mongoServer = await MongoMemoryServer.create({
        instance: {
          dbName: 'dind-javascript-memory',
          port: 27018 // Different port to avoid conflicts
        }
      });

      this.uri = this.mongoServer.getUri();
      logger.info(`✅ In-memory MongoDB started at: ${this.uri}`);

      return this.uri;
    } catch (error) {
      logger.error('Failed to start in-memory MongoDB:', error);
      throw error;
    }
  }

  async stop() {
    if (this.mongoServer) {
      await this.mongoServer.stop();
      logger.info('🛑 In-memory MongoDB stopped');
    }
  }

  getUri() {
    return this.uri;
  }
}

module.exports = new MemoryDatabase();
