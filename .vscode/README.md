# VS Code Workspace Configuration

## Created Files

- **`.vscode/settings.json`** - IDE settings for consistent development environment
- **`.vscode/launch.json`** - Debug configurations for tests and application
- **`.vscode/tasks.json`** - Build and test tasks
- **`.vscode/extensions.json`** - Recommended extensions

## Debug Configurations

### Test Debugging

- **Run All Tests** - Execute complete test suite
- **Run Current Test File** - Run tests in currently open file
- **Debug Current Test File** - Debug tests in currently open file with breakpoints
- **Debug Specific Test** - Run a specific test by name pattern

### Application Debugging

- **Run App (Development)** - Start application in development mode
- **Debug App (Development)** - Debug application with breakpoints
- **Attach to Running App** - Attach debugger to running application

## Available Tasks

### Testing Tasks

- **npm: test** - Run all tests (default test task)
- **npm: test:watch** - Run tests in watch mode
- **npm: test:coverage** - Run tests with coverage report
- **Jest: Run Current File** - Run tests for current file only

### Development Tasks

- **npm: start** - Start application (default build task)
- **npm: dev** - Start in development mode with hot reload
- **ESLint: Fix All** - Fix all ESLint issues automatically
- **Prettier: Format All** - Format all files with Prettier

## Key Features

### IDE Integration

- Auto-format on save with Prettier
- ESLint integration with auto-fix
- Jest test runner integration
- IntelliSense for JavaScript/Node.js
- Coverage highlighting in editor

### File Exclusions

- Excludes `node_modules`, `logs`, `uploads` from search and file watching
- Optimized for better performance

### PowerShell Integration

- Configured for Windows PowerShell as default terminal
- Proper shell command generation for Windows

## Usage

1. **Running Tests**: Use `Ctrl+Shift+P` > "Tasks: Run Task" > "npm: test"
2. **Debugging Tests**: Press `F5` and select "Debug Current Test File"
3. **Test Coverage**: Use "npm: test:coverage" task
4. **Watch Mode**: Use "npm: test:watch" for continuous testing

## Keyboard Shortcuts

- `F5` - Start debugging (will show debug configuration picker)
- `Ctrl+Shift+P` - Command palette for tasks
- `Ctrl+`` ` - Toggle integrated terminal
- `Ctrl+Shift+`` ` - Create new terminal
