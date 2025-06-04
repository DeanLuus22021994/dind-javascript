import request from 'supertest';
import express from 'express';
// import mongoose from 'mongoose';
import User from '../models/User.js';

describe('Authentication Routes', () => {
  let app;

  beforeAll(async () => {
    // Setup Express app with routes
    app = express();
    app.use(express.json());
    const authRoutesModule = await import('../routes/auth.js');
    app.use('/api/auth', authRoutesModule.default || authRoutesModule);
  });

  beforeEach(async () => {
    await User.deleteMany({});
  });

  describe('POST /api/auth/register', () => {
    test('should register a new user successfully', async () => {
      const userData = {
        username: 'testuser',
        email: 'test@example.com',
        password: 'password123',
        firstName: 'Test',
        lastName: 'User'
      };

      const response = await request(app).post('/api/auth/register').send(userData).expect(201);

      expect(response.body).toHaveProperty('token');
      expect(response.body).toHaveProperty('user');
      expect(response.body.user.email).toBe(userData.email);
      expect(response.body.user).not.toHaveProperty('password');
    });

    test('should return error for duplicate email', async () => {
      const userData = {
        username: 'testuser',
        email: 'test@example.com',
        password: 'password123',
        firstName: 'Test',
        lastName: 'User'
      };

      // Create first user
      await request(app).post('/api/auth/register').send(userData).expect(201);

      // Try to create duplicate user
      const response = await request(app).post('/api/auth/register').send(userData).expect(409);

      expect(response.body).toHaveProperty('error');
    });

    test('should return error for invalid email', async () => {
      const userData = {
        username: 'testuser',
        email: 'invalid-email',
        password: 'password123'
      };

      const response = await request(app).post('/api/auth/register').send(userData).expect(400);

      expect(response.body).toHaveProperty('error');
    });

    test('should return error for weak password', async () => {
      const userData = {
        username: 'testuser',
        email: 'test@example.com',
        password: '123'
      };

      const response = await request(app).post('/api/auth/register').send(userData).expect(400);

      expect(response.body).toHaveProperty('error');
    });
  });

  describe('POST /api/auth/login', () => {
    // let registeredUser;

    beforeEach(async () => {
      const userData = {
        username: 'testuser',
        email: 'test@example.com',
        password: 'password123',
        firstName: 'Test',
        lastName: 'User'
      };

      await request(app).post('/api/auth/register').send(userData).expect(201);
    });

    test('should login with valid credentials', async () => {
      const loginData = {
        email: 'test@example.com',
        password: 'password123'
      };

      const response = await request(app).post('/api/auth/login').send(loginData).expect(200);

      expect(response.body).toHaveProperty('token');
      expect(response.body).toHaveProperty('user');
      expect(response.body.user.email).toBe(loginData.email);
    });

    test('should return error for invalid email', async () => {
      const loginData = {
        email: 'nonexistent@example.com',
        password: 'password123'
      };

      const response = await request(app).post('/api/auth/login').send(loginData).expect(401);

      expect(response.body).toHaveProperty('error');
    });

    test('should return error for invalid password', async () => {
      const loginData = {
        email: 'test@example.com',
        password: 'wrongpassword'
      };

      const response = await request(app).post('/api/auth/login').send(loginData).expect(401);

      expect(response.body).toHaveProperty('error');
    });

    test('should return error for missing email', async () => {
      const loginData = {
        password: 'password123'
      };

      const response = await request(app).post('/api/auth/login').send(loginData).expect(400);

      expect(response.body).toHaveProperty('error');
    });

    test('should return error for missing password', async () => {
      const loginData = {
        email: 'test@example.com'
      };

      const response = await request(app).post('/api/auth/login').send(loginData).expect(400);

      expect(response.body).toHaveProperty('error');
    });
  });

  describe('GET /api/auth/profile', () => {
    let token;

    beforeEach(async () => {
      const userData = {
        username: 'testuser',
        email: 'test@example.com',
        password: 'password123',
        firstName: 'Test',
        lastName: 'User'
      };

      token = (await request(app).post('/api/auth/register').send(userData).expect(201)).body.token;
    });

    test('should get user profile with valid token', async () => {
      const response = await request(app)
        .get('/api/auth/profile')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(response.body).toHaveProperty('user');
      // expect(response.body.user._id).toBe(userId);
      expect(response.body.user).not.toHaveProperty('password');
    });

    test('should return error without token', async () => {
      const response = await request(app).get('/api/auth/profile').expect(401);

      expect(response.body).toHaveProperty('error');
    });

    test('should return error with invalid token', async () => {
      const response = await request(app)
        .get('/api/auth/profile')
        .set('Authorization', 'Bearer invalid-token')
        .expect(401);

      expect(response.body).toHaveProperty('error');
    });
  });

  describe('PUT /api/auth/profile', () => {
    let token;

    beforeEach(async () => {
      const userData = {
        username: 'testuser',
        email: 'test@example.com',
        password: 'password123',
        firstName: 'Test',
        lastName: 'User'
      };

      token = (await request(app).post('/api/auth/register').send(userData).expect(201)).body.token;
    });

    test('should update user profile with valid token', async () => {
      const updateData = {
        firstName: 'Updated',
        lastName: 'Name'
      };

      const response = await request(app)
        .put('/api/auth/profile')
        .set('Authorization', `Bearer ${token}`)
        .send(updateData)
        .expect(200);

      expect(response.body).toHaveProperty('user');
      expect(response.body.user.firstName).toBe('Updated');
      expect(response.body.user.lastName).toBe('Name');
    });

    test('should return error without token', async () => {
      const updateData = {
        firstName: 'Updated',
        lastName: 'Name'
      };

      const response = await request(app).put('/api/auth/profile').send(updateData).expect(401);

      expect(response.body).toHaveProperty('error');
    });
  });

  describe('POST /api/auth/logout', () => {
    let token;

    beforeEach(async () => {
      const userData = {
        username: 'testuser',
        email: 'test@example.com',
        password: 'password123',
        firstName: 'Test',
        lastName: 'User'
      };

      token = (await request(app).post('/api/auth/register').send(userData).expect(201)).body.token;
    });

    test('should logout with valid token', async () => {
      const response = await request(app)
        .post('/api/auth/logout')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(response.body).toHaveProperty('message');
    });

    test('should return error without token', async () => {
      const response = await request(app).post('/api/auth/logout').expect(401);

      expect(response.body).toHaveProperty('error');
    });
  });
});
