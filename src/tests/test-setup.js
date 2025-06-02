const { MongoMemoryServer } = require('mongodb-memory-server');
const mongoose = require('mongoose');
const path = require('path');
const fs = require('fs');

let mongoServer;

// Global setup before all tests
beforeAll(async() => {
  // Start in-memory MongoDB instance
  mongoServer = await MongoMemoryServer.create();
  const mongoUri = mongoServer.getUri();

  // Connect to the in-memory database
  await mongoose.connect(mongoUri, {
    useNewUrlParser: true,
    useUnifiedTopology: true,
  });

  // Create test upload directory
  const testUploadDir = path.join(__dirname, '../uploads/test');
  if (!fs.existsSync(testUploadDir)) {
    fs.mkdirSync(testUploadDir, { recursive: true });
  }
});

// Global cleanup after all tests
afterAll(async() => {
  // Close database connection
  await mongoose.disconnect();

  // Stop in-memory MongoDB instance
  if (mongoServer) {
    await mongoServer.stop();
  }

  // Clean up test upload directory
  const testUploadDir = path.join(__dirname, '../uploads/test');
  try {
    if (fs.existsSync(testUploadDir)) {
      fs.rmSync(testUploadDir, { recursive: true, force: true });
    }
  } catch (error) {
    // Ignore cleanup errors
  }
});

// Set longer timeout for database operations
jest.setTimeout(30000);

module.exports = {
  mongoServer
};
