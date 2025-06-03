const nodemailer = require('nodemailer');
const config = require('../config');
const logger = require('./logger');

class EmailService {
  constructor() {
    this.transporter = null;
    this.isConfigured = false;
    this.initialize();
  }

  initialize() {
    try {
      if (!config.email.host || !config.email.user || !config.email.password) {
        logger.warn('Email service not configured - missing credentials');
        return;
      }

      this.transporter = nodemailer.createTransporter({
        host: config.email.host,
        port: config.email.port,
        secure: config.email.port === 465, // true for 465, false for other ports
        auth: {
          user: config.email.user,
          pass: config.email.password
        },
        tls: {
          rejectUnauthorized: false
        }
      });

      this.isConfigured = true;
      logger.info('✅ Email service initialized');
    } catch (error) {
      logger.error('Failed to initialize email service:', error);
    }
  }

  async verifyConnection() {
    if (!this.isConfigured) {
      throw new Error('Email service not configured');
    }

    try {
      await this.transporter.verify();
      logger.info('Email service connection verified');
      return true;
    } catch (error) {
      logger.error('Email service connection verification failed:', error);
      throw error;
    }
  }

  async sendEmail(options) {
    if (!this.isConfigured) {
      logger.warn('Attempted to send email but service not configured');
      return false;
    }

    try {
      const mailOptions = {
        from: options.from || config.email.from,
        to: options.to,
        cc: options.cc,
        bcc: options.bcc,
        subject: options.subject,
        text: options.text,
        html: options.html,
        attachments: options.attachments
      };

      const result = await this.transporter.sendMail(mailOptions);
      logger.info(`Email sent successfully to ${options.to}`, {
        messageId: result.messageId,
        response: result.response
      });

      return {
        success: true,
        messageId: result.messageId,
        response: result.response
      };
    } catch (error) {
      logger.error('Failed to send email:', error);
      throw error;
    }
  }

  // Template-based email methods
  async sendWelcomeEmail(userEmail, userName) {
    const subject = 'Welcome to DIND JavaScript API!';
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h1 style="color: #333;">Welcome, ${userName}!</h1>
        <p>Thank you for registering with DIND JavaScript API.</p>
        <p>Your account has been created successfully and you can now start using our services.</p>
        <div style="margin: 20px 0; padding: 20px; background-color: #f5f5f5; border-radius: 5px;">
          <h3>Getting Started:</h3>
          <ul>
            <li>Explore our API documentation</li>
            <li>Check out the health monitoring dashboard</li>
            <li>Join our WebSocket channels for real-time updates</li>
          </ul>
        </div>
        <p>If you have any questions, feel free to contact our support team.</p>
        <p>Best regards,<br>The DIND JavaScript API Team</p>
      </div>
    `;

    return this.sendEmail({
      to: userEmail,
      subject,
      html
    });
  }

  async sendPasswordResetEmail(userEmail, resetToken, userName) {
    const resetUrl = `${config.isProduction ? 'https' : 'http'}://localhost:${config.port}/auth/reset-password?token=${resetToken}`;

    const subject = 'Password Reset Request';
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h1 style="color: #333;">Password Reset Request</h1>
        <p>Hello ${userName},</p>
        <p>We received a request to reset your password for your DIND JavaScript API account.</p>
        <div style="margin: 20px 0; padding: 20px; background-color: #f8f9fa; border-radius: 5px; text-align: center;">
          <a href="${resetUrl}" style="background-color: #007bff; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block;">Reset Password</a>
        </div>
        <p>If you didn't request this password reset, please ignore this email. Your password will remain unchanged.</p>
        <p>This link will expire in 1 hour for security reasons.</p>
        <p>If the button above doesn't work, copy and paste this URL into your browser:</p>
        <p style="word-break: break-all; color: #666;">${resetUrl}</p>
        <p>Best regards,<br>The DIND JavaScript API Team</p>
      </div>
    `;

    return this.sendEmail({
      to: userEmail,
      subject,
      html
    });
  }

  async sendNotificationEmail(userEmail, title, message, userName) {
    const subject = `Notification: ${title}`;
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h1 style="color: #333;">${title}</h1>
        <p>Hello ${userName},</p>
        <div style="margin: 20px 0; padding: 20px; background-color: #e3f2fd; border-left: 4px solid #2196f3; border-radius: 5px;">
          ${message}
        </div>
        <p>This is an automated notification from DIND JavaScript API.</p>
        <p>Best regards,<br>The DIND JavaScript API Team</p>
      </div>
    `;

    return this.sendEmail({
      to: userEmail,
      subject,
      html
    });
  }

  async sendBulkEmail(recipients, subject, html) {
    if (!Array.isArray(recipients) || recipients.length === 0) {
      throw new Error('Recipients must be a non-empty array');
    }

    const results = [];

    for (const recipient of recipients) {
      try {
        const result = await this.sendEmail({
          to: recipient,
          subject,
          html
        });
        results.push({ recipient, success: true, result });
      } catch (error) {
        logger.error(`Failed to send email to ${recipient}:`, error);
        results.push({ recipient, success: false, error: error.message });
      }
    }

    return results;
  }

  // Email queue methods (would integrate with Bull queue)
  async queueEmail(emailData, options = {}) {
    // This would integrate with a job queue like Bull
    // For now, just send immediately
    const delay = options.delay || 0;

    if (delay > 0) {
      setTimeout(() => {
        this.sendEmail(emailData);
      }, delay);
    } else {
      return this.sendEmail(emailData);
    }
  }

  getStatus() {
    return {
      isConfigured: this.isConfigured,
      host: config.email.host,
      port: config.email.port,
      user: config.email.user
        ? config.email.user.replace(/(.{2}).*(@.*)/, '$1***$2')
        : 'Not configured'
    };
  }
}

module.exports = new EmailService();
