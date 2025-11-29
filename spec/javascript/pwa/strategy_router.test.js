/**
 * Tests for StrategyRouter
 * Routes fetch requests to appropriate caching strategies
 */

import { StrategyRouter } from '../../../app/javascript/pwa/strategy_router.js';

describe('StrategyRouter', () => {
  let router;
  let mockConfig;

  beforeEach(() => {
    mockConfig = {
      version: 'v1',
      cache: {
        static: {
          strategy: 'cache-first',
          patterns: ['\\.(?:css|js|woff2?)$'],
          max_age: 86400
        },
        images: {
          strategy: 'cache-first',
          patterns: ['\\.(?:png|jpg|jpeg|gif|webp|svg|ico)$'],
          max_age: 604800
        },
        pages: {
          strategy: 'network-first',
          patterns: ['^/$', '^/terms$', '^/privacy_policy$'],
          timeout: 3000
        },
        api: {
          strategy: 'network-only',
          patterns: ['^/api/', '^/operator/']
        }
      },
      network: {
        timeout: 3000,
        retries: 1
      }
    };

    router = new StrategyRouter(mockConfig);
  });

  describe('constructor()', () => {
    it('should initialize with config', () => {
      expect(router.config).toBe(mockConfig);
      expect(router.version).toBe('v1');
      expect(router.strategies).toHaveLength(4);
    });

    it('should use default version if not provided', () => {
      const configWithoutVersion = { cache: {} };
      const routerWithoutVersion = new StrategyRouter(configWithoutVersion);
      expect(routerWithoutVersion.version).toBe('v1');
    });

    it('should convert pattern strings to RegExp objects', () => {
      const strategy = router.strategies.find(s => s.name === 'static');
      expect(strategy.patterns[0]).toBeInstanceOf(RegExp);
    });

    it('should filter out invalid patterns', () => {
      const invalidConfig = {
        cache: {
          test: {
            strategy: 'cache-first',
            patterns: ['\\.js$', '[invalid(regex']
          }
        }
      };

      const routerWithInvalid = new StrategyRouter(invalidConfig);
      const strategy = routerWithInvalid.strategies[0];
      expect(strategy.patterns).toHaveLength(1); // Only valid pattern
      expect(console.warn).toHaveBeenCalledWith('[SW] Invalid pattern:', '[invalid(regex');
    });
  });

  describe('initializeStrategies()', () => {
    it('should create strategy instances with correct cache names', () => {
      const staticStrategy = router.strategies.find(s => s.name === 'static');
      expect(staticStrategy.strategy.cacheName).toBe('static-v1');
    });

    it('should pass timeout options from cache config', () => {
      const pagesStrategy = router.strategies.find(s => s.name === 'pages');
      expect(pagesStrategy.strategy.timeout).toBe(3000);
    });

    it('should fall back to network timeout if not specified in cache config', () => {
      const staticStrategy = router.strategies.find(s => s.name === 'static');
      expect(staticStrategy.strategy.timeout).toBe(3000); // From network.timeout
    });

    it('should use default timeout if not specified anywhere', () => {
      const minimalConfig = {
        cache: {
          test: {
            strategy: 'network-first',
            patterns: ['/test/']
          }
        }
      };

      const routerMinimal = new StrategyRouter(minimalConfig);
      expect(routerMinimal.strategies[0].strategy.timeout).toBe(3000);
    });
  });

  describe('getStrategyClass()', () => {
    it('should return CacheFirstStrategy for "cache-first"', () => {
      const StrategyClass = router.getStrategyClass('cache-first');
      expect(StrategyClass.name).toBe('CacheFirstStrategy');
    });

    it('should return NetworkFirstStrategy for "network-first"', () => {
      const StrategyClass = router.getStrategyClass('network-first');
      expect(StrategyClass.name).toBe('NetworkFirstStrategy');
    });

    it('should return NetworkOnlyStrategy for "network-only"', () => {
      const StrategyClass = router.getStrategyClass('network-only');
      expect(StrategyClass.name).toBe('NetworkOnlyStrategy');
    });

    it('should return NetworkFirstStrategy for unknown strategy', () => {
      const StrategyClass = router.getStrategyClass('unknown-strategy');
      expect(StrategyClass.name).toBe('NetworkFirstStrategy');
    });
  });

  describe('findStrategy()', () => {
    it('should match static assets with cache-first strategy', () => {
      const matched = router.findStrategy('/assets/application.css');
      expect(matched).not.toBeNull();
      expect(matched.name).toBe('static');
    });

    it('should match images with cache-first strategy', () => {
      const matched = router.findStrategy('/images/logo.png');
      expect(matched).not.toBeNull();
      expect(matched.name).toBe('images');
    });

    it('should match pages with network-first strategy', () => {
      const matched = router.findStrategy('/');
      expect(matched).not.toBeNull();
      expect(matched.name).toBe('pages');
    });

    it('should match API routes with network-only strategy', () => {
      const matched = router.findStrategy('/api/users');
      expect(matched).not.toBeNull();
      expect(matched.name).toBe('api');
    });

    it('should return null for unmatched paths', () => {
      const matched = router.findStrategy('/unknown/path');
      expect(matched).toBeNull();
    });

    it('should match first matching pattern', () => {
      // /api/ should match 'api' strategy, not others
      const matched = router.findStrategy('/api/data.json');
      expect(matched.name).toBe('api');
    });
  });

  describe('handleFetch()', () => {
    let mockEvent;

    beforeEach(() => {
      mockEvent = {
        request: createMockRequest('http://localhost:3000/assets/app.js')
      };
    });

    it('should skip non-GET requests', async () => {
      // Arrange
      const postRequest = createMockRequest('http://localhost:3000/api/data', {
        method: 'POST'
      });
      mockEvent.request = postRequest;

      const networkResponse = createMockResponse({ ok: true });
      global.fetch.mockResolvedValue(networkResponse);

      // Act
      const result = await router.handleFetch(mockEvent);

      // Assert
      expect(global.fetch).toHaveBeenCalledWith(postRequest);
      expect(result).toBe(networkResponse);
    });

    it('should skip cross-origin requests', async () => {
      // Arrange
      const crossOriginRequest = createMockRequest('https://external.com/data.json');
      mockEvent.request = crossOriginRequest;

      const networkResponse = createMockResponse({ data: 'external' });
      global.fetch.mockResolvedValue(networkResponse);

      // Act
      const result = await router.handleFetch(mockEvent);

      // Assert
      expect(global.fetch).toHaveBeenCalledWith(crossOriginRequest);
      expect(result).toBe(networkResponse);
    });

    it('should route matched requests to appropriate strategy', async () => {
      // Arrange
      const mockCache = setupCacheMock();
      const cachedResponse = createMockResponse('cached js');
      mockCache.match.mockResolvedValue(cachedResponse);

      // Mock fetch for potential network call
      global.fetch.mockResolvedValue(cachedResponse);

      // Act
      const result = await router.handleFetch(mockEvent);

      // Assert
      // The strategy should return a response (either from cache or network)
      expect(result).toBeDefined();
      expect(result.body).toBe('cached js');
    });

    it('should use network fetch for unmatched requests', async () => {
      // Arrange
      const unmatchedRequest = createMockRequest('http://localhost:3000/unknown/path');
      mockEvent.request = unmatchedRequest;

      const networkResponse = createMockResponse('network response');
      global.fetch.mockResolvedValue(networkResponse);

      // Act
      const result = await router.handleFetch(mockEvent);

      // Assert
      expect(global.fetch).toHaveBeenCalledWith(unmatchedRequest);
      expect(result).toBeDefined();
      expect(result).toEqual(networkResponse);
    });
  });

  describe('getStrategyNames()', () => {
    it('should return array of all strategy names', () => {
      const names = router.getStrategyNames();
      expect(names).toEqual(['static', 'images', 'pages', 'api']);
    });

    it('should return empty array for router with no strategies', () => {
      const emptyRouter = new StrategyRouter({ cache: {} });
      const names = emptyRouter.getStrategyNames();
      expect(names).toEqual([]);
    });
  });
});
