import { CacheStrategy } from './base_strategy.js';

/**
 * NetworkFirstStrategy - Network First Caching Strategy
 * Tries network first with timeout, falls back to cache
 * Best for: HTML pages that change frequently
 */
export class NetworkFirstStrategy extends CacheStrategy {
  /**
   * Handle a fetch request with network-first strategy
   * @param {Request} request - The fetch request
   * @returns {Promise<Response>} The response (from network or cache)
   */
  async handle(request) {
    try {
      // 1. Try network first with timeout
      console.log('[SW] NetworkFirst: fetching', request.url);
      const networkResponse = await this.fetchWithTimeout(request, this.timeout);

      // 2. Cache the successful network response
      await this.cacheResponse(request, networkResponse);

      return networkResponse;
    } catch (error) {
      console.warn('[SW] Network failed:', error.message);

      // 3. Network failed - try cache
      const cachedResponse = await this.getCached(request);

      if (cachedResponse) {
        console.log('[SW] Serving from cache:', request.url);
        return cachedResponse;
      }

      // 4. No cache - return offline fallback
      console.log('[SW] No cache, serving fallback');
      return this.getFallback();
    }
  }
}
