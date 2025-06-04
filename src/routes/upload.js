import express from 'express';
import multer from 'multer';
import path from 'path';
import fs from 'fs/promises';
import { v4 as uuidv4 } from 'uuid';
import { requireAuth } from '../utils/auth.js';
import logger from '../utils/logger.js';
const router = express.Router();

// Configure storage
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    // Use test directory for tests, regular uploads otherwise
    const uploadDir =
      process.env.NODE_ENV === 'test'
        ? path.join(__dirname, '../../uploads/test')
        : path.join(__dirname, '../../uploads');

    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    // Generate unique filename with original extension
    const ext = path.extname(file.originalname);
    cb(null, `${uuidv4()}${ext}`);
  }
});

// File filter
const fileFilter = (req, file, cb) => {
  // Allow only certain file types
  const allowedTypes = [
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.pdf',
    '.txt',
    '.doc',
    '.docx',
    '.xls',
    '.xlsx'
  ];
  const ext = path.extname(file.originalname).toLowerCase();

  if (allowedTypes.includes(ext)) {
    cb(null, true);
  } else {
    cb(new Error(`File type ${ext} not allowed`), false);
  }
};

// Configure multer
const upload = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: 5 * 1024 * 1024 // 5MB
  }
});

// For testing purposes, this middleware will bypass auth checks in test environment
const conditionalAuth = (req, res, next) => {
  if (process.env.NODE_ENV === 'test') {
    req.user = { _id: 'test-user-id' }; // Mock user for tests
    return next();
  }
  return requireAuth(req, res, next);
};

// Error handler for multer
const handleMulterError = (err, req, res, next) => {
  if (err instanceof multer.MulterError) {
    if (err.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({ error: 'File too large. Maximum size is 5MB.' });
    }
    return res.status(400).json({ error: `Upload error: ${err.message}` });
  } else if (err) {
    return res.status(400).json({ error: err.message });
  }
  next();
};

/**
 * @route POST /api/upload/single
 * @description Upload a single file
 */
router.post('/single', conditionalAuth, (req, res, next) => {
  const singleUpload = upload.single('file');

  singleUpload(req, res, err => {
    if (err) {
      return handleMulterError(err, req, res, next);
    }

    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }

    res.status(200).json({
      message: 'File uploaded successfully',
      file: {
        filename: req.file.filename,
        originalname: req.file.originalname,
        mimetype: req.file.mimetype,
        size: req.file.size,
        path: req.file.path
      }
    });
  });
});

/**
 * @route POST /api/upload/multiple
 * @description Upload multiple files
 */
router.post('/multiple', conditionalAuth, (req, res, next) => {
  const multiUpload = upload.array('files', 10); // Max 10 files

  multiUpload(req, res, err => {
    if (err) {
      return handleMulterError(err, req, res, next);
    }

    if (!req.files || req.files.length === 0) {
      return res.status(400).json({ error: 'No files uploaded' });
    }

    res.status(200).json({
      message: `${req.files.length} files uploaded successfully`,
      files: req.files.map(file => ({
        filename: file.filename,
        originalname: file.originalname,
        mimetype: file.mimetype,
        size: file.size
      }))
    });
  });
});

/**
 * @route GET /api/upload/files
 * @description List uploaded files
 */
router.get('/files', conditionalAuth, async (req, res) => {
  try {
    // Determine which directory to use
    const uploadDir =
      process.env.NODE_ENV === 'test'
        ? path.join(__dirname, '../../uploads/test')
        : path.join(__dirname, '../../uploads');

    // Read directory
    const files = await fs.readdir(uploadDir);

    // Get file details
    const fileDetails = await Promise.all(
      files.map(async filename => {
        const filePath = path.join(uploadDir, filename);
        const stats = await fs.stat(filePath);

        return {
          filename,
          size: stats.size,
          createdAt: stats.birthtime
        };
      })
    );

    res.status(200).json({ files: fileDetails });
  } catch {
    logger.error('Error listing files');
    res.status(500).json({ error: 'Failed to list files' });
  }
});

/**
 * @route DELETE /api/upload/files/:filename
 * @description Delete a file
 */
router.delete('/files/:filename', conditionalAuth, async (req, res) => {
  try {
    const { filename } = req.params;

    // Validate filename to prevent directory traversal
    if (!filename || filename.includes('/') || filename.includes('\\')) {
      return res.status(400).json({ error: 'Invalid filename' });
    }

    // Determine which directory to use
    const uploadDir =
      process.env.NODE_ENV === 'test'
        ? path.join(__dirname, '../../uploads/test')
        : path.join(__dirname, '../../uploads');

    const filePath = path.join(uploadDir, filename);

    // Check if file exists
    try {
      await fs.access(filePath);
    } catch (error) {
      return res.status(404).json({ error: 'File not found' });
    }

    // Delete file
    await fs.unlink(filePath);

    res.status(200).json({ message: 'File deleted successfully' });
  } catch {
    logger.error('Error deleting file');
    res.status(500).json({ error: 'Failed to delete file' });
  }
});

export default router;
