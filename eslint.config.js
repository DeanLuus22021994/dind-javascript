// Flat config for ESLint v9+
import js from "@eslint/js";

/** @type {import("eslint").FlatConfig[]} */
export default [
  js.config({
    env: { node: true, es2021: true, jest: true }
  }),
  {
    files: ["**/*.js"],
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "module"
    },
    rules: {
      "no-console": process.env.NODE_ENV === "production" ? "warn" : "off",
      "no-debugger": process.env.NODE_ENV === "production" ? "warn" : "off",
      "semi": ["error", "always"],
      "quotes": ["error", "single"],
      "indent": ["error", 2],
      "comma-dangle": ["error", "never"],
      "space-before-function-paren": ["error", "never"],
      "generator-star-spacing": ["error", { "before": false, "after": true }],
      "no-trailing-spaces": "error",
      "eol-last": "error",
      "no-multiple-empty-lines": ["error", { "max": 2, "maxEOF": 1 }],
      "object-curly-spacing": ["error", "always"],
      "array-bracket-spacing": ["error", "never"],
      "key-spacing": ["error", { "beforeColon": false, "afterColon": true }],
      "prefer-const": "error",
      "no-var": "error",
      "arrow-spacing": "error",
      "template-curly-spacing": "error"
    }
  },
  {
    files: ["**/__tests__/**/*", "**/*.test.js", "**/*.spec.js"],
    rules: {
      "no-console": "off"
    }
  }
];
