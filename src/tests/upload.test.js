const request = require('supertest');
const express = require('express');
const path = require('path');
const fs = require('fs').promises;

describe('File Upload Routes', () => {
  let app;
  const uploadDir = path.join(__dirname, '../../uploads/test');

  beforeAll(async() => {
    app = express(); // Import and use upload routes
    const uploadRoutes = require('../routes/upload');
    app.use('/api/upload', uploadRoutes);

    // Create test upload directory
    try {
      await fs.mkdir(uploadDir, { recursive: true });
    } catch (error) {
      // Directory might already exist
    }
  });

  afterAll(async() => {
    // Clean up test uploads
    try {
      const files = await fs.readdir(uploadDir);
      await Promise.all(files.map(file => fs.unlink(path.join(uploadDir, file))));
      await fs.rmdir(uploadDir);
    } catch (error) {
      // Directory might not exist
    }
  });

  describe('POST /api/upload/single', () => {
    test('should upload a single file successfully', async() => {
      // Create a test file buffer
      const testContent = 'This is a test file content';

      const response = await request(app)
        .post('/api/upload/single')
        .attach('file', Buffer.from(testContent), 'test.txt')
        .expect(200);

      expect(response.body).toHaveProperty('message');
      expect(response.body).toHaveProperty('file');
      expect(response.body.file).toHaveProperty('filename');
      expect(response.body.file).toHaveProperty('originalname', 'test.txt');
      expect(response.body.file).toHaveProperty('size');
    });

    test('should return error when no file is provided', async() => {
      const response = await request(app)
        .post('/api/upload/single')
        .expect(400);

      expect(response.body).toHaveProperty('error');
    });

    test('should return error for unsupported file type', async() => {
      const testContent = 'This is a test file content';

      const response = await request(app)
        .post('/api/upload/single')
        .attach('file', Buffer.from(testContent), 'test.exe')
        .expect(400);

      expect(response.body).toHaveProperty('error');
    });

    test('should return error for file too large', async() => {
      // Create a large buffer (assuming 5MB limit)
      const largeContent = 'x'.repeat(6 * 1024 * 1024); // 6MB

      const response = await request(app)
        .post('/api/upload/single')
        .attach('file', Buffer.from(largeContent), 'large.txt')
        .expect(400);

      expect(response.body).toHaveProperty('error');
    });
  });

  describe('POST /api/upload/multiple', () => {
    test('should upload multiple files successfully', async() => {
      const testContent1 = 'This is test file 1';
      const testContent2 = 'This is test file 2';

      const response = await request(app)
        .post('/api/upload/multiple')
        .attach('files', Buffer.from(testContent1), 'test1.txt')
        .attach('files', Buffer.from(testContent2), 'test2.txt')
        .expect(200);

      expect(response.body).toHaveProperty('message');
      expect(response.body).toHaveProperty('files');
      expect(Array.isArray(response.body.files)).toBe(true);
      expect(response.body.files).toHaveLength(2);
    });

    test('should return error when no files are provided', async() => {
      const response = await request(app)
        .post('/api/upload/multiple')
        .expect(400);

      expect(response.body).toHaveProperty('error');
    });

    test('should return error when too many files are uploaded', async() => {
      const files = [];
      // Create more than 10 files (assuming 10 is the limit)
      for (let i = 0; i < 12; i++) {
        files.push({
          content: `Test file ${i}`,
          name: `test${i}.txt`
        });
      }

      let requestChain = request(app).post('/api/upload/multiple');

      files.forEach(file => {
        requestChain = requestChain.attach('files', Buffer.from(file.content), file.name);
      });

      const response = await requestChain.expect(400);

      expect(response.body).toHaveProperty('error');
    });
  });

  describe('GET /api/upload/files', () => {
    test('should list uploaded files', async() => {
      // First upload a file
      const testContent = 'This is a test file content';

      await request(app)
        .post('/api/upload/single')
        .attach('file', Buffer.from(testContent), 'test-list.txt');

      // Then list files
      const response = await request(app)
        .get('/api/upload/files')
        .expect(200);

      expect(response.body).toHaveProperty('files');
      expect(Array.isArray(response.body.files)).toBe(true);
    });
  });

  describe('DELETE /api/upload/files/:filename', () => {
    test('should delete an uploaded file', async() => {
      // First upload a file
      const testContent = 'This is a test file content';

      const uploadResponse = await request(app)
        .post('/api/upload/single')
        .attach('file', Buffer.from(testContent), 'test-delete.txt');

      const filename = uploadResponse.body.file.filename;

      // Then delete it
      const response = await request(app)
        .delete(`/api/upload/files/${filename}`)
        .expect(200);

      expect(response.body).toHaveProperty('message');
    });

    test('should return error when trying to delete non-existent file', async() => {
      const response = await request(app)
        .delete('/api/upload/files/non-existent.txt')
        .expect(404);

      expect(response.body).toHaveProperty('error');
    });
  });
});
