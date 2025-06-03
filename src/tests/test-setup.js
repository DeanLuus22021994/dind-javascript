import { MongoMemoryServer } from 'mongodb-memory-server';
import mongoose from 'mongoose';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

let mongoServer;

export default async function globalTestSetup() {
  // Start in-memory MongoDB instance
  mongoServer = await MongoMemoryServer.create();
  const mongoUri = mongoServer.getUri();

  // Connect to the in-memory database
  await mongoose.connect(mongoUri, {
    useNewUrlParser: true,
    useUnifiedTopology: true
  });

  // Create test upload directory
  const testUploadDir = path.join(__dirname, '../uploads/test');
  if (!fs.existsSync(testUploadDir)) {
    fs.mkdirSync(testUploadDir, { recursive: true });
  }

  // Register teardown
  if (typeof afterAll === 'function') {
    afterAll(async () => {
      await mongoose.disconnect();
      if (mongoServer) {
        await mongoServer.stop();
      }
      try {
        if (fs.existsSync(testUploadDir)) {
          fs.rmSync(testUploadDir, { recursive: true, force: true });
        }
      } catch (error) {
        // Ignore cleanup errors
      }
    });
  }
}
