import Bull from 'bull';
import config from '../config/index.js';
import logger from './logger.js';
import emailService from './email.js';

class JobQueue {
  constructor() {
    this.queues = new Map();
    this.isInitialized = false;
  }

  initialize() {
    if (!config.enableBackgroundJobs) {
      logger.info('Background jobs disabled by configuration');
      return;
    }

    if (!config.redis.url) {
      logger.warn('Redis not configured - background jobs disabled');
      return;
    }

    try {
      // Create different queues for different job types
      this.createQueue('email', {
        defaultJobOptions: {
          removeOnComplete: 10,
          removeOnFail: 5,
          attempts: 3,
          backoff: {
            type: 'exponential',
            delay: 2000
          }
        }
      });

      this.createQueue('notifications', {
        defaultJobOptions: {
          removeOnComplete: 20,
          removeOnFail: 10,
          attempts: 2,
          backoff: {
            type: 'fixed',
            delay: 5000
          }
        }
      });

      this.createQueue('analytics', {
        defaultJobOptions: {
          removeOnComplete: 50,
          removeOnFail: 20,
          attempts: 1
        }
      });

      this.createQueue('cleanup', {
        defaultJobOptions: {
          removeOnComplete: 5,
          removeOnFail: 5,
          attempts: 2
        }
      });

      this.setupJobProcessors();
      this.setupEventHandlers();

      this.isInitialized = true;
      logger.info('✅ Job queue system initialized');
    } catch (error) {
      logger.error('Failed to initialize job queue system:', error);
    }
  }

  createQueue(name, options = {}) {
    const queue = new Bull(name, {
      redis: {
        port: new URL(config.redis.url).port || 6379,
        host: new URL(config.redis.url).hostname,
        password: config.redis.password || undefined
      },
      settings: {
        stalledInterval: 30 * 1000,
        maxStalledCount: 1
      },
      ...options
    });

    this.queues.set(name, queue);
    logger.debug(`Queue '${name}' created`);
    return queue;
  }

  setupJobProcessors() {
    // Email queue processor
    const emailQueue = this.queues.get('email');
    if (emailQueue) {
      emailQueue.process('send-welcome', config.jobConcurrency, async job => {
        const { userEmail, userName } = job.data;
        logger.debug(`Processing welcome email job for ${userEmail}`);
        return emailService.sendWelcomeEmail(userEmail, userName);
      });

      emailQueue.process('send-reset', config.jobConcurrency, async job => {
        const { userEmail, resetToken, userName } = job.data;
        logger.debug(`Processing password reset email job for ${userEmail}`);
        return emailService.sendPasswordResetEmail(userEmail, resetToken, userName);
      });

      emailQueue.process('send-notification', config.jobConcurrency, async job => {
        const { userEmail, title, message, userName } = job.data;
        logger.debug(`Processing notification email job for ${userEmail}`);
        return emailService.sendNotificationEmail(userEmail, title, message, userName);
      });

      emailQueue.process('send-bulk', 1, async job => {
        const { recipients, subject, html } = job.data;
        logger.debug(`Processing bulk email job for ${recipients.length} recipients`);
        return emailService.sendBulkEmail(recipients, subject, html);
      });
    }

    // Notifications queue processor
    const notificationsQueue = this.queues.get('notifications');
    if (notificationsQueue) {
      notificationsQueue.process('push-notification', config.jobConcurrency, async job => {
        const { userId, title, message } = job.data;
        logger.debug(`Processing push notification job for user ${userId}`);

        // Here you would integrate with push notification service
        // For now, just log the notification
        logger.info(`Push notification: ${title} - ${message} (User: ${userId})`);
        return { success: true, userId, title, message };
      });

      notificationsQueue.process('websocket-broadcast', config.jobConcurrency, async job => {
        const { event, room } = job.data;
        logger.debug(`Processing WebSocket broadcast job: ${event}`);

        // Here you would integrate with WebSocket server
        // const websocketServer = require('./websocket');
        // websocketServer.sendToRoom(room, event, data);

        return { success: true, event, room };
      });
    }

    // Analytics queue processor
    const analyticsQueue = this.queues.get('analytics');
    if (analyticsQueue) {
      analyticsQueue.process('track-event', config.jobConcurrency * 2, async job => {
        const { event, userId, data, timestamp } = job.data;
        logger.debug(`Processing analytics event: ${event}`);

        // Here you would send data to analytics service
        logger.info(`Analytics: ${event}`, { userId, data, timestamp });
        return { success: true, event, userId };
      });

      analyticsQueue.process('generate-report', 1, async job => {
        const { reportType, filters, userId } = job.data;
        logger.debug(`Processing report generation: ${reportType}`);

        // Here you would generate the report
        logger.info(`Report generated: ${reportType}`, { filters, userId });
        return { success: true, reportType, generatedAt: new Date() };
      });
    }

    // Cleanup queue processor
    const cleanupQueue = this.queues.get('cleanup');
    if (cleanupQueue) {
      cleanupQueue.process('clean-logs', 1, async job => {
        const { olderThan } = job.data;
        logger.debug('Processing log cleanup job');

        // Here you would clean up old log files
        logger.info(`Log cleanup completed for files older than ${olderThan}`);
        return { success: true, cleanedAt: new Date() };
      });

      cleanupQueue.process('clean-uploads', 1, async job => {
        const { olderThan } = job.data;
        logger.debug('Processing upload cleanup job');

        // Here you would clean up old uploaded files
        logger.info(`Upload cleanup completed for files older than ${olderThan}`);
        return { success: true, cleanedAt: new Date() };
      });
    }
  }

