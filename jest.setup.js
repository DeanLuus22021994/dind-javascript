// Suppress console logs during tests
const originalConsoleError = console.error;
const originalConsoleWarn = console.warn;
const originalConsoleLog = console.log;

beforeAll(() => {
  // Only suppress console in test environment
  if (process.env.NODE_ENV === 'test') {
    console.error = jest.fn();
    console.warn = jest.fn();
    console.log = jest.fn();
  }
});

afterAll(() => {
  // Restore original console methods
  console.error = originalConsoleError;
  console.warn = originalConsoleWarn;
  console.log = originalConsoleLog;
});

// Increase timeout for database operations
jest.setTimeout(30000);

// Setup test database and cleanup
require('./src/tests/test-setup.js');
