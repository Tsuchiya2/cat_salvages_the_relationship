import { CacheStrategy } from './base_strategy.js';

/**
 * CacheFirstStrategy - Cache First Caching Strategy
 * Serves from cache first, falls back to network if not cached
 * Best for: Static assets (CSS, JS, fonts, images)
 */
export class CacheFirstStrategy extends CacheStrategy {
  /**
   * Handle a fetch request with cache-first strategy
   * @param {Request} request - The fetch request
   * @returns {Promise<Response>} The response (from cache or network)
   */
  async handle(request) {
    try {
      // 1. Try to get from cache first
      const cachedResponse = await this.getCached(request);

      if (cachedResponse) {
        console.log('[SW] Cache hit:', request.url);
        // Update cache in background (stale-while-revalidate style)
        this.updateCacheInBackground(request);
        return cachedResponse;
      }

      // 2. Cache miss - fetch from network
      console.log('[SW] Cache miss, fetching:', request.url);
      const networkResponse = await fetch(request);

      // 3. Cache the network response
      await this.cacheResponse(request, networkResponse);

      return networkResponse;
    } catch (error) {
      console.error('[SW] CacheFirst error:', error.message);

      // Try to return cached response even on error
      const cachedResponse = await this.getCached(request);
      if (cachedResponse) {
        return cachedResponse;
      }

      // Last resort: return offline fallback
      return this.getFallback();
    }
  }

  /**
   * Update cache in background after serving cached response
   * This keeps the cache fresh without blocking the response
   * @param {Request} request - The original request
   */
  async updateCacheInBackground(request) {
    try {
      const networkResponse = await fetch(request);
      if (this.shouldCache(networkResponse)) {
        await this.cacheResponse(request, networkResponse);
        console.log('[SW] Background cache update:', request.url);
      }
    } catch (error) {
      // Silently fail - we already served from cache
      console.log('[SW] Background update failed (ok):', request.url);
    }
  }
}
