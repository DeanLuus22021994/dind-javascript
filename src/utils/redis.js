const redis = require('redis');
const logger = require('./logger');
const config = require('../config');

class RedisClient {
  constructor() {
    this.client = null;
    this.isConnected = false;
  }

  async connect() {
    try {
      if (this.isConnected) {
        logger.info('Redis already connected');
        return this.client;
      }

      const redisConfig = {
        url: config.redis.url,
        retry_strategy: (options) => {
          if (options.error && options.error.code === 'ECONNREFUSED') {
            logger.error('Redis server connection refused');
            return new Error('Redis server connection refused');
          }
          if (options.total_retry_time > 1000 * 60 * 60) {
            logger.error('Redis retry time exhausted');
            return new Error('Redis retry time exhausted');
          }
          if (options.attempt > 10) {
            logger.error('Redis max retry attempts reached');
            return new Error('Redis max retry attempts reached');
          }
          return Math.min(options.attempt * 100, 3000);
        }
      };

      if (config.redis.password) {
        redisConfig.password = config.redis.password;
      }

      this.client = redis.createClient(redisConfig);

      this.client.on('error', (error) => {
        logger.error('Redis client error:', error);
        this.isConnected = false;
      });

      this.client.on('connect', () => {
        logger.info('✅ Redis client connected');
        this.isConnected = true;
      });

      this.client.on('ready', () => {
        logger.info('Redis client ready');
      });

      this.client.on('end', () => {
        logger.info('Redis client disconnected');
        this.isConnected = false;
      });

      await this.client.connect();
      return this.client;
    } catch (error) {
      logger.error('Failed to connect to Redis:', error);
      // Don't throw - allow app to continue without Redis
      return null;
    }
  }

  async disconnect() {
    try {
      if (!this.isConnected || !this.client) {
        logger.info('Redis not connected');
        return;
      }

      await this.client.disconnect();
      this.isConnected = false;
      logger.info('Redis disconnected successfully');
    } catch (error) {
      logger.error('Error disconnecting from Redis:', error);
    }
  }

  async get(key) {
    try {
      if (!this.isConnected || !this.client) {
        return null;
      }

      const value = await this.client.get(key);
      return value ? JSON.parse(value) : null;
    } catch (error) {
      logger.error(`Error getting key ${key} from Redis:`, error);
      return null;
    }
  }

  async set(key, value, ttlSeconds = 3600) {
    try {
      if (!this.isConnected || !this.client) {
        return false;
      }

      const stringValue = JSON.stringify(value);
      await this.client.setEx(key, ttlSeconds, stringValue);
      return true;
    } catch (error) {
      logger.error(`Error setting key ${key} in Redis:`, error);
      return false;
    }
  }

  async del(key) {
    try {
      if (!this.isConnected || !this.client) {
        return false;
      }

      await this.client.del(key);
      return true;
    } catch (error) {
      logger.error(`Error deleting key ${key} from Redis:`, error);
      return false;
    }
  }

  async exists(key) {
    try {
      if (!this.isConnected || !this.client) {
        return false;
      }

      const exists = await this.client.exists(key);
      return exists === 1;
    } catch (error) {
      logger.error(`Error checking existence of key ${key} in Redis:`, error);
      return false;
    }
  }

  async flush() {
    try {
      if (!this.isConnected || !this.client) {
        return false;
      }

      if (!config.isTesting) {
        throw new Error('Redis flush is only allowed in test environment');
      }

      await this.client.flushAll();
      logger.info('Redis cache flushed');
      return true;
    } catch (error) {
      logger.error('Error flushing Redis:', error);
      return false;
    }
  }

  getStatus() {
    return {
      isConnected: this.isConnected,
      client: this.client ? 'initialized' : 'not initialized'
    };
  }
}

module.exports = new RedisClient();
