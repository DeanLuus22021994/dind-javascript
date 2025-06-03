const originalEnv = process.env;

describe('Configuration', () => {
  beforeEach(() => {
    jest.resetModules();
    process.env = { ...originalEnv };
  });

  afterAll(() => {
    process.env = originalEnv;
  });

  it('should have default values', () => {
    // Reset NODE_ENV to get default behavior
    delete process.env.NODE_ENV;

    delete require.cache[require.resolve('../src/config')];
    const config = require('../src/config');

    expect(config.port).toBe(3000);
    expect(config.nodeEnv).toBe('development');
    expect(config.rateLimitWindowMs).toBe(900000);
    expect(config.rateLimitMaxRequests).toBe(100);
  });

  it('should use environment variables when available', () => {
    process.env.PORT = '8080';
    process.env.NODE_ENV = 'production';
    process.env.RATE_LIMIT_MAX_REQUESTS = '50';

    // Re-require config to pick up new env vars
    delete require.cache[require.resolve('../src/config')];
    const newConfig = require('../src/config');

    expect(newConfig.port).toBe(8080);
    expect(newConfig.nodeEnv).toBe('production');
    expect(newConfig.rateLimitMaxRequests).toBe(50);
  });

  it('should correctly identify environment types', () => {
    // Set NODE_ENV to development explicitly for this test
    process.env.NODE_ENV = 'development';

    delete require.cache[require.resolve('../src/config')];
    const config = require('../src/config');

    expect(config.isDevelopment).toBe(true);
    expect(config.isProduction).toBe(false);
    expect(config.isTest).toBe(false);
  });

  it('should validate database configuration', () => {
    delete require.cache[require.resolve('../src/config')];
    const config = require('../src/config');

    expect(config.database).toBeDefined();
    expect(config.database.url).toBeDefined();
    expect(config.databaseUrl).toBeDefined();
  });

  it('should validate Redis configuration', () => {
    delete require.cache[require.resolve('../src/config')];
    const config = require('../src/config');

    expect(config.redis).toBeDefined();
    expect(config.redis.url).toBeDefined();
    expect(config.redisUrl).toBeDefined();
  });
});