  setupEventHandlers() {
    this.queues.forEach((queue, name) => {
      queue.on('completed', (job, result) => {
        logger.debug(`Job completed in queue '${name}':`, {
          jobId: job.id,
          jobType: job.name,
          duration: Date.now() - job.processedOn
        });
      });

      queue.on('failed', (job, error) => {
        logger.error(`Job failed in queue '${name}':`, {
          jobId: job.id,
          jobType: job.name,
          error: error.message,
          attempts: job.attemptsMade,
          maxAttempts: job.opts.attempts
        });
      });

      queue.on('stalled', job => {
        logger.warn(`Job stalled in queue '${name}':`, {
          jobId: job.id,
          jobType: job.name
        });
      });

      queue.on('progress', (job, progress) => {
        logger.debug(`Job progress in queue '${name}':`, {
          jobId: job.id,
          jobType: job.name,
          progress: `${progress}%`
        });
      });
    });
  }

  // Public methods for adding jobs
  addEmailJob(type, data, options = {}) {
    if (!this.isInitialized) {
      logger.warn('Job queue not initialized - email job skipped');
      return null;
    }

    const emailQueue = this.queues.get('email');
    return emailQueue.add(type, data, {
      priority: options.priority || 0,
      delay: options.delay || 0,
      ...options
    });
  }

  addNotificationJob(type, data, options = {}) {
    if (!this.isInitialized) {
      logger.warn('Job queue not initialized - notification job skipped');
      return null;
    }

    const notificationsQueue = this.queues.get('notifications');
    return notificationsQueue.add(type, data, {
      priority: options.priority || 0,
      delay: options.delay || 0,
      ...options
    });
  }

  addAnalyticsJob(type, data, options = {}) {
    if (!this.isInitialized) {
      logger.warn('Job queue not initialized - analytics job skipped');
      return null;
    }

    const analyticsQueue = this.queues.get('analytics');
    return analyticsQueue.add(type, data, {
      priority: options.priority || 0,
      delay: options.delay || 0,
      ...options
    });
  }

  addCleanupJob(type, data, options = {}) {
    if (!this.isInitialized) {
      logger.warn('Job queue not initialized - cleanup job skipped');
      return null;
    }

    const cleanupQueue = this.queues.get('cleanup');
    return cleanupQueue.add(type, data, {
      priority: options.priority || 0,
      delay: options.delay || 0,
      ...options
    });
  }

  // Recurring jobs
  addRecurringJob(queueName, jobName, data, cronPattern, options = {}) {
    if (!this.isInitialized) {
      logger.warn('Job queue not initialized - recurring job skipped');
      return null;
    }

    const queue = this.queues.get(queueName);
    if (!queue) {
      logger.error(`Queue '${queueName}' not found`);
      return null;
    }

    return queue.add(jobName, data, {
      repeat: { cron: cronPattern },
      ...options
    });
  }

  // Queue management methods
  async getQueueStats(queueName) {
    if (!this.isInitialized) {
      return null;
    }

    const queue = this.queues.get(queueName);
    if (!queue) {
      return null;
    }

    const [waiting, active, completed, failed, delayed] = await Promise.all([
      queue.getWaiting(),
      queue.getActive(),
      queue.getCompleted(),
      queue.getFailed(),
      queue.getDelayed()
    ]);

    return {
      name: queueName,
      waiting: waiting.length,
      active: active.length,
      completed: completed.length,
      failed: failed.length,
      delayed: delayed.length
    };
  }

  async getAllQueueStats() {
    if (!this.isInitialized) {
      return {};
    }

    const stats = {};
    for (const queueName of this.queues.keys()) {
      stats[queueName] = await this.getQueueStats(queueName);
    }
    return stats;
  }

  async pauseQueue(queueName) {
    const queue = this.queues.get(queueName);
    if (queue) {
      await queue.pause();
      logger.info(`Queue '${queueName}' paused`);
    }
  }

  async resumeQueue(queueName) {
    const queue = this.queues.get(queueName);
    if (queue) {
      await queue.resume();
      logger.info(`Queue '${queueName}' resumed`);
    }
  }

  async closeAllQueues() {
    if (!this.isInitialized) {
      return;
    }

    for (const [name, queue] of this.queues) {
      await queue.close();
      logger.info(`Queue '${name}' closed`);
    }

    this.queues.clear();
    this.isInitialized = false;
  }
}

export default new JobQueue();
