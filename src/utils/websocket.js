const socketIO = require('socket.io');
const jwt = require('jsonwebtoken');
const logger = require('./logger');
const config = require('../config');
const redisClient = require('./redis');

class WebSocketServer {
  constructor() {
    this.io = null;
    this.connectedUsers = new Map();
    this.rooms = new Map();
  }

  initialize(server) {
    if (!config.enableWebSocket) {
      logger.info('WebSocket disabled by configuration');
      return;
    }

    this.io = socketIO(server, {
      cors: {
        origin: config.corsOrigins,
        methods: ['GET', 'POST'],
        credentials: true
      },
      pingTimeout: 60000,
      pingInterval: 25000
    });

    // Authentication middleware
    this.io.use(async (socket, next) => {
      try {
        const token = socket.handshake.auth.token || socket.handshake.headers.authorization?.replace('Bearer ', '');

        if (!token) {
          socket.isAuthenticated = false;
          socket.user = { id: 'anonymous', role: 'guest' };
          return next();
        }

        const decoded = jwt.verify(token, config.jwtSecret);
        socket.isAuthenticated = true;
        socket.user = decoded;

        logger.debug(`WebSocket authentication successful for user: ${decoded.userId}`);
        next();
      } catch (error) {
        logger.warn('WebSocket authentication failed:', error.message);
        socket.isAuthenticated = false;
        socket.user = { id: 'anonymous', role: 'guest' };
        next();
      }
    });

    this.setupEventHandlers();
    logger.info('✅ WebSocket server initialized');
  }

  setupEventHandlers() {
    this.io.on('connection', (socket) => {
      this.handleConnection(socket);

      // Event handlers
      socket.on('join-room', (data) => this.handleJoinRoom(socket, data));
      socket.on('leave-room', (data) => this.handleLeaveRoom(socket, data));
      socket.on('send-message', (data) => this.handleSendMessage(socket, data));
      socket.on('typing-start', (data) => this.handleTypingStart(socket, data));
      socket.on('typing-stop', (data) => this.handleTypingStop(socket, data));
      socket.on('get-online-users', () => this.handleGetOnlineUsers(socket));
      socket.on('ping', () => this.handlePing(socket));

      socket.on('disconnect', (reason) => this.handleDisconnection(socket, reason));
      socket.on('error', (error) => this.handleError(socket, error));
    });
  }

  handleConnection(socket) {
    const userId = socket.isAuthenticated ? socket.user.userId : socket.id;

    this.connectedUsers.set(socket.id, {
      socketId: socket.id,
      userId,
      isAuthenticated: socket.isAuthenticated,
      connectedAt: new Date(),
      user: socket.user
    });

    logger.info(`WebSocket connection established: ${socket.id} (${socket.isAuthenticated ? 'authenticated' : 'anonymous'})`);

    // Send welcome message
    socket.emit('connected', {
      socketId: socket.id,
      isAuthenticated: socket.isAuthenticated,
      user: socket.user,
      timestamp: new Date().toISOString()
    });

    // Broadcast user count
    this.broadcastUserCount();

    // Store connection in Redis for scaling
    if (socket.isAuthenticated) {
      redisClient.set(`ws:user:${userId}`, {
        socketId: socket.id,
        connectedAt: new Date(),
        serverId: process.env.SERVER_ID || 'server-1'
      }, 24 * 60 * 60);
    }
  }

  handleDisconnection(socket, reason) {
    const userInfo = this.connectedUsers.get(socket.id);

    if (userInfo) {
      logger.info(`WebSocket disconnection: ${socket.id} (reason: ${reason})`);

      // Remove from connected users
      this.connectedUsers.delete(socket.id);

      // Remove from all rooms
      this.leaveAllRooms(socket);

      // Remove from Redis
      if (userInfo.isAuthenticated) {
        redisClient.del(`ws:user:${userInfo.userId}`);
      }

      // Broadcast updated user count
      this.broadcastUserCount();
    }
  }

  handleError(socket, error) {
    logger.error(`WebSocket error for ${socket.id}:`, error);
    socket.emit('error', {
      message: 'An error occurred',
      timestamp: new Date().toISOString()
    });
  }

  handleJoinRoom(socket, data) {
    const { room, password } = data;

    if (!room || typeof room !== 'string') {
      return socket.emit('error', { message: 'Invalid room name' });
    }

    try {
      // Check if room requires authentication
      if (room.startsWith('private:') && !socket.isAuthenticated) {
        return socket.emit('join-room-error', {
          room,
          message: 'Authentication required for private rooms'
        });
      }

      socket.join(room);

      // Track room membership
      if (!this.rooms.has(room)) {
        this.rooms.set(room, new Set());
      }
      this.rooms.get(room).add(socket.id);

      logger.debug(`User ${socket.id} joined room: ${room}`);

      // Notify user
      socket.emit('joined-room', {
        room,
        timestamp: new Date().toISOString()
      });

      // Notify other users in room
      socket.to(room).emit('user-joined-room', {
        room,
        user: socket.isAuthenticated ? socket.user : { id: socket.id, role: 'guest' },
        timestamp: new Date().toISOString()
      });

      // Send room info
      this.sendRoomInfo(socket, room);
    } catch (error) {
      logger.error(`Error joining room ${room}:`, error);
      socket.emit('join-room-error', {
        room,
        message: 'Failed to join room'
      });
    }
  }

