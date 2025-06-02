const request = require('supertest');
const app = require('../src/index');

describe('API Endpoints', () => {
  let server;

  beforeAll((done) => {
    server = app.listen(0, done); // Use random port for testing
  });

  afterAll((done) => {
    server.close(done);
  });

  describe('GET /', () => {
    it('should return application information', async() => {
      const response = await request(app)
        .get('/')
        .expect(200);

      expect(response.body).toHaveProperty('message');
      expect(response.body).toHaveProperty('timestamp');
      expect(response.body).toHaveProperty('environment');
      expect(response.body).toHaveProperty('nodeVersion');
      expect(response.body).toHaveProperty('features');
      expect(Array.isArray(response.body.features)).toBe(true);
    });
  });

  describe('Health Endpoints', () => {
    it('should return health status', async() => {
      const response = await request(app)
        .get('/health')
        .expect(200);

      expect(response.body).toHaveProperty('status', 'healthy');
      expect(response.body).toHaveProperty('uptime');
      expect(response.body).toHaveProperty('memory');
    });

    it('should return detailed health information', async() => {
      const response = await request(app)
        .get('/health/detailed')
        .expect(200);

      expect(response.body).toHaveProperty('status');
      expect(response.body).toHaveProperty('checks');
      expect(response.body).toHaveProperty('system');
      expect(response.body).toHaveProperty('resources');
    });

    it('should return readiness status', async() => {
      const response = await request(app)
        .get('/health/ready')
        .expect(200);

      expect(response.body).toHaveProperty('status', 'ready');
      expect(response.body).toHaveProperty('checks');
    });

    it('should return liveness status', async() => {
      const response = await request(app)
        .get('/health/live')
        .expect(200);

      expect(response.body).toHaveProperty('status', 'alive');
      expect(response.body).toHaveProperty('checks');
    });
  });

  describe('API Endpoints', () => {
    it('should return API information', async() => {
      const response = await request(app)
        .get('/api/info')
        .expect(200);

      expect(response.body).toHaveProperty('name');
      expect(response.body).toHaveProperty('version');
      expect(response.body).toHaveProperty('environment');
    });

    it('should echo posted data', async() => {
      const testData = { message: 'Hello, World!', metadata: { test: true } };

      const response = await request(app)
        .post('/api/echo')
        .send(testData)
        .expect(200);

      expect(response.body).toHaveProperty('echo');
      expect(response.body.echo.message).toBe(testData.message);
      expect(response.body.echo.metadata).toEqual(testData.metadata);
      expect(response.body).toHaveProperty('requestId');
    });

    it('should validate echo endpoint input', async() => {
      const response = await request(app)
        .post('/api/echo')
        .send({}) // Empty body
        .expect(400);

      expect(response.body).toHaveProperty('error', 'Validation Error');
      expect(response.body).toHaveProperty('details');
    });

    it('should return paginated data', async() => {
      const response = await request(app)
        .get('/api/data?page=1&limit=5')
        .expect(200);

      expect(response.body).toHaveProperty('data');
      expect(response.body).toHaveProperty('pagination');
      expect(Array.isArray(response.body.data)).toBe(true);
      expect(response.body.data).toHaveLength(5);
      expect(response.body.pagination.page).toBe(1);
      expect(response.body.pagination.limit).toBe(5);
    });

    it('should filter data by search term', async() => {
      const response = await request(app)
        .get('/api/data?search=Item 1')
        .expect(200);

      expect(response.body).toHaveProperty('data');
      expect(response.body.filters.search).toBe('Item 1');
      // Should find items containing "Item 1"
      response.body.data.forEach(item => {
        expect(item.name.toLowerCase()).toContain('item 1');
      });
    });

    it('should return API status', async() => {
      const response = await request(app)
        .get('/api/status')
        .expect(200);

      expect(response.body).toHaveProperty('status', 'operational');
      expect(response.body).toHaveProperty('uptime');
      expect(response.body).toHaveProperty('memory');
      expect(response.body).toHaveProperty('cpu');
    });
  });

  describe('Error Handling', () => {
    it('should return 404 for non-existent routes', async() => {
      const response = await request(app)
        .get('/non-existent-route')
        .expect(404);

      expect(response.body).toHaveProperty('error', 'Route not found');
      expect(response.body).toHaveProperty('message');
    });
  });

  describe('Security Headers', () => {
    it('should include security headers', async() => {
      const response = await request(app)
        .get('/')
        .expect(200);

      // Check for helmet security headers
      expect(response.headers).toHaveProperty('x-dns-prefetch-control');
      expect(response.headers).toHaveProperty('x-frame-options');
      expect(response.headers).toHaveProperty('x-download-options');
      expect(response.headers).toHaveProperty('x-content-type-options');
      expect(response.headers).toHaveProperty('x-xss-protection');
    });
  });

  describe('Rate Limiting', () => {
    it('should include rate limit headers on API routes', async() => {
      const response = await request(app)
        .get('/api/info')
        .expect(200);

      expect(response.headers).toHaveProperty('x-ratelimit-limit');
      expect(response.headers).toHaveProperty('x-ratelimit-remaining');
    });
  });
});
