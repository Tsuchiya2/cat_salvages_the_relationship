/**
 * Tests for CacheFirstStrategy
 * Cache-first strategy: serves from cache, falls back to network
 */

import { CacheFirstStrategy } from '../../../../app/javascript/pwa/strategies/cache_first_strategy.js';

describe('CacheFirstStrategy', () => {
  let strategy;
  let mockCache;
  let mockRequest;

  beforeEach(() => {
    // Set up strategy instance
    strategy = new CacheFirstStrategy('test-cache', {
      timeout: 1000,
      maxAge: 86400
    });

    // Set up mock cache
    mockCache = setupCacheMock();

    // Create mock request
    mockRequest = createMockRequest('https://example.com/test.js');
  });

  describe('handle()', () => {
    it('should serve from cache when available (cache hit)', async () => {
      // Arrange
      const cachedResponse = createMockResponse('cached content');
      mockCache.match.mockResolvedValue(cachedResponse);

      // Act
      const result = await strategy.handle(mockRequest);

      // Assert
      expect(result).toBe(cachedResponse);
      expect(mockCache.match).toHaveBeenCalledWith(mockRequest);
      expect(console.log).toHaveBeenCalledWith('[SW] Cache hit:', mockRequest.url);
    });

    it('should fetch from network when cache miss', async () => {
      // Arrange
      mockCache.match.mockResolvedValue(undefined);
      const networkResponse = createMockResponse('network content');
      global.fetch.mockResolvedValue(networkResponse);

      // Act
      const result = await strategy.handle(mockRequest);

      // Assert
      expect(mockCache.match).toHaveBeenCalledWith(mockRequest);
      expect(global.fetch).toHaveBeenCalledWith(mockRequest);
      expect(result).toBe(networkResponse);
      expect(console.log).toHaveBeenCalledWith('[SW] Cache miss, fetching:', mockRequest.url);
    });

    it('should cache network response after fetch', async () => {
      // Arrange
      mockCache.match.mockResolvedValue(undefined);
      const networkResponse = createMockResponse('network content');
      global.fetch.mockResolvedValue(networkResponse);

      // Act
      await strategy.handle(mockRequest);

      // Assert
      expect(mockCache.put).toHaveBeenCalledWith(
        mockRequest,
        expect.any(Response)
      );
      expect(console.log).toHaveBeenCalledWith('[SW] Cached:', mockRequest.url);
    });

    it('should update cache in background when serving from cache', async () => {
      // Arrange
      const cachedResponse = createMockResponse('cached content');
      mockCache.match.mockResolvedValue(cachedResponse);
      const networkResponse = createMockResponse('new content');
      global.fetch.mockResolvedValue(networkResponse);

      // Act
      await strategy.handle(mockRequest);

      // Wait for background update
      await new Promise(resolve => setTimeout(resolve, 100));

      // Assert
      expect(global.fetch).toHaveBeenCalledWith(mockRequest);
      expect(console.log).toHaveBeenCalledWith('[SW] Background cache update:', mockRequest.url);
    });

    it('should return cached response on network error', async () => {
      // Arrange
      const cachedResponse = createMockResponse('cached content');
      mockCache.match
        .mockResolvedValueOnce(undefined) // First call: cache miss
        .mockResolvedValueOnce(cachedResponse); // Second call: error recovery

      global.fetch.mockRejectedValue(new Error('Network error'));

      // Act
      const result = await strategy.handle(mockRequest);

      // Assert
      expect(result).toBe(cachedResponse);
      expect(console.error).toHaveBeenCalledWith(
        '[SW] CacheFirst error:',
        'Network error'
      );
    });

    it('should return offline fallback when no cache and network fails', async () => {
      // Arrange
      mockCache.match.mockResolvedValue(undefined);
      global.fetch.mockRejectedValue(new Error('Network error'));
      global.caches.match.mockResolvedValue(undefined); // No offline.html

      // Act
      const result = await strategy.handle(mockRequest);

      // Assert
      expect(result.status).toBe(503);
      expect(result.statusText).toBe('Service Unavailable');
      const body = await result.text();
      expect(body).toContain('Offline');
    });

    it('should not cache responses with status !== 200', async () => {
      // Arrange
      mockCache.match.mockResolvedValue(undefined);
      const errorResponse = createMockResponse('Not Found', { status: 404 });
      global.fetch.mockResolvedValue(errorResponse);

      // Act
      await strategy.handle(mockRequest);

      // Assert
      expect(mockCache.put).not.toHaveBeenCalled();
    });

    it('should not cache opaque responses', async () => {
      // Arrange
      mockCache.match.mockResolvedValue(undefined);
      const opaqueResponse = createMockResponse('opaque', { type: 'opaque' });
      global.fetch.mockResolvedValue(opaqueResponse);

      // Act
      await strategy.handle(mockRequest);

      // Assert
      expect(mockCache.put).not.toHaveBeenCalled();
    });
  });

  describe('updateCacheInBackground()', () => {
    it('should silently fail on background update errors', async () => {
      // Arrange
      global.fetch.mockRejectedValue(new Error('Network error'));

      // Act & Assert - should not throw
      await expect(strategy.updateCacheInBackground(mockRequest)).resolves.toBeUndefined();
      expect(console.log).toHaveBeenCalledWith(
        '[SW] Background update failed (ok):',
        mockRequest.url
      );
    });

    it('should not cache invalid responses in background', async () => {
      // Arrange
      const errorResponse = createMockResponse('Error', { status: 500 });
      global.fetch.mockResolvedValue(errorResponse);

      // Act
      await strategy.updateCacheInBackground(mockRequest);

      // Assert
      expect(mockCache.put).not.toHaveBeenCalled();
    });
  });

  describe('cacheResponse()', () => {
    it('should clone response before caching', async () => {
      // Arrange
      const response = createMockResponse('test content');
      const cloneSpy = jest.spyOn(response, 'clone');

      // Act
      await strategy.cacheResponse(mockRequest, response);

      // Assert
      expect(cloneSpy).toHaveBeenCalled();
    });

    it('should handle cache errors gracefully', async () => {
      // Arrange
      const response = createMockResponse('test content');
      mockCache.put.mockRejectedValue(new Error('Cache full'));

      // Act & Assert - should not throw
      await expect(strategy.cacheResponse(mockRequest, response)).resolves.toBeUndefined();
      expect(console.warn).toHaveBeenCalledWith(
        '[SW] Failed to cache:',
        mockRequest.url,
        'Cache full'
      );
    });
  });
});
