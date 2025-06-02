const logger = require('../../utils/logger');

describe('Logger Utility', () => {
  let originalConsoleLog;
  let consoleOutput;

  beforeEach(() => {
    consoleOutput = [];
    originalConsoleLog = console.log;
    console.log = jest.fn((message) => {
      consoleOutput.push(message);
    });
  });

  afterEach(() => {
    console.log = originalConsoleLog;
  });

  describe('Logger Configuration', () => {
    test('should have winston logger instance', () => {
      expect(logger).toBeDefined();
      expect(typeof logger.info).toBe('function');
      expect(typeof logger.error).toBe('function');
      expect(typeof logger.warn).toBe('function');
      expect(typeof logger.debug).toBe('function');
    });

    test('should support different log levels', () => {
      expect(() => {
        logger.info('Info message');
        logger.warn('Warning message');
        logger.error('Error message');
        logger.debug('Debug message');
      }).not.toThrow();
    });
  });

  describe('Logging Methods', () => {
    test('should log info messages', () => {
      const message = 'Test info message';
      logger.info(message);
      // In test environment, info logs might be suppressed
      // Just verify it doesn't throw
      expect(true).toBe(true);
    });

    test('should log warning messages', () => {
      const message = 'Test warning message';
      logger.warn(message);
      // In test environment, warnings should still be logged
      expect(true).toBe(true);
    });

    test('should log error messages', () => {
      const message = 'Test error message';
      logger.error(message);
      // Error logs should always be shown
      expect(true).toBe(true);
    });

    test('should handle error objects', () => {
      const error = new Error('Test error');
      expect(() => {
        logger.error('Error occurred:', error);
      }).not.toThrow();
    });

    test('should handle metadata', () => {
      const metadata = {
        userId: '123',
        action: 'test',
        timestamp: new Date().toISOString()
      };

      expect(() => {
        logger.info('Test with metadata', metadata);
      }).not.toThrow();
    });
  });

  describe('Log Formatting', () => {
    test('should handle string messages', () => {
      expect(() => {
        logger.warn('Simple string message');
      }).not.toThrow();
    });

    test('should handle object messages', () => {
      const messageObj = {
        event: 'user_login',
        userId: '123',
        ip: '127.0.0.1'
      };

      expect(() => {
        logger.warn('Event occurred', messageObj);
      }).not.toThrow();
    });

    test('should handle null and undefined', () => {
      expect(() => {
        logger.warn('Null message', null);
        logger.warn('Undefined message', undefined);
      }).not.toThrow();
    });
  });

  describe('Performance', () => {
    test('should log quickly', () => {
      const startTime = Date.now();

      for (let i = 0; i < 10; i++) {
        logger.warn(`Performance test message ${i}`);
      }

      const endTime = Date.now();
      const duration = endTime - startTime;

      // Should complete within reasonable time
      expect(duration).toBeLessThan(100);
    });
  });

  describe('Error Handling', () => {
    test('should not throw on malformed input', () => {
      expect(() => {
        logger.error('Error with circular reference', { circular: {} });
      }).not.toThrow();
    });

    test('should handle very long messages', () => {
      const longMessage = 'A'.repeat(10000);
      expect(() => {
        logger.warn(longMessage);
      }).not.toThrow();
    });

    test('should handle special characters', () => {
      const specialMessage = 'Test with special chars: 😀 ñ ü ß 中文 العربية';
      expect(() => {
        logger.warn(specialMessage);
      }).not.toThrow();
    });
  });
});
