/**
 * Tests for NetworkOnlyStrategy
 * Network-only strategy: always fetches from network, never caches
 */

import { NetworkOnlyStrategy } from '../../../../app/javascript/pwa/strategies/network_only_strategy.js';

describe('NetworkOnlyStrategy', () => {
  let strategy;
  let mockCache;
  let mockRequest;

  beforeEach(() => {
    // Set up strategy instance
    strategy = new NetworkOnlyStrategy('test-cache', {
      timeout: 1000
    });

    // Set up mock cache
    mockCache = setupCacheMock();

    // Create mock request
    mockRequest = createMockRequest('https://example.com/api/data');
  });

  describe('handle()', () => {
    it('should always fetch from network', async () => {
      // Arrange
      const networkResponse = createMockResponse({ data: 'test' });
      global.fetch.mockResolvedValue(networkResponse);

      // Act
      const result = await strategy.handle(mockRequest);

      // Assert
      expect(global.fetch).toHaveBeenCalledWith(mockRequest);
      expect(result).toBe(networkResponse);
      expect(console.log).toHaveBeenCalledWith('[SW] NetworkOnly: fetching', mockRequest.url);
    });

    it('should never cache responses', async () => {
      // Arrange
      const networkResponse = createMockResponse({ data: 'test' });
      global.fetch.mockResolvedValue(networkResponse);

      // Act
      await strategy.handle(mockRequest);

      // Assert
      expect(mockCache.put).not.toHaveBeenCalled();
    });

    it('should return offline fallback for navigation requests when network fails', async () => {
      // Arrange
      const navRequest = createMockRequest('https://example.com/page', { mode: 'navigate' });
      global.fetch.mockRejectedValue(new Error('Network error'));
      global.caches.match.mockResolvedValue(undefined); // No offline.html

      // Act
      const result = await strategy.handle(navRequest);

      // Assert
      expect(result.status).toBe(503);
      const body = await result.text();
      expect(body).toContain('Offline');
      expect(console.error).toHaveBeenCalledWith('[SW] NetworkOnly failed:', 'Network error');
    });

    it('should return JSON error for non-navigation requests when network fails', async () => {
      // Arrange
      global.fetch.mockRejectedValue(new Error('Network error'));

      // Act
      const result = await strategy.handle(mockRequest);

      // Assert
      expect(result.status).toBe(503);
      expect(result.statusText).toBe('Service Unavailable');
      const body = await result.json();
      expect(body).toEqual({ error: 'Network unavailable' });
      expect(result.headers.get('Content-Type')).toBe('application/json');
    });

    it('should not use cache even if available', async () => {
      // Arrange
      const cachedResponse = createMockResponse('cached');
      mockCache.match.mockResolvedValue(cachedResponse);

      const networkResponse = createMockResponse('network');
      global.fetch.mockResolvedValue(networkResponse);

      // Act
      const result = await strategy.handle(mockRequest);

      // Assert
      expect(result).toBe(networkResponse);
      expect(mockCache.match).not.toHaveBeenCalled();
    });

    it('should handle successful responses with various status codes', async () => {
      // Arrange
      const createdResponse = createMockResponse({ id: 1 }, { status: 201 });
      global.fetch.mockResolvedValue(createdResponse);

      // Act
      const result = await strategy.handle(mockRequest);

      // Assert
      expect(result.status).toBe(201);
      expect(result).toBe(createdResponse);
    });
  });

  describe('cacheResponse()', () => {
    it('should do nothing (override to prevent caching)', async () => {
      // Arrange
      const response = createMockResponse('test');

      // Act
      await strategy.cacheResponse(mockRequest, response);

      // Assert
      expect(mockCache.put).not.toHaveBeenCalled();
    });
  });

  describe('constructor()', () => {
    it('should accept cache name and options', () => {
      // Arrange & Act
      const customStrategy = new NetworkOnlyStrategy('custom-cache', {
        timeout: 5000,
        maxAge: 3600
      });

      // Assert
      expect(customStrategy.cacheName).toBe('custom-cache');
      expect(customStrategy.timeout).toBe(5000);
      expect(customStrategy.maxAge).toBe(3600);
    });

    it('should use default options if not provided', () => {
      // Arrange & Act
      const defaultStrategy = new NetworkOnlyStrategy('test-cache');

      // Assert
      expect(defaultStrategy.timeout).toBe(3000);
      expect(defaultStrategy.maxAge).toBe(86400);
    });
  });
});
