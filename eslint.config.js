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
      sourceType: 'module'
    },
    plugins: {
      prettier: prettierPlugin
    },
    rules: {
      'no-unused-vars': 'warn',
      'no-console': 'off',
      'no-debugger': 'warn',
      'prettier/prettier': 'error'
    }
  },
  {
    // Enable Jest globals for test files
    files: ['**/src/tests/**/*.js', '**/__tests__/**/*.js'],
    languageOptions: {
      globals: {
        describe: 'readonly',
        it: 'readonly',
        test: 'readonly',
        expect: 'readonly',
        beforeAll: 'readonly',
        afterAll: 'readonly',
        beforeEach: 'readonly',
        afterEach: 'readonly',
        jest: 'readonly',
        process: 'readonly',
        Buffer: 'readonly',
        setTimeout: 'readonly',
        __dirname: 'readonly',
        require: 'readonly',
        module: 'readonly',
        URL: 'readonly'
      }
    },
    rules: {
      'no-unused-expressions': 'off',
      'no-empty-function': 'off'
    }
  },
  prettier
];