  handleLeaveRoom(socket, data) {
    const { room } = data;

    if (!room) {
      return socket.emit('error', { message: 'Room name required' });
    }

    this.leaveRoom(socket, room);
  }

  leaveRoom(socket, room) {
    socket.leave(room);

    // Remove from room tracking
    if (this.rooms.has(room)) {
      this.rooms.get(room).delete(socket.id);
      if (this.rooms.get(room).size === 0) {
        this.rooms.delete(room);
      }
    }

    logger.debug(`User ${socket.id} left room: ${room}`);

    // Notify user
    socket.emit('left-room', {
      room,
      timestamp: new Date().toISOString()
    });

    // Notify other users in room
    socket.to(room).emit('user-left-room', {
      room,
      user: socket.isAuthenticated ? socket.user : { id: socket.id, role: 'guest' },
      timestamp: new Date().toISOString()
    });
  }

  leaveAllRooms(socket) {
    const rooms = Array.from(socket.rooms);
    rooms.forEach(room => {
      if (room !== socket.id) { // Skip the default room (socket.id)
        this.leaveRoom(socket, room);
      }
    });
  }

  handleSendMessage(socket, data) {
    const { room, message, type = 'text' } = data;

    if (!room || !message) {
      return socket.emit('error', { message: 'Room and message are required' });
    }

    if (!socket.rooms.has(room)) {
      return socket.emit('error', { message: 'You are not in this room' });
    }

    const messageData = {
      id: `msg_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      room,
      message,
      type,
      user: socket.isAuthenticated ? socket.user : { id: socket.id, role: 'guest' },
      timestamp: new Date().toISOString()
    };

    // Send to all users in room including sender
    this.io.to(room).emit('new-message', messageData);

    logger.debug(`Message sent in room ${room} by ${socket.id}`);
  }

  handleTypingStart(socket, data) {
    const { room } = data;

    if (!room || !socket.rooms.has(room)) {
      return;
    }

    socket.to(room).emit('user-typing', {
      room,
      user: socket.isAuthenticated ? socket.user : { id: socket.id, role: 'guest' },
      timestamp: new Date().toISOString()
    });
  }

  handleTypingStop(socket, data) {
    const { room } = data;

    if (!room || !socket.rooms.has(room)) {
      return;
    }

    socket.to(room).emit('user-stopped-typing', {
      room,
      user: socket.isAuthenticated ? socket.user : { id: socket.id, role: 'guest' },
      timestamp: new Date().toISOString()
    });
  }

  handleGetOnlineUsers(socket) {
    const onlineUsers = Array.from(this.connectedUsers.values())
      .filter(user => user.isAuthenticated)
      .map(user => ({
        userId: user.userId,
        user: user.user,
        connectedAt: user.connectedAt
      }));

    socket.emit('online-users', {
      count: onlineUsers.length,
      users: onlineUsers,
      timestamp: new Date().toISOString()
    });
  }

  handlePing(socket) {
    socket.emit('pong', { timestamp: new Date().toISOString() });
  }

  sendRoomInfo(socket, room) {
    const roomUsers = this.io.sockets.adapter.rooms.get(room);
    const userCount = roomUsers ? roomUsers.size : 0;

    socket.emit('room-info', {
      room,
      userCount,
      timestamp: new Date().toISOString()
    });
  }

  broadcastUserCount() {
    const totalUsers = this.connectedUsers.size;
    const authenticatedUsers = Array.from(this.connectedUsers.values())
      .filter(user => user.isAuthenticated).length;

    this.io.emit('user-count', {
      total: totalUsers,
      authenticated: authenticatedUsers,
      anonymous: totalUsers - authenticatedUsers,
      timestamp: new Date().toISOString()
    });
  }

  // Public methods for external use
  sendToUser(userId, event, data) {
    const userConnections = Array.from(this.connectedUsers.values())
      .filter(conn => conn.userId === userId);

    userConnections.forEach(conn => {
      this.io.to(conn.socketId).emit(event, data);
    });
  }

  sendToRoom(room, event, data) {
    this.io.to(room).emit(event, data);
  }

  broadcastToAll(event, data) {
    this.io.emit(event, data);
  }

  getStats() {
    return {
      connectedUsers: this.connectedUsers.size,
      authenticatedUsers: Array.from(this.connectedUsers.values())
        .filter(user => user.isAuthenticated).length,
      activeRooms: this.rooms.size
    };
  }
}

module.exports = new WebSocketServer();
