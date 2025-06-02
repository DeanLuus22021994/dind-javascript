const { gql } = require('apollo-server-express');

const typeDefs = gql`
  type User {
    id: ID!
    username: String!
    email: String!
    firstName: String
    lastName: String
    fullName: String
    role: String!
    isActive: Boolean!
    createdAt: String!
    lastLogin: String
  }

  type AuthPayload {
    token: String!
    user: User!
  }

  type ChangePasswordResponse {
    success: Boolean!
    message: String!
  }

  type DeleteUserResponse {
    success: Boolean!
    message: String!
  }

  input RegisterInput {
    username: String!
    email: String!
    password: String!
    firstName: String
    lastName: String
  }

  input UpdateProfileInput {
    firstName: String
    lastName: String
  }

  type Query {
    me: User
    users: [User!]!
    user(id: ID!): User
  }

  type Mutation {
    register(input: RegisterInput!): AuthPayload!
    login(email: String!, password: String!): AuthPayload!
    updateProfile(input: UpdateProfileInput!): User!
    changePassword(currentPassword: String!, newPassword: String!): ChangePasswordResponse!
    deleteUser(id: ID!): DeleteUserResponse!
  }
`;

module.exports = typeDefs;
