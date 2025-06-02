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

// Console transport configuration
const consoleTransport = new winston.transports.Console({
  level: config.isTest ? 'silent' : 'info', // Completely silent in test environment
  format: customFormat,
  silent: config.isTest // Always silent in test environment
});

// File transport for non-test environments only
const transports = [consoleTransport];

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
  level: config.isTest ? 'silent' : config.logLevel, // Silent level in test
  format: customFormat,
  transports,
  // Don't exit on handled exceptions in test environment
  exitOnError: !config.isTest,
  // Completely silent in test environment
  silent: config.isTest
});

module.exports = logger;
