const mongoose = require('mongoose');
const { v4: uuidv4 } = require('uuid');

const userSchema = new mongoose.Schema({
  _id: {
    type: String,
    default: uuidv4
  },
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    trim: true,
    match: [/^\w+([.-]?\w+)*@\w+([.-]?\w+)*(\.\w{2,3})+$/, 'Please enter a valid email']
  },
  username: {
    type: String,
    required: true,
    unique: true,
    trim: true,
    minlength: 3,
    maxlength: 30,
    match: [/^[a-zA-Z0-9_]+$/, 'Username can only contain letters, numbers, and underscores']
  },
  password: {
    type: String,
    required: true,
    minlength: 6
  },
  firstName: {
    type: String,
    required: true,
    trim: true,
    maxlength: 50
  },
  lastName: {
    type: String,
    required: true,
    trim: true,
    maxlength: 50
  },
  roles: {
    type: [String],
    enum: ['user', 'admin', 'moderator'],
    default: ['user']
  },
  isActive: {
    type: Boolean,
    default: true
  },
  isVerified: {
    type: Boolean,
    default: false
  },
  lastLoginAt: {
    type: Date
  },
  profile: {
    avatar: String,
    bio: {
      type: String,
      maxlength: 500
    },
    location: String,
    website: String,
    dateOfBirth: Date
  },
  preferences: {
    language: {
      type: String,
      default: 'en'
    },
    timezone: {
      type: String,
      default: 'UTC'
    },
    notifications: {
      email: {
        type: Boolean,
        default: true
      },
      push: {
        type: Boolean,
        default: true
      }
    }
  },
  metadata: {
    loginCount: {
      type: Number,
      default: 0
    },
    lastIpAddress: String,
    userAgent: String,
    referralSource: String
  }
}, {
  timestamps: true,
  versionKey: false
});

// Indexes
userSchema.index({ email: 1 });
userSchema.index({ username: 1 });
userSchema.index({ isActive: 1, isVerified: 1 });
userSchema.index({ createdAt: -1 });

// Virtual for full name
userSchema.virtual('fullName').get(function () {
  return `${this.firstName} ${this.lastName}`;
});

// Virtual for public profile
userSchema.virtual('publicProfile').get(function () {
  return {
    id: this._id,
    username: this.username,
    firstName: this.firstName,
    lastName: this.lastName,
    fullName: this.fullName,
    profile: {
      avatar: this.profile?.avatar,
      bio: this.profile?.bio,
      location: this.profile?.location,
      website: this.profile?.website
    },
    createdAt: this.createdAt
  };
});

// Method to check if user has role
userSchema.methods.hasRole = function (role) {
  return this.roles.includes(role);
};

// Method to add role
userSchema.methods.addRole = function (role) {
  if (!this.roles.includes(role)) {
    this.roles.push(role);
  }
};

// Method to remove role
userSchema.methods.removeRole = function (role) {
  this.roles = this.roles.filter(r => r !== role);
};

// Method to update login info
userSchema.methods.updateLoginInfo = function (ipAddress, userAgent) {
  this.lastLoginAt = new Date();
  this.metadata.loginCount += 1;
  this.metadata.lastIpAddress = ipAddress;
  this.metadata.userAgent = userAgent;
};

// Method to get safe user object (without password)
userSchema.methods.toSafeObject = function () {
  const user = this.toObject();
  delete user.password;
  return user;
};

// Transform JSON output to exclude password
userSchema.methods.toJSON = function () {
  const user = this.toObject();
  delete user.password;
  return user;
};

// Static method to find by email or username
userSchema.statics.findByEmailOrUsername = function (identifier) {
  return this.findOne({
    $or: [
      { email: identifier.toLowerCase() },
      { username: identifier }
    ]
  });
};

// Static method to get active users
userSchema.statics.getActiveUsers = function () {
  return this.find({ isActive: true, isVerified: true });
};

module.exports = mongoose.model('User', userSchema);
