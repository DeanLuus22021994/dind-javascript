// Modern Jest setup using ESM, top-level await, and async hooks
import { jest } from '@jest/globals';

const originalConsoleError = console.error;
const originalConsoleWarn = console.warn;
const originalConsoleLog = console.log;

beforeAll(() => {
  if (process.env.NODE_ENV === 'test') {
    console.error = jest.fn();
    console.warn = jest.fn();
    console.log = jest.fn();
  }
});

afterAll(() => {
  console.error = originalConsoleError;
  console.warn = originalConsoleWarn;
  console.log = originalConsoleLog;
});

// Increase timeout for database operations
jest.setTimeout(30000);

// Modern async/await test setup
const setupModule = await import('./src/tests/test-setup.js');
if (setupModule && typeof setupModule.default === 'function') {
  await setupModule.default();
}
