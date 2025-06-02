const express = require('express');
const path = require('path');
const fs = require('fs');
const { uploadMiddleware, handleUploadError, fileUtils } = require('../utils/upload');
const authService = require('../utils/auth');
const logger = require('../utils/logger');
const config = require('../config');

const router = express.Router();

/**
 * @swagger
 * tags:
 *   name: Upload
 *   description: File upload endpoints
 */

/**
 * @swagger
 * /upload/single:
 *   post:
 *     summary: Upload a single file
 *     tags: [Upload]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               file:
 *                 type: string
 *                 format: binary
 *               description:
 *                 type: string
 *     responses:
 *       200:
 *         description: File uploaded successfully
 *       400:
 *         description: Upload error
 *       401:
 *         description: Authentication required
 */
router.post('/single',
  authService.authenticate(),
  uploadMiddleware.single('file'),
  handleUploadError,
  async(req, res) => {
    try {
      if (!req.file) {
        return res.status(400).json({
          error: 'No file uploaded',
          message: 'Please select a file to upload',
          timestamp: new Date().toISOString()
        });
      }

      const fileInfo = fileUtils.getFileInfo(req.file);

      logger.info(`File uploaded successfully by user ${req.user.userId}:`, {
        filename: fileInfo.filename,
        originalName: fileInfo.originalName,
        size: fileInfo.size,
        mimetype: fileInfo.mimetype
      });

      res.json({
        message: 'File uploaded successfully',
        file: {
          ...fileInfo,
          sizeFormatted: fileUtils.formatFileSize(fileInfo.size),
          uploadedBy: req.user.userId,
          uploadedAt: new Date().toISOString()
        },
        metadata: {
          description: req.body.description || null,
          tags: req.body.tags ? req.body.tags.split(',').map(tag => tag.trim()) : []
        },
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      logger.error('File upload error:', error);
      res.status(500).json({
        error: 'Upload failed',
        message: 'An error occurred during file upload',
        timestamp: new Date().toISOString()
      });
    }
  }
);

/**
 * @swagger
 * /upload/multiple:
 *   post:
 *     summary: Upload multiple files
 *     tags: [Upload]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               files:
 *                 type: array
 *                 items:
 *                   type: string
 *                   format: binary
 *     responses:
 *       200:
 *         description: Files uploaded successfully
 *       400:
 *         description: Upload error
 *       401:
 *         description: Authentication required
 */
router.post('/multiple',
  authService.authenticate(),
  uploadMiddleware.array('files', 5),
  handleUploadError,
  async(req, res) => {
    try {
      if (!req.files || req.files.length === 0) {
        return res.status(400).json({
          error: 'No files uploaded',
          message: 'Please select files to upload',
          timestamp: new Date().toISOString()
        });
      }

      const uploadedFiles = req.files.map(file => {
        const fileInfo = fileUtils.getFileInfo(file);
        return {
          ...fileInfo,
          sizeFormatted: fileUtils.formatFileSize(fileInfo.size)
        };
      });

      logger.info(`Multiple files uploaded successfully by user ${req.user.userId}:`, {
        count: uploadedFiles.length,
        totalSize: uploadedFiles.reduce((sum, file) => sum + file.size, 0),
        files: uploadedFiles.map(f => f.filename)
      });

      res.json({
        message: `${uploadedFiles.length} files uploaded successfully`,
        files: uploadedFiles.map(file => ({
          ...file,
          uploadedBy: req.user.userId,
          uploadedAt: new Date().toISOString()
        })),
        summary: {
          totalFiles: uploadedFiles.length,
          totalSize: fileUtils.formatFileSize(uploadedFiles.reduce((sum, file) => sum + file.size, 0))
        },
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      logger.error('Multiple file upload error:', error);
      res.status(500).json({
        error: 'Upload failed',
        message: 'An error occurred during file upload',
        timestamp: new Date().toISOString()
      });
    }
  }
);

/**
 * @swagger
 * /upload/avatar:
 *   post:
 *     summary: Upload user avatar image
 *     tags: [Upload]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               avatar:
 *                 type: string
 *                 format: binary
 *     responses:
 *       200:
 *         description: Avatar uploaded successfully
 *       400:
 *         description: Upload error
 *       401:
 *         description: Authentication required
 */
router.post('/avatar',
  authService.authenticate(),
  uploadMiddleware.single('avatar'),
  handleUploadError,
  async(req, res) => {
    try {
      if (!req.file) {
        return res.status(400).json({
          error: 'No avatar file uploaded',
          message: 'Please select an image file',
          timestamp: new Date().toISOString()
        });
      }

      // Validate that it's an image
      if (!req.file.mimetype.startsWith('image/')) {
        // Delete the uploaded file since it's not valid
        fileUtils.deleteFile(req.file.path);
        return res.status(400).json({
          error: 'Invalid file type',
          message: 'Avatar must be an image file',
          timestamp: new Date().toISOString()
        });
      }

      const fileInfo = fileUtils.getFileInfo(req.file);

      // Here you could update the user's avatar URL in the database
      // const User = require('../models/User');
      // const user = await User.findById(req.user.userId);
      // user.profile.avatar = fileInfo.url;
      // await user.save();

      logger.info(`Avatar uploaded successfully by user ${req.user.userId}:`, {
        filename: fileInfo.filename,
        size: fileInfo.size
      });

      res.json({
        message: 'Avatar uploaded successfully',
        avatar: {
          ...fileInfo,
          sizeFormatted: fileUtils.formatFileSize(fileInfo.size),
          uploadedBy: req.user.userId,
          uploadedAt: new Date().toISOString()
        },
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      logger.error('Avatar upload error:', error);
      res.status(500).json({
        error: 'Avatar upload failed',
        message: 'An error occurred during avatar upload',
        timestamp: new Date().toISOString()
      });
    }
  }
);

/**
 * @swagger
 * /upload/files/{filename}:
 *   get:
 *     summary: Download/view uploaded file
 *     tags: [Upload]
 *     parameters:
 *       - in: path
 *         name: filename
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: File content
 *       404:
 *         description: File not found
 */
router.get('/files/:filename', (req, res) => {
  try {
    const { filename } = req.params;

    // Security: prevent directory traversal
    if (filename.includes('..') || filename.includes('/') || filename.includes('\\')) {
      return res.status(400).json({
        error: 'Invalid filename',
        message: 'Filename contains invalid characters',
        timestamp: new Date().toISOString()
      });
    }

    // Search for file in upload directories
    const uploadDir = path.join(process.cwd(), config.upload.uploadPath);
    const possiblePaths = [
      path.join(uploadDir, 'image', filename),
      path.join(uploadDir, 'application', filename),
      path.join(uploadDir, 'text', filename),
      path.join(uploadDir, filename)
    ];

    let filePath = null;
    for (const possiblePath of possiblePaths) {
      if (fs.existsSync(possiblePath)) {
        filePath = possiblePath;
        break;
      }
    }

    if (!filePath) {
      return res.status(404).json({
        error: 'File not found',
        message: `File '${filename}' does not exist`,
        timestamp: new Date().toISOString()
      });
    }

    // Get file stats
    const stats = fs.statSync(filePath);
    const fileExtension = path.extname(filename).toLowerCase();

    // Set appropriate headers
    res.setHeader('Content-Length', stats.size);

    // Set content type based on file extension
    const contentTypes = {
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.png': 'image/png',
      '.gif': 'image/gif',
      '.pdf': 'application/pdf',
      '.txt': 'text/plain',
      '.json': 'application/json'
    };

    const contentType = contentTypes[fileExtension] || 'application/octet-stream';
    res.setHeader('Content-Type', contentType);

    // Log file access
    logger.debug(`File accessed: ${filename}`, {
      size: stats.size,
      contentType,
      ip: req.ip
    });

    // Stream file to response
    const fileStream = fs.createReadStream(filePath);
    fileStream.pipe(res);

    fileStream.on('error', (error) => {
      logger.error(`Error streaming file ${filename}:`, error);
      if (!res.headersSent) {
        res.status(500).json({
          error: 'File streaming error',
          message: 'An error occurred while serving the file',
          timestamp: new Date().toISOString()
        });
      }
    });
  } catch (error) {
    logger.error('File access error:', error);
    res.status(500).json({
      error: 'File access failed',
      message: 'An error occurred while accessing the file',
      timestamp: new Date().toISOString()
    });
  }
});

/**
 * @swagger
 * /upload/info:
 *   get:
 *     summary: Get upload configuration and limits
 *     tags: [Upload]
 *     responses:
 *       200:
 *         description: Upload configuration
 */
router.get('/info', (req, res) => {
  res.json({
    limits: {
      maxFileSize: config.upload.maxFileSize,
      maxFileSizeFormatted: fileUtils.formatFileSize(config.upload.maxFileSize),
      maxFiles: 5,
      maxFields: 10
    },
    allowedTypes: [
      'image/jpeg',
      'image/png',
      'image/gif',
      'image/webp',
      'application/pdf',
      'text/plain',
      'text/csv',
      'application/json',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.ms-excel',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    ],
    uploadPath: config.upload.uploadPath,
    timestamp: new Date().toISOString()
  });
});

module.exports = router;
