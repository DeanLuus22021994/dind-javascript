// Flat config for ESLint (ESM, modern, future-proof)

import js from '@eslint/js';
import prettier from 'eslint-config-prettier';
import prettierPlugin from 'eslint-plugin-prettier';

export default [
  js.configs.recommended,
  {
    files: ['**/*.js'],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'module',
    },
    plugins: {
      prettier: prettierPlugin,
    },
    rules: {
      'no-unused-vars': 'warn',
      'no-console': 'off',
      'no-debugger': 'warn',
      'prettier/prettier': 'error',
    },
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
