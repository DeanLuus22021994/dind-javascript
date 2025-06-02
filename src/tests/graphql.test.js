const request = require('supertest');
const express = require('express');
// Removed unused ApolloServer import
const { createApolloServer } = require('../graphql/server');
const User = require('../models/User');
const jwt = require('jsonwebtoken');
const config = require('../../config');

describe('GraphQL API', () => {
  let app;
  let server;
  let token;
  let userId;

  beforeAll(async() => {
    // Create Express app
    app = express();

    // Create Apollo Server
    server = await createApolloServer();
    await server.start();
    server.applyMiddleware({ app, path: '/graphql' });
  });

  beforeEach(async() => {
    // Create a test user and get token
    const user = new User({
      username: 'testuser',
      email: 'test@example.com',
      password: 'password123',
      firstName: 'Test',
      lastName: 'User'
    });
    await user.save();

    userId = user._id.toString();
    token = jwt.sign({ userId }, config.jwtSecret);
  });

  afterEach(async() => {
    await User.deleteMany({});
  });

  afterAll(async() => {
    if (server) {
      await server.stop();
    }
  });

  describe('Query: me', () => {
    test('should return current user when authenticated', async() => {
      const query = `
        query {
          me {
            id
            username
            email
            firstName
            lastName
          }
        }
      `;

      const response = await request(app)
        .post('/graphql')
        .set('Authorization', `Bearer ${token}`)
        .send({ query })
        .expect(200);

      expect(response.body.data.me).toBeTruthy();
      expect(response.body.data.me.email).toBe('test@example.com');
      expect(response.body.data.me.username).toBe('testuser');
    });

    test('should return error when not authenticated', async() => {
      const query = `
        query {
          me {
            id
            username
            email
          }
        }
      `;

      const response = await request(app)
        .post('/graphql')
        .send({ query })
        .expect(200);

      expect(response.body.errors).toBeTruthy();
      expect(response.body.errors[0].message).toContain('authenticated');
    });
  });

  describe('Query: users', () => {
    beforeEach(async() => {
      // Create additional test users
      await User.create([
        {
          username: 'user1',
          email: 'user1@example.com',
          password: 'password123',
          firstName: 'User',
          lastName: 'One'
        },
        {
          username: 'user2',
          email: 'user2@example.com',
          password: 'password123',
          firstName: 'User',
          lastName: 'Two'
        }
      ]);
    });

    test('should return list of users when authenticated', async() => {
      const query = `
        query {
          users {
            id
            username
            email
            firstName
            lastName
          }
        }
      `;

      const response = await request(app)
        .post('/graphql')
        .set('Authorization', `Bearer ${token}`)
        .send({ query })
        .expect(200);

      expect(response.body.data.users).toBeTruthy();
      expect(response.body.data.users.length).toBeGreaterThan(0);
      expect(response.body.data.users.some(user => user.email === 'user1@example.com')).toBe(true);
    });

    test('should return error when not authenticated', async() => {
      const query = `
        query {
          users {
            id
            username
            email
          }
        }
      `;

      const response = await request(app)
        .post('/graphql')
        .send({ query })
        .expect(200);

      expect(response.body.errors).toBeTruthy();
    });
  });

  describe('Mutation: updateProfile', () => {
    test('should update user profile when authenticated', async() => {
      const mutation = `
        mutation {
          updateProfile(input: {
            firstName: "Updated"
            lastName: "Name"
          }) {
            id
            firstName
            lastName
          }
        }
      `;

      const response = await request(app)
        .post('/graphql')
        .set('Authorization', `Bearer ${token}`)
        .send({ query: mutation })
        .expect(200);

      expect(response.body.data.updateProfile).toBeTruthy();
      expect(response.body.data.updateProfile.firstName).toBe('Updated');
      expect(response.body.data.updateProfile.lastName).toBe('Name');
    });

    test('should return error when not authenticated', async() => {
      const mutation = `
        mutation {
          updateProfile(input: {
            firstName: "Updated"
            lastName: "Name"
          }) {
            id
            firstName
            lastName
          }
        }
      `;

      const response = await request(app)
        .post('/graphql')
        .send({ query: mutation })
        .expect(200);

      expect(response.body.errors).toBeTruthy();
    });
  });

  describe('Mutation: changePassword', () => {
    test('should change password with correct current password', async() => {
      const mutation = `
        mutation {
          changePassword(
            currentPassword: "password123"
            newPassword: "newpassword123"
          )
        }
      `;

      const response = await request(app)
        .post('/graphql')
        .set('Authorization', `Bearer ${token}`)
        .send({ query: mutation })
        .expect(200);

      expect(response.body.data.changePassword).toBe(true);
    });

    test('should return error with incorrect current password', async() => {
      const mutation = `
        mutation {
          changePassword(
            currentPassword: "wrongpassword"
            newPassword: "newpassword123"
          )
        }
      `;

      const response = await request(app)
        .post('/graphql')
        .set('Authorization', `Bearer ${token}`)
        .send({ query: mutation })
        .expect(200);

      expect(response.body.errors).toBeTruthy();
    });
  });
});
