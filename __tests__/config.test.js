const originalEnv = process.env;

describe('Configuration', () => {
  beforeEach(() => {
    jest.resetModules();
    process.env = { ...originalEnv };
  });

  afterAll(() => {
    process.env = originalEnv;
  });

  it('should have default values', async () => {
    // Reset NODE_ENV to get default behavior
    delete process.env.NODE_ENV;
    const { default: config } = await import('../src/config/index.js?' + Date.now());
    expect(config.port).toBe(3000);
    expect(config.nodeEnv).toBe('development');
    expect(config.rateLimitWindowMs).toBe(900000);
    expect(config.rateLimitMaxRequests).toBe(100);
  });

  it('should use environment variables when available', async () => {
    process.env.PORT = '8080';
    process.env.NODE_ENV = 'production';
    process.env.RATE_LIMIT_MAX_REQUESTS = '50';
    const { default: newConfig } = await import('../src/config/index.js?' + Date.now());
    expect(newConfig.port).toBe(8080);
    expect(newConfig.nodeEnv).toBe('production');
    expect(newConfig.rateLimitMaxRequests).toBe(50);
  });

  it('should correctly identify environment types', async () => {
    // Set NODE_ENV to development explicitly for this test
    process.env.NODE_ENV = 'development';
    const { default: config } = await import('../src/config/index.js?' + Date.now());
    expect(config.isDevelopment).toBe(true);
    expect(config.isProduction).toBe(false);
    expect(config.isTest).toBe(false);
  });

  it('should validate database configuration', async () => {
    const { default: config } = await import('../src/config/index.js?' + Date.now());
    expect(config.database).toBeDefined();
    expect(config.database.url).toBeDefined();
    expect(config.databaseUrl).toBeDefined();
  });

  it('should validate Redis configuration', async () => {
    const { default: config } = await import('../src/config/index.js?' + Date.now());
    expect(config.redis).toBeDefined();
    expect(config.redis.url).toBeDefined();
    expect(config.redisUrl).toBeDefined();
  });
});
