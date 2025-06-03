module.exports = {
  testEnvironment: 'node',
  setupFilesAfterEnv: ['<rootDir>/jest.setup.js'],
  testMatch: [
    '**/__tests__/**/*.js',
    '**/src/tests/**/*.test.js', // Only match .test.js files in src/tests
    '**/?(*.)+(spec|test).js'
  ],
  testPathIgnorePatterns: [
    '/node_modules/',
    '/src/tests/test-setup.js' // Updated to ignore the renamed file
  ],
  collectCoverageFrom: [
    'src/**/*.js',
    '!src/tests/**',
    '!src/**/*.test.js',
    '!src/tests/test-setup.js' // Updated to ignore the renamed file
  ],
  coverageDirectory: 'coverage',
  coverageReporters: ['text', 'lcov', 'html'],
  verbose: false,
  silent: false,
  setupFilesAfterEnv: ['<rootDir>/jest.setup.js']
};
