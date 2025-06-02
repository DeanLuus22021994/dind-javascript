const { MongoMemoryServer } = require('mongodb-memory-server');
const mongoose = require('mongoose');
const path = require('path');
const fs = require('fs');

// Set test environment
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test-jwt-secret-key';

// Create uploads/test directory if it doesn't exist
const testUploadDir = path.join(__dirname, '../uploads/test');
if (!fs.existsSync(testUploadDir)) {
  fs.mkdirSync(testUploadDir, { recursive: true });
}

let mongoServer;

beforeAll(async() => {
  // Start in-memory MongoDB instance
  mongoServer = await MongoMemoryServer.create();
  const mongoUri = mongoServer.getUri();

  // Connect to the in-memory database
  await mongoose.connect(mongoUri);
});

afterAll(async() => {
  // Cleanup
  await mongoose.disconnect();
  await mongoServer.stop();

  // Clean up test upload directory
  try {
    if (fs.existsSync(testUploadDir)) {
      const files = fs.readdirSync(testUploadDir);
      files.forEach(file => {
        fs.unlinkSync(path.join(testUploadDir, file));
      });
      fs.rmdirSync(testUploadDir);
    }
  } catch (error) {
    // Ignore cleanup errors
  }
});

// Set longer timeout for database operations
jest.setTimeout(30000);
