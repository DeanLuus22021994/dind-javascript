const request = require('supertest');
const express = require('express');

describe('Health Check Routes', () => {
  let app;

  beforeAll(async() => {
    app = express();

    // Import and use health routes
    const healthRoutes = require('../../routes/health');
    app.use('/api/health', healthRoutes);
  });

  describe('GET /api/health', () => {
    test('should return basic health status', async() => {
      const response = await request(app)
        .get('/api/health')
        .expect(200);

      expect(response.body).toHaveProperty('status', 'ok');
      expect(response.body).toHaveProperty('timestamp');
      expect(response.body).toHaveProperty('uptime');
      expect(response.body).toHaveProperty('version');
    });
  });

  describe('GET /api/health/detailed', () => {
    test('should return detailed health status', async() => {
      const response = await request(app)
        .get('/api/health/detailed')
        .expect(200);

      expect(response.body).toHaveProperty('status');
      expect(response.body).toHaveProperty('timestamp');
      expect(response.body).toHaveProperty('services');
      expect(response.body.services).toHaveProperty('database');
      expect(response.body.services).toHaveProperty('redis');
      expect(response.body.services).toHaveProperty('websocket');
    });

    test('should include system information', async() => {
      const response = await request(app)
        .get('/api/health/detailed')
        .expect(200);

      expect(response.body).toHaveProperty('system');
      expect(response.body.system).toHaveProperty('memory');
      expect(response.body.system).toHaveProperty('cpu');
      expect(response.body.system).toHaveProperty('platform');
      expect(response.body.system).toHaveProperty('nodeVersion');
    });
  });

  describe('GET /api/health/ready', () => {
    test('should return readiness status', async() => {
      const response = await request(app)
        .get('/api/health/ready')
        .expect(200);

      expect(response.body).toHaveProperty('ready');
      expect(response.body).toHaveProperty('services');
    });
  });

  describe('GET /api/health/live', () => {
    test('should return liveness status', async() => {
      const response = await request(app)
        .get('/api/health/live')
        .expect(200);

      expect(response.body).toHaveProperty('alive', true);
      expect(response.body).toHaveProperty('timestamp');
    });
  });
});
