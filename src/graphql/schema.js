const { gql } = require('apollo-server-express');

const typeDefs = gql`
  scalar Date
  scalar Upload

  type User {
    id: ID!
    username: String!
    email: String!
    firstName: String
    lastName: String
    avatar: String
    role: Role!
    isActive: Boolean!
    lastLogin: Date
    createdAt: Date!
    updatedAt: Date!
    profile: UserProfile
    preferences: UserPreferences
  }

  type UserProfile {
    bio: String
    website: String
    location: String
    phone: String
    dateOfBirth: Date
    timezone: String
    language: String
  }

  type UserPreferences {
    emailNotifications: Boolean!
    pushNotifications: Boolean!
    smsNotifications: Boolean!
    theme: String!
    language: String!
  }

  enum Role {
    USER
    ADMIN
    MODERATOR
  }

  type AuthPayload {
    token: String!
    refreshToken: String!
    user: User!
    expiresIn: Int!
  }

  type File {
    id: ID!
    filename: String!
    originalName: String!
    mimetype: String!
    size: Int!
    path: String!
    url: String!
    uploadedBy: User!
    uploadedAt: Date!
  }

  type Message {
    id: ID!
    content: String!
    user: User!
    room: String!
    timestamp: Date!
    edited: Boolean!
    editedAt: Date
  }

  type HealthStatus {
    status: String!
    timestamp: Date!
    uptime: Float!
    memory: MemoryUsage!
    services: ServiceStatus!
  }

  type MemoryUsage {
    rss: Float!
    heapTotal: Float!
    heapUsed: Float!
    external: Float!
  }

  type ServiceStatus {
    database: ServiceHealth!
    redis: ServiceHealth!
    email: ServiceHealth!
    websocket: ServiceHealth!
  }

  type ServiceHealth {
    status: String!
    connected: Boolean!
    details: String
  }

  input RegisterInput {
    username: String!
    email: String!
    password: String!
    firstName: String
    lastName: String
  }

  input LoginInput {
    email: String!
    password: String!
  }

  input UpdateProfileInput {
    firstName: String
    lastName: String
    bio: String
    website: String
    location: String
    phone: String
    dateOfBirth: Date
    timezone: String
    language: String
  }

  input UpdatePreferencesInput {
    emailNotifications: Boolean
    pushNotifications: Boolean
    smsNotifications: Boolean
    theme: String
    language: String
  }

  type Query {
    # Authentication
    me: User
    users(limit: Int, offset: Int, search: String): [User!]!
    user(id: ID!): User

    # Files
    files(limit: Int, offset: Int): [File!]!
    file(id: ID!): File

    # Messages
    messages(room: String!, limit: Int, offset: Int): [Message!]!

    # System
    health: HealthStatus!
    metrics: String!

    # Admin
    systemStats: SystemStats
  }

  type Mutation {
    # Authentication
    register(input: RegisterInput!): AuthPayload!
    login(input: LoginInput!): AuthPayload!
    logout: Boolean!
    refreshToken: AuthPayload!
      # Profile
    updateProfile(input: UpdateProfileInput!): User!
    updatePreferences(input: UpdatePreferencesInput!): User!
    changePassword(currentPassword: String!, newPassword: String!): Boolean!
    uploadAvatar(file: Upload!): User!
    
    # Files
    uploadFile(file: Upload!): File!
    uploadFiles(files: [Upload!]!): [File!]!
    deleteFile(id: ID!): Boolean!
    
    # Messages
    sendMessage(room: String!, content: String!): Message!
    editMessage(id: ID!, content: String!): Message!
    deleteMessage(id: ID!): Boolean!
    
    # Admin
    updateUserRole(userId: ID!, role: Role!): User!
    deactivateUser(userId: ID!): User!
    activateUser(userId: ID!): User!
    deleteUser(userId: ID!): Boolean!
  }

  type Subscription {
    # Messages
    messageAdded(room: String!): Message!
    messageEdited(room: String!): Message!
    messageDeleted(room: String!): ID!
    
    # User presence
    userJoined(room: String!): User!
    userLeft(room: String!): User!
    userTyping(room: String!): TypingEvent!
    
    # System notifications
    systemAlert: SystemAlert!
  }

  type TypingEvent {
    user: User!
    room: String!
    isTyping: Boolean!
  }

  type SystemAlert {
    type: AlertType!
    message: String!
    severity: AlertSeverity!
    timestamp: Date!
  }

  enum AlertType {
    MAINTENANCE
    SECURITY
    SYSTEM_ERROR
    UPDATE
  }

  enum AlertSeverity {
    LOW
    MEDIUM
    HIGH
    CRITICAL
  }

  type SystemStats {
    totalUsers: Int!
    activeUsers: Int!
    totalFiles: Int!
    totalMessages: Int!
    systemUptime: Float!
    memoryUsage: MemoryUsage!
    diskUsage: DiskUsage!
  }

  type DiskUsage {
    total: Float!
    used: Float!
    free: Float!
    percentage: Float!
  }
`;

module.exports = typeDefs;
