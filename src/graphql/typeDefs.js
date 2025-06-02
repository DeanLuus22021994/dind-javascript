// filepath: src/graphql/typeDefs.js
const { gql } = require('apollo-server-express');

const typeDefs = gql`
  type User {
    id: ID!
    username: String!
    email: String!
    firstName: String
    lastName: String
    role: String!
    isActive: Boolean!
    lastLogin: String
    createdAt: String!
    updatedAt: String!
  }

  type AuthPayload {
    token: String!
    user: User!
  }

  type Query {
    me: User
    users: [User!]!
    user(id: ID!): User
  }

  type Mutation {
    register(
      username: String!
      email: String!
      password: String!
      firstName: String
      lastName: String
    ): AuthPayload!

    login(
      email: String!
      password: String!
    ): AuthPayload!

    updateProfile(
      firstName: String
      lastName: String
    ): User!

    deleteAccount: Boolean!
  }
`;

module.exports = typeDefs;
