const { MongoMemoryServer } = require('mongodb-memory-server');
const mongoose = require('mongoose');

let mongod;

// Setup test database
// Setup test database
global.beforeAll(async() => {
  if (!mongod) {
    mongod = await MongoMemoryServer.create();
    const uri = mongod.getUri();

    // Override database URL for tests
    process.env.NODE_ENV = 'test';
    process.env.DATABASE_URL = uri;

    await mongoose.connect(uri, {
      useNewUrlParser: true,
      useUnifiedTopology: true
    });
  }
});

// Cleanup after tests
// Cleanup after tests
global.afterAll(async() => {
  if (mongod) {
    await mongoose.connection.close();
    await mongod.stop();
  }
});

// Clean up between tests
// Clean up between tests
global.afterEach(async() => {
  if (mongoose.connection.readyState === 1) {
    const collections = mongoose.connection.collections;
    for (const key in collections) {
      await collections[key].deleteMany({});
    }
  }
});

// Increase timeout for async operations
jest.setTimeout(30000);
