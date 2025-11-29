import { CacheStrategy } from './base_strategy.js';

/**
 * NetworkOnlyStrategy - Network Only Strategy
 * Always fetches from network, never caches
 * Best for: Authenticated routes, dynamic APIs, operator dashboard
 */
export class NetworkOnlyStrategy extends CacheStrategy {
  /**
   * @param {string} cacheName - Cache name (unused but required for consistency)
   * @param {Object} options - Strategy options
   */
  constructor(cacheName, options = {}) {
    super(cacheName, options);
  }

  /**
   * Handle a fetch request with network-only strategy
   * @param {Request} request - The fetch request
   * @returns {Promise<Response>} The response (from network only)
   */
  async handle(request) {
    try {
      // Always fetch from network - no caching
      console.log('[SW] NetworkOnly: fetching', request.url);
      const response = await fetch(request);
      return response;
    } catch (error) {
      console.error('[SW] NetworkOnly failed:', error.message);

      // Network failed - return offline fallback for navigation requests
      if (request.mode === 'navigate') {
        return this.getFallback();
      }

      // For non-navigation requests, return error response
      return new Response(
        JSON.stringify({ error: 'Network unavailable' }),
        {
          status: 503,
          statusText: 'Service Unavailable',
          headers: {
            'Content-Type': 'application/json'
          }
        }
      );
    }
  }

  /**
   * Override cacheResponse to do nothing (network-only never caches)
   * @param {Request} request - The request
   * @param {Response} response - The response
   * @returns {Promise<void>}
   */
  async cacheResponse(request, response) {
    // Intentionally do nothing - network-only strategy
    return;
  }
}
