const request = require('supertest');
const express = require('express');

describe('Health Check Routes', () => {
  let app;

  beforeAll(() => {
    // Ensure we're in test environment
    process.env.NODE_ENV = 'test';

    app = express();
    const healthRoutes = require('../routes/health');
    app.use('/api/health', healthRoutes);
  });

  describe('GET /api/health', () => {
    test('should return basic health status', async() => {
      const response = await request(app)
        .get('/api/health/')
        .expect(200);

      expect(response.body).toHaveProperty('status', 'healthy');
      expect(response.body).toHaveProperty('timestamp');
      expect(response.body).toHaveProperty('uptime');
      expect(response.body).toHaveProperty('version');
      expect(response.body).toHaveProperty('memory');
      expect(response.body.memory).toHaveProperty('rss');
      expect(response.body.memory).toHaveProperty('heapTotal');
      expect(response.body.memory).toHaveProperty('heapUsed');
    });
  });

  describe('GET /api/health/detailed', () => {
    test('should return detailed health information', async() => {
      const response = await request(app)
        .get('/api/health/detailed')
        .expect(200);

      expect(response.body).toHaveProperty('status');
      expect(response.body).toHaveProperty('timestamp');
      expect(response.body).toHaveProperty('responseTime');
      expect(response.body).toHaveProperty('checks');
      expect(response.body).toHaveProperty('system');
      expect(response.body).toHaveProperty('services');
      expect(response.body).toHaveProperty('resources');

      // Verify checks structure
      expect(response.body.checks).toHaveProperty('memory');
      expect(response.body.checks).toHaveProperty('uptime');
      expect(response.body.checks).toHaveProperty('environment');
      expect(response.body.checks).toHaveProperty('dependencies');

      // Verify system information
      expect(response.body.system).toHaveProperty('memory');
      expect(response.body.system).toHaveProperty('cpu');
      expect(response.body.system).toHaveProperty('platform');
      expect(response.body.system).toHaveProperty('nodeVersion');

      // Verify services
      expect(response.body.services).toHaveProperty('database');
      expect(response.body.services).toHaveProperty('redis');
      expect(response.body.services).toHaveProperty('websocket');

      // Verify resources
      expect(response.body.resources).toHaveProperty('memory');
      expect(response.body.resources).toHaveProperty('cpu');
    });
  });

  describe('GET /api/health/services', () => {
    test('should return service status', async() => {
      const response = await request(app)
        .get('/api/health/services')
        .expect(200); // Should be 200 in test environment

      expect(response.body).toHaveProperty('status', 'healthy'); // Should be healthy in test environment
      expect(response.body).toHaveProperty('timestamp');
      expect(response.body).toHaveProperty('responseTime');
      expect(response.body).toHaveProperty('services');

      // Verify individual services
      expect(response.body.services).toHaveProperty('database');
      expect(response.body.services).toHaveProperty('redis');
      expect(response.body.services).toHaveProperty('email');
      expect(response.body.services).toHaveProperty('websocket');

      // In test environment, all services should be healthy
      expect(response.body.services.database.status).toBe('healthy');
      expect(response.body.services.redis.status).toBe('healthy');
      expect(response.body.services.email.status).toBe('healthy');
      expect(response.body.services.websocket.status).toBe('healthy');
    });
  });

  describe('GET /api/health/ready', () => {
    test('should return readiness status', async() => {
      const response = await request(app)
        .get('/api/health/ready')
        .expect(200);

      expect(response.body).toHaveProperty('status', 'ready');
      expect(response.body).toHaveProperty('ready', true);
      expect(response.body).toHaveProperty('checks');
      expect(response.body).toHaveProperty('services');
      expect(response.body).toHaveProperty('timestamp');

      // Verify services readiness
      expect(response.body.services).toHaveProperty('database', true);
      expect(response.body.services).toHaveProperty('cache', true);
      expect(response.body.services).toHaveProperty('storage', true);
    });
  });

  describe('GET /api/health/live', () => {
    test('should return liveness status', async() => {
      const response = await request(app)
        .get('/api/health/live')
        .expect(200);

      expect(response.body).toHaveProperty('status', 'alive');
      expect(response.body).toHaveProperty('alive', true);
      expect(response.body).toHaveProperty('checks');
      expect(response.body).toHaveProperty('timestamp');

      // Verify liveness checks
      expect(response.body.checks).toHaveProperty('server', 'running');
      expect(response.body.checks).toHaveProperty('memory', 'ok');
    });
  });

  describe('Health Check Edge Cases', () => {
    test('should handle health check gracefully under load', async() => {
      // Simulate multiple concurrent requests
      const promises = Array.from({ length: 5 }, () =>
        request(app).get('/api/health/').expect(200)
      );

      const responses = await Promise.all(promises);

      responses.forEach(response => {
        expect(response.body).toHaveProperty('status', 'healthy');
        expect(response.body).toHaveProperty('timestamp');
      });
    });

    test('should return consistent response format', async() => {
      const response = await request(app)
        .get('/api/health/')
        .expect(200);

      // Verify response structure consistency
      expect(typeof response.body.status).toBe('string');
      expect(typeof response.body.timestamp).toBe('string');
      expect(typeof response.body.uptime).toBe('string');
      expect(typeof response.body.memory).toBe('object');
      expect(typeof response.body.memory.rss).toBe('number');
      expect(typeof response.body.memory.heapTotal).toBe('number');
      expect(typeof response.body.memory.heapUsed).toBe('number');
    });
  });

  describe('Performance Tests', () => {
    test('should respond quickly to health checks', async() => {
      const startTime = Date.now();

      await request(app)
        .get('/api/health/')
        .expect(200);

      const responseTime = Date.now() - startTime;
      expect(responseTime).toBeLessThan(100); // Should respond within 100ms
    });

    test('should handle detailed health check efficiently', async() => {
      const startTime = Date.now();

      const response = await request(app)
        .get('/api/health/detailed')
        .expect(200);

      const responseTime = Date.now() - startTime;
      expect(responseTime).toBeLessThan(500); // Should respond within 500ms
      expect(response.body.responseTime).toBeDefined();
    });
  });
});
