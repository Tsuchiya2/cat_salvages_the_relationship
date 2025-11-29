/**
 * Tests for NetworkFirstStrategy
 * Network-first strategy: tries network with timeout, falls back to cache
 */

import { NetworkFirstStrategy } from '../../../../app/javascript/pwa/strategies/network_first_strategy.js';

describe('NetworkFirstStrategy', () => {
  let strategy;
  let mockCache;
  let mockRequest;

  beforeEach(() => {
    // Set up strategy instance
    strategy = new NetworkFirstStrategy('test-cache', {
      timeout: 1000,
      maxAge: 86400
    });

    // Set up mock cache
    mockCache = setupCacheMock();

    // Create mock request
    mockRequest = createMockRequest('https://example.com/page.html');
  });

  describe('handle()', () => {
    it('should fetch from network first', async () => {
      // Arrange
      const networkResponse = createMockResponse('network content');
      global.fetch.mockResolvedValue(networkResponse);

      // Act
      const result = await strategy.handle(mockRequest);

      // Assert
      expect(global.fetch).toHaveBeenCalledWith(
        mockRequest,
        expect.objectContaining({ signal: expect.any(Object) })
      );
      expect(result).toBe(networkResponse);
      expect(console.log).toHaveBeenCalledWith('[SW] NetworkFirst: fetching', mockRequest.url);
    });

    it('should cache successful network response', async () => {
      // Arrange
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
      expect(console.log).toHaveBeenCalledWith('[SW] Serving from cache:', mockRequest.url);
    });

    it('should fall back to cache on timeout', async () => {
      // Arrange
      const cachedResponse = createMockResponse('cached content');
      mockCache.match.mockResolvedValue(cachedResponse);

      // Simulate timeout
      global.fetch.mockImplementation(() => {
        return new Promise((resolve, reject) => {
          setTimeout(() => {
            const abortError = new Error('Aborted');
            abortError.name = 'AbortError';
            reject(abortError);
          }, 50);
        });
      });

      // Act
      const result = await strategy.handle(mockRequest);

      // Assert
      expect(result).toBe(cachedResponse);
      expect(console.warn).toHaveBeenCalledWith(
        '[SW] Network failed:',
        expect.stringContaining('timed out')
      );
    });

    it('should return offline fallback when network fails and no cache', async () => {
      // Arrange
      global.fetch.mockRejectedValue(new Error('Network error'));
      mockCache.match.mockResolvedValue(undefined);
      global.caches.match.mockResolvedValue(undefined); // No offline.html

      // Act
      const result = await strategy.handle(mockRequest);

      // Assert
      expect(result.status).toBe(503);
      expect(console.log).toHaveBeenCalledWith('[SW] No cache, serving fallback');
    });

    it('should use custom timeout value', async () => {
      // Arrange
      const customStrategy = new NetworkFirstStrategy('test-cache', {
        timeout: 100
      });

      // Simulate timeout by throwing AbortError
      global.fetch.mockImplementation(() => {
        return new Promise((resolve, reject) => {
          const abortError = new Error('Request timed out after 100ms');
          abortError.name = 'AbortError';
          reject(abortError);
        });
      });

      const cachedResponse = createMockResponse('cached content');
      mockCache.match.mockResolvedValue(cachedResponse);

      // Act
      const result = await customStrategy.handle(mockRequest);

      // Assert - should timeout and use cache
      expect(result).toEqual(cachedResponse);
    }, 1000);

    it('should not cache error responses', async () => {
      // Arrange
      const errorResponse = createMockResponse('Error', { status: 500 });
      global.fetch.mockResolvedValue(errorResponse);

      // Act
      await strategy.handle(mockRequest);

      // Assert
      expect(mockCache.put).not.toHaveBeenCalled();
    });
  });

  describe('fetchWithTimeout()', () => {
    it('should abort request on timeout', async () => {
      // Arrange
      global.fetch.mockImplementation(() => {
        return new Promise((resolve, reject) => {
          // Simulate a long-running request
          setTimeout(() => {
            const abortError = new Error('Aborted');
            abortError.name = 'AbortError';
            reject(abortError);
          }, 50);
        });
      });

      // Act & Assert
      await expect(strategy.fetchWithTimeout(mockRequest, 100)).rejects.toThrow('timed out');
    }, 1000);

    it('should clear timeout on successful fetch', async () => {
      // Arrange
      const clearTimeoutSpy = jest.spyOn(global, 'clearTimeout');
      const response = createMockResponse('success');
      global.fetch.mockResolvedValue(response);

      // Act
      await strategy.fetchWithTimeout(mockRequest);

      // Assert
      expect(clearTimeoutSpy).toHaveBeenCalled();

      // Cleanup
      clearTimeoutSpy.mockRestore();
    });

    it('should rethrow non-timeout errors', async () => {
      // Arrange
      const networkError = new Error('DNS error');
      global.fetch.mockRejectedValue(networkError);

      // Act & Assert
      await expect(strategy.fetchWithTimeout(mockRequest)).rejects.toThrow('DNS error');
    });
  });
});
