/**
 * Jest Configuration
 * For testing Service Worker modules with ES Modules support
 */

export default {
  // Test environment: jsdom for browser-like environment
  testEnvironment: 'jsdom',

  // Test file patterns
  testMatch: [
    '**/spec/javascript/**/*.test.js'
  ],

  // Setup files to run before tests
  setupFilesAfterEnv: ['<rootDir>/spec/javascript/setup.js'],

  // Module file extensions
  moduleFileExtensions: ['js', 'json'],

  // Transform settings with babel for ES modules
  transform: {
    '^.+\\.js$': ['babel-jest', { configFile: './babel.config.json' }]
  },

  // Don't transform node_modules except for ES modules
  transformIgnorePatterns: [
    'node_modules/(?!(somePkg)/)'
  ],

  // Coverage configuration
  collectCoverageFrom: [
    'app/javascript/pwa/strategies/**/*.js',
    'app/javascript/pwa/strategy_router.js',
    'app/javascript/pwa/lifecycle_manager.js',
    'app/javascript/pwa/config_loader.js',
    '!app/javascript/pwa/**/*.test.js'
  ],

  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80
    }
  },

  coverageReporters: ['text', 'text-summary', 'html', 'lcov'],

  // Module name mapper for absolute imports (if needed)
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/app/javascript/$1'
  },

  // Verbose output
  verbose: true,

  // Clear mocks between tests
  clearMocks: true,

  // Reset mocks between tests
  resetMocks: true,

  // Restore mocks between tests
  restoreMocks: true
};
