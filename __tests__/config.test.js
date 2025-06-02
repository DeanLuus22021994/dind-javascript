const config = require('../src/config');

describe('Configuration', () => {
  const originalEnv = process.env;

  beforeEach(() => {
    jest.resetModules();
    process.env = { ...originalEnv };
  });

  afterAll(() => {
    process.env = originalEnv;
  });

  it('should have default values', () => {
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
    expect(config.isDevelopment).toBe(true);
    expect(config.isProduction).toBe(false);
    expect(config.isTesting).toBe(false);
  });
});
