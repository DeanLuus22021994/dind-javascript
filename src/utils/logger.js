const winston = require('winston');
const config = require('../config');

// Custom format that includes timestamp and level
const customFormat = winston.format.combine(
  winston.format.timestamp(),
  winston.format.errors({ stack: true }),
  winston.format.json(),
  winston.format.printf(({ level, message, timestamp, stack, ...meta }) => {
    let log = `${timestamp} '${level}': '${message}'`;

    // Add stack trace for errors
    if (stack) {
      log += `\n${stack}`;
    }

    // Add metadata if present
    if (Object.keys(meta).length > 0) {
      log += ` ${JSON.stringify(meta)}`;
    }

    return log;
  })
);

// Console transport for all environments
const transports = [
  new winston.transports.Console({
    level: config.isTest ? 'warn' : 'info', // Reduce logging in test environment to warn and above
    format: customFormat,
    silent: config.isTest && process.env.JEST_SILENT === 'true' // Allow silencing in tests
  })
];

// File transport for non-test environments
if (!config.isTest) {
  transports.push(
    new winston.transports.File({
      filename: 'logs/error.log',
      level: 'error',
      format: customFormat
    }),
    new winston.transports.File({
      filename: 'logs/combined.log',
      format: customFormat
    })
  );
}

const logger = winston.createLogger({
  level: config.isTest ? 'warn' : config.logLevel, // Only log warnings and errors in test
  format: customFormat,
  transports,
  // Don't exit on handled exceptions in test environment
  exitOnError: !config.isTest
});

module.exports = logger;
