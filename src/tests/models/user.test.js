const User = require('../../models/User');
const bcrypt = require('bcryptjs');

describe('User Model', () => {
  afterEach(async() => {
    await User.deleteMany({});
  });

  describe('User Creation', () => {
    test('should create a new user with valid data', async() => {
      const userData = {
        username: 'testuser',
        email: 'test@example.com',
        password: 'password123',
        firstName: 'Test',
        lastName: 'User'
      };

      const user = new User(userData);
      await user.save();

      expect(user._id).toBeDefined();
      expect(user.username).toBe(userData.username);
      expect(user.email).toBe(userData.email);
      expect(user.firstName).toBe(userData.firstName);
      expect(user.lastName).toBe(userData.lastName);
      expect(user.password).not.toBe(userData.password); // Should be hashed
      expect(user.isActive).toBe(true);
      expect(user.role).toBe('user');
    });

    test('should hash password before saving', async() => {
      const password = 'password123';
      const user = new User({
        username: 'testuser',
        email: 'test@example.com',
        password,
        firstName: 'Test',
        lastName: 'User'
      });

      await user.save();

      expect(user.password).not.toBe(password);
      expect(user.password.length).toBeGreaterThan(password.length);

      // Verify the password can be compared
      const isMatch = await bcrypt.compare(password, user.password);
      expect(isMatch).toBe(true);
    });

    test('should require username', async() => {
      const user = new User({
        email: 'test@example.com',
        password: 'password123',
        firstName: 'Test',
        lastName: 'User'
      });

      let error;
      try {
        await user.save();
      } catch (err) {
        error = err;
      }

      expect(error).toBeDefined();
      expect(error.errors.username).toBeDefined();
    });

    test('should require email', async() => {
      const user = new User({
        username: 'testuser',
        password: 'password123',
        firstName: 'Test',
        lastName: 'User'
      });

      let error;
      try {
        await user.save();
      } catch (err) {
        error = err;
      }

      expect(error).toBeDefined();
      expect(error.errors.email).toBeDefined();
    });

    test('should require password', async() => {
      const user = new User({
        username: 'testuser',
        email: 'test@example.com',
        firstName: 'Test',
        lastName: 'User'
      });

      let error;
      try {
        await user.save();
      } catch (err) {
        error = err;
      }

      expect(error).toBeDefined();
      expect(error.errors.password).toBeDefined();
    });

    test('should enforce unique email', async() => {
      const userData1 = {
        username: 'testuser1',
        email: 'test@example.com',
        password: 'password123',
        firstName: 'Test',
        lastName: 'User'
      };

      const userData2 = {
        username: 'testuser2',
        email: 'test@example.com', // Same email
        password: 'password123',
        firstName: 'Test',
        lastName: 'User'
      };

      const user1 = new User(userData1);
      await user1.save();

      const user2 = new User(userData2);
      let error;
      try {
        await user2.save();
      } catch (err) {
        error = err;
      }

      expect(error).toBeDefined();
      expect(error.code).toBe(11000); // MongoDB duplicate key error
    });

    test('should enforce unique username', async() => {
      const userData1 = {
        username: 'testuser',
        email: 'test1@example.com',
        password: 'password123',
        firstName: 'Test',
        lastName: 'User'
      };

      const userData2 = {
        username: 'testuser', // Same username
        email: 'test2@example.com',
        password: 'password123',
        firstName: 'Test',
        lastName: 'User'
      };

      const user1 = new User(userData1);
      await user1.save();

      const user2 = new User(userData2);
      let error;
      try {
        await user2.save();
      } catch (err) {
        error = err;
      }

      expect(error).toBeDefined();
      expect(error.code).toBe(11000); // MongoDB duplicate key error
    });

    test('should validate email format', async() => {
      const user = new User({
        username: 'testuser',
        email: 'invalid-email',
        password: 'password123',
        firstName: 'Test',
        lastName: 'User'
      });

      let error;
      try {
        await user.save();
      } catch (err) {
        error = err;
      }

      expect(error).toBeDefined();
      expect(error.errors.email).toBeDefined();
    });

    test('should validate password minimum length', async() => {
      const user = new User({
        username: 'testuser',
        email: 'test@example.com',
        password: '123', // Too short
        firstName: 'Test',
        lastName: 'User'
      });

      let error;
      try {
        await user.save();
      } catch (err) {
        error = err;
      }

      expect(error).toBeDefined();
      expect(error.errors.password).toBeDefined();
    });
  });

  describe('User Methods', () => {
    let user;

    beforeEach(async() => {
      user = new User({
        username: 'testuser',
        email: 'test@example.com',
        password: 'password123',
        firstName: 'Test',
        lastName: 'User'
      });
      await user.save();
    });

    test('should compare password correctly', async() => {
      const isMatch = await user.comparePassword('password123');
      expect(isMatch).toBe(true);

      const isNotMatch = await user.comparePassword('wrongpassword');
      expect(isNotMatch).toBe(false);
    });

    test('should generate full name', () => {
      expect(user.fullName).toBe('Test User');
    });

    test('should return user object without password', () => {
      const userObject = user.toObject();
      expect(userObject).not.toHaveProperty('password');
      expect(userObject).toHaveProperty('username');
      expect(userObject).toHaveProperty('email');
    });
  });

  describe('User Updates', () => {
    let user;

    beforeEach(async() => {
      user = new User({
        username: 'testuser',
        email: 'test@example.com',
        password: 'password123',
        firstName: 'Test',
        lastName: 'User'
      });
      await user.save();
    });

    test('should update user profile', async() => {
      user.firstName = 'Updated';
      user.lastName = 'Name';
      await user.save();

      const updatedUser = await User.findById(user._id);
      expect(updatedUser.firstName).toBe('Updated');
      expect(updatedUser.lastName).toBe('Name');
    });

    test('should update lastLogin timestamp', async() => {
      const originalLastLogin = user.lastLogin;

      user.lastLogin = new Date();
      await user.save();

      expect(user.lastLogin).not.toEqual(originalLastLogin);
    });

    test('should not hash password on non-password updates', async() => {
      const originalPassword = user.password;

      user.firstName = 'Updated';
      await user.save();

      expect(user.password).toBe(originalPassword);
    });

    test('should hash new password on password update', async() => {
      const originalPassword = user.password;

      user.password = 'newpassword123';
      await user.save();

      expect(user.password).not.toBe(originalPassword);
      expect(user.password).not.toBe('newpassword123');

      const isMatch = await user.comparePassword('newpassword123');
      expect(isMatch).toBe(true);
    });
  });
});
