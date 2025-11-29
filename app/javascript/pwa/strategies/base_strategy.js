/**
 * CacheStrategy - Abstract Base Class for Caching Strategies
 * Provides common methods for cache operations
 * Subclasses must implement the handle() method
 */
export class CacheStrategy {
  /**
   * @param {string} cacheName - Name of the cache to use
   * @param {Object} options - Strategy options
   * @param {number} options.timeout - Network timeout in milliseconds
   * @param {number} options.maxAge - Maximum cache age in seconds
   */
  constructor(cacheName, options = {}) {
    this.cacheName = cacheName;
    this.timeout = options.timeout || 3000;
    this.maxAge = options.maxAge || 86400; // 24 hours default

    if (this.constructor === CacheStrategy) {
      throw new Error('CacheStrategy is an abstract class and cannot be instantiated directly');
    }
  }

  /**
   * Handle a fetch request - MUST be implemented by subclasses
   * @param {Request} request - The fetch request to handle
   * @returns {Promise<Response>} The response
   * @abstract
   */
  async handle(request) {
    throw new Error('handle() method must be implemented by subclass');
  }

  /**
   * Cache a response for a given request
   * @param {Request} request - The original request
   * @param {Response} response - The response to cache
   * @returns {Promise<void>}
   */
  async cacheResponse(request, response) {
    if (!this.shouldCache(response)) {
      return;
    }

    try {
      const cache = await caches.open(this.cacheName);
      // Clone the response because it can only be consumed once
      await cache.put(request, response.clone());
      console.log('[SW] Cached:', request.url);
    } catch (error) {
      console.warn('[SW] Failed to cache:', request.url, error.message);
    }
  }

  /**
   * Check if a response should be cached
   * @param {Response} response - The response to validate
   * @returns {boolean} True if response should be cached
   */
  shouldCache(response) {
    // Only cache successful responses
    if (!response || response.status !== 200) {
      return false;
    }

    // Don't cache opaque responses (cross-origin without CORS)
    if (response.type === 'opaque') {
      return false;
    }

    // Only cache basic (same-origin) or CORS responses
    if (response.type !== 'basic' && response.type !== 'cors') {
      return false;
    }

    return true;
  }

  /**
   * Fetch with timeout using AbortController
   * @param {Request} request - The request to fetch
   * @param {number} timeout - Timeout in milliseconds (defaults to this.timeout)
   * @returns {Promise<Response>} The fetch response
   * @throws {Error} If fetch times out or fails
   */
  async fetchWithTimeout(request, timeout = this.timeout) {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeout);

    try {
      const response = await fetch(request, {
        signal: controller.signal
      });
      return response;
    } catch (error) {
      if (error.name === 'AbortError') {
        throw new Error(`Request timed out after ${timeout}ms`);
      }
      throw error;
    } finally {
      clearTimeout(timeoutId);
    }
  }

  /**
   * Get the offline fallback page from cache
   * @returns {Promise<Response>} The offline.html response or minimal fallback
   */
  async getFallback() {
    try {
      // Try to get offline.html from any cache
      const offlineResponse = await caches.match('/offline.html');
      if (offlineResponse) {
        console.log('[SW] Serving offline fallback');
        return offlineResponse;
      }
    } catch (error) {
      console.warn('[SW] Failed to get offline fallback:', error.message);
    }

    // Return minimal fallback if offline.html not available
    return new Response(
      '<!DOCTYPE html><html><head><meta charset="utf-8"><title>Offline</title></head><body><h1>Offline</h1><p>You are currently offline.</p></body></html>',
      {
        status: 503,
        statusText: 'Service Unavailable',
        headers: {
          'Content-Type': 'text/html; charset=utf-8'
        }
      }
    );
  }

  /**
   * Get a cached response for a request
   * @param {Request} request - The request to match
   * @returns {Promise<Response|undefined>} The cached response or undefined
   */
  async getCached(request) {
    try {
      const cache = await caches.open(this.cacheName);
      return await cache.match(request);
    } catch (error) {
      console.warn('[SW] Cache read error:', error.message);
      return undefined;
    }
  }
}
