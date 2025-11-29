# JavaScript Tests for PWA Service Worker

This directory contains Jest tests for the Progressive Web App (PWA) Service Worker modules.

## Test Structure

```
spec/javascript/
├── setup.js                          # Test setup with Service Worker API mocks
├── pwa/
│   ├── strategies/
│   │   ├── cache_first_strategy.test.js    # Cache-first strategy tests
│   │   ├── network_first_strategy.test.js  # Network-first strategy tests
│   │   └── network_only_strategy.test.js   # Network-only strategy tests
│   ├── strategy_router.test.js             # Strategy router tests
│   ├── lifecycle_manager.test.js           # Lifecycle manager tests
│   └── config_loader.test.js               # Config loader tests
└── README.md                         # This file
```

## Running Tests

### Install Dependencies

First, install the required npm packages:

```bash
npm install
```

### Run All Tests

```bash
npm test
```

### Run Tests in Watch Mode

```bash
npm run test:watch
```

### Run Tests with Coverage Report

```bash
npm run test:coverage
```

Coverage reports are generated in the `/coverage` directory.

## Test Coverage Targets

- **Branches**: ≥ 80%
- **Functions**: ≥ 80%
- **Lines**: ≥ 80%
- **Statements**: ≥ 80%

## What's Being Tested

### Cache Strategies

1. **CacheFirstStrategy** (`cache_first_strategy.test.js`)
   - Serves from cache when available
   - Falls back to network on cache miss
   - Caches network responses
   - Updates cache in background
   - Handles errors gracefully

2. **NetworkFirstStrategy** (`network_first_strategy.test.js`)
   - Tries network first with timeout
   - Falls back to cache on network failure
   - Caches successful network responses
   - Handles timeout errors
   - Provides offline fallback

3. **NetworkOnlyStrategy** (`network_only_strategy.test.js`)
   - Always fetches from network
   - Never caches responses
   - Provides appropriate error responses
   - Differentiates navigation vs API requests

### Router & Lifecycle

4. **StrategyRouter** (`strategy_router.test.js`)
   - Matches URL patterns correctly
   - Routes to appropriate strategies
   - Handles unmatched requests
   - Skips non-GET and cross-origin requests

5. **LifecycleManager** (`lifecycle_manager.test.js`)
   - Pre-caches critical assets on install
   - Cleans up old caches on activate
   - Calls skipWaiting and clients.claim
   - Handles errors during lifecycle events

6. **ConfigLoader** (`config_loader.test.js`)
   - Fetches configuration from API
   - Falls back to defaults on error
   - Provides nested config value access
   - Handles invalid API responses

## Mock Environment

The test setup (`setup.js`) provides mocks for:

- **Cache API**: `caches.open()`, `caches.match()`, `caches.keys()`, `caches.delete()`
- **Fetch API**: `fetch()` with configurable responses
- **Service Worker Globals**: `self.skipWaiting()`, `self.clients.claim()`
- **Request/Response**: Browser-like Request and Response classes
- **AbortController**: For testing timeout functionality

## Test Patterns

### Example: Testing Cache Hit

```javascript
it('should serve from cache when available', async () => {
  // Arrange
  const cachedResponse = createMockResponse('cached content');
  mockCache.match.mockResolvedValue(cachedResponse);

  // Act
  const result = await strategy.handle(mockRequest);

  // Assert
  expect(result).toBe(cachedResponse);
  expect(mockCache.match).toHaveBeenCalledWith(mockRequest);
});
```

### Example: Testing Network Fallback

```javascript
it('should fall back to cache when network fails', async () => {
  // Arrange
  global.fetch.mockRejectedValue(new Error('Network error'));
  const cachedResponse = createMockResponse('cached content');
  mockCache.match.mockResolvedValue(cachedResponse);

  // Act
  const result = await strategy.handle(mockRequest);

  // Assert
  expect(result).toBe(cachedResponse);
  expect(console.warn).toHaveBeenCalledWith('[SW] Network failed:', 'Network error');
});
```

## Helper Functions

The setup file provides helper functions for creating test fixtures:

- `setupCacheMock()`: Creates a mock cache object
- `createMockResponse(body, options)`: Creates a mock Response
- `createMockRequest(url, options)`: Creates a mock Request

## Troubleshooting

### Tests Fail with "Cannot find module"

Make sure you've installed all dependencies:

```bash
npm install
```

### Coverage Not Meeting Thresholds

Run coverage report to see uncovered lines:

```bash
npm run test:coverage
```

Then check the HTML report in `/coverage/index.html`.

### Mock Issues

If mocks aren't working correctly, check that:
1. `setup.js` is being loaded (configured in `jest.config.js`)
2. Mocks are cleared between tests (happens automatically in `beforeEach`)

## CI/CD Integration

To run tests in CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
- name: Run JavaScript Tests
  run: |
    npm ci
    npm run test:coverage
```

## Related Documentation

- [Jest Documentation](https://jestjs.io/docs/getting-started)
- [Service Worker API](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API)
- [Cache API](https://developer.mozilla.org/en-US/docs/Web/API/Cache)
