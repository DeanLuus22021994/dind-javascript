// Flat config for ESLint (ESM, modern, future-proof)
import js from '@eslint/js';
import prettier from 'eslint-config-prettier';

export default [
  js.configs.recommended,
  {
    files: ['**/*.js'],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'module',
    },
    rules: {
      'no-unused-vars': 'warn',
      'no-console': 'off',
      'no-debugger': 'warn',
      'prettier/prettier': 'error',
    },
    plugins: {},
  },
  {
    files: ['**/src/tests/**/*.js', '**/__tests__/**/*.js'],
    rules: {
      'no-unused-expressions': 'off',
      'no-empty-function': 'off',
    },
  },
  prettier,
];
