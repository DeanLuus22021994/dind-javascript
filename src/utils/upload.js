const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');
const config = require('../config');
const logger = require('./logger');

// Ensure upload directory exists
const uploadDir = path.join(process.cwd(), config.upload.uploadPath);
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

// Storage configuration
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    // Create subdirectories based on file type
    const fileType = file.mimetype.split('/')[0];
    const subDir = path.join(uploadDir, fileType);

    if (!fs.existsSync(subDir)) {
      fs.mkdirSync(subDir, { recursive: true });
    }

    cb(null, subDir);
  },
  filename: (req, file, cb) => {
    // Generate unique filename
    const uniqueSuffix = `${Date.now()}-${uuidv4()}`;
    const extension = path.extname(file.originalname);
    cb(null, `${file.fieldname}-${uniqueSuffix}${extension}`);
  }
});

// File filter
const fileFilter = (req, file, cb) => {
  // Define allowed file types
  const allowedTypes = {
    'image/jpeg': '.jpg',
    'image/jpg': '.jpg',
    'image/png': '.png',
    'image/gif': '.gif',
    'image/webp': '.webp',
    'application/pdf': '.pdf',
    'text/plain': '.txt',
    'text/csv': '.csv',
    'application/json': '.json',
    'application/msword': '.doc',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document': '.docx',
    'application/vnd.ms-excel': '.xls',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': '.xlsx'
  };

  if (allowedTypes[file.mimetype]) {
    cb(null, true);
  } else {
    cb(new Error(`File type ${file.mimetype} is not allowed`), false);
  }
};

// Multer configuration
const upload = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: config.upload.maxFileSize, // Max file size from config
    files: 5, // Max 5 files per request
    fields: 10 // Max 10 non-file fields
  }
});

// File upload middleware functions
const uploadMiddleware = {
  // Single file upload
  single: (fieldName) => upload.single(fieldName),

  // Multiple files upload (same field)
  array: (fieldName, maxCount = 5) => upload.array(fieldName, maxCount),

  // Multiple files upload (different fields)
  fields: (fields) => upload.fields(fields),

  // Any files
  any: () => upload.any(),

  // No files (just parse form data)
  none: () => upload.none()
};

// Error handling middleware
const handleUploadError = (error, req, res, next) => {
  if (error instanceof multer.MulterError) {
    logger.warn('File upload error:', error);

    let message = 'File upload failed';
    const statusCode = 400;

    switch (error.code) {
      case 'LIMIT_FILE_SIZE':
        message = `File too large. Maximum size is ${config.upload.maxFileSize / (1024 * 1024)}MB`;
        break;
      case 'LIMIT_FILE_COUNT':
        message = 'Too many files';
        break;
      case 'LIMIT_UNEXPECTED_FILE':
        message = 'Unexpected file field';
        break;
      case 'LIMIT_PART_COUNT':
        message = 'Too many parts';
        break;
      case 'LIMIT_FIELD_KEY':
        message = 'Field name too long';
        break;
      case 'LIMIT_FIELD_VALUE':
        message = 'Field value too long';
        break;
      case 'LIMIT_FIELD_COUNT':
        message = 'Too many fields';
        break;
      default:
        message = error.message;
    }

    return res.status(statusCode).json({
      error: 'Upload Error',
      message,
      code: error.code,
      timestamp: new Date().toISOString()
    });
  }

  if (error) {
    logger.error('Unexpected upload error:', error);
    return res.status(400).json({
      error: 'Upload Error',
      message: error.message,
      timestamp: new Date().toISOString()
    });
  }

  next();
};

// File utilities
const fileUtils = {
  // Get file info
  getFileInfo: (file) => ({
    filename: file.filename,
    originalName: file.originalname,
    mimetype: file.mimetype,
    size: file.size,
    path: file.path,
    destination: file.destination,
    url: `/uploads/${path.relative(uploadDir, file.path).replace(/\\/g, '/')}`
  }),

  // Delete file
  deleteFile: (filePath) => {
    try {
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
        logger.debug(`File deleted: ${filePath}`);
        return true;
      }
      return false;
    } catch (error) {
      logger.error(`Error deleting file ${filePath}:`, error);
      return false;
    }
  },
  // Get file size in human readable format
  formatFileSize: (bytes) => {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  },

  // Validate image dimensions (requires sharp package)
  validateImageDimensions: async function (filePath, maxWidth = 2000, maxHeight = 2000) {
    try {
      // To enable validation, uncomment the following lines and install 'sharp':
      // const sharp = require('sharp');
      // const metadata = await sharp(filePath).metadata();
      // return metadata.width <= maxWidth && metadata.height <= maxHeight;

      // For now, just return true
      return true;
    } catch (error) {
      logger.error('Error validating image dimensions:', error);
      return false;
    }
  }
};

module.exports = {
  uploadMiddleware,
  handleUploadError,
  fileUtils,
  uploadDir
};
