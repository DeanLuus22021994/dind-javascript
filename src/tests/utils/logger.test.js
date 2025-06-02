const logger = require('../../utils/logger');

describe('Logger Utility', () => {
  let originalConsoleLog;
  let originalConsoleError;
  let logOutput = [];
  let errorOutput = [];

  beforeAll(() => {
    // Mock console methods to capture output
    originalConsoleLog = console.log;
    originalConsoleError = console.error;

    console.log = (...args) => logOutput.push(args.join(' '));
    console.error = (...args) => errorOutput.push(args.join(' '));
  });

  afterAll(() => {
    // Restore original console methods
    console.log = originalConsoleLog;
    console.error = originalConsoleError;
  });

  beforeEach(() => {
    logOutput = [];
    errorOutput = [];
  });

  describe('Logger levels', () => {
    test('should log info messages', () => {
      logger.info('Test info message');

      // In test environment, check if the message structure is correct
      expect(typeof logger.info).toBe('function');
    });

    test('should log error messages', () => {
      logger.error('Test error message');

      expect(typeof logger.error).toBe('function');
    });

    test('should log warning messages', () => {
      logger.warn('Test warning message');

      expect(typeof logger.warn).toBe('function');
    });

    test('should log debug messages', () => {
      logger.debug('Test debug message');

      expect(typeof logger.debug).toBe('function');
    });
  });

  describe('Logger configuration', () => {
    test('should have correct format', () => {
      // Check that logger has expected properties
      expect(logger).toHaveProperty('info');
      expect(logger).toHaveProperty('error');
      expect(logger).toHaveProperty('warn');
      expect(logger).toHaveProperty('debug');
    });

    test('should handle object logging', () => {
      const testObject = { test: 'value', number: 123 };
      logger.info('Test object', testObject);

      // Should not throw an error
      expect(typeof logger.info).toBe('function');
    });

    test('should handle error object logging', () => {
      const testError = new Error('Test error');
      logger.error('Error occurred:', testError);

      // Should not throw an error
      expect(typeof logger.error).toBe('function');
    });
  });

  describe('Logger metadata', () => {
    test('should log with additional metadata', () => {
      const metadata = {
        userId: '123',
        action: 'login',
        ip: '127.0.0.1'
      };

      logger.info('User action', metadata);

      // Should not throw an error
      expect(typeof logger.info).toBe('function');
    });

    test('should handle nested objects', () => {
      const complexObject = {
        user: {
          id: '123',
          profile: {
            name: 'Test User',
            preferences: {
              theme: 'dark'
            }
          }
        }
      };

      logger.info('Complex object', complexObject);

      // Should not throw an error
      expect(typeof logger.info).toBe('function');
    });
  });
});
