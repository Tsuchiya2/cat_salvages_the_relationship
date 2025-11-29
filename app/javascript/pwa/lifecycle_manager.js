/**
 * LifecycleManager - Service Worker Lifecycle Management
 * Handles install/activate events, cache initialization, and cleanup
 */
export class LifecycleManager {
  /**
   * @param {Object} config - Configuration object
   * @param {string} config.version - Cache version (e.g., "v1")
   * @param {string[]} config.precacheUrls - URLs to pre-cache during install
   */
  constructor(config) {
    this.version = config.version || 'v1';
    this.precacheUrls = config.precacheUrls || ['/offline.html'];
    this.cacheNames = {
      static: `static-${this.version}`,
      images: `images-${this.version}`,
      pages: `pages-${this.version}`
    };
  }

  /**
   * Handle service worker install event
   * Pre-caches critical assets and offline page
   * @returns {Promise<void>}
   */
  async handleInstall() {
    console.log('[SW] Installing service worker...');

    try {
      const cache = await caches.open(this.cacheNames.static);

      // Pre-cache critical assets
      const urlsToCache = [
        '/',
        '/offline.html',
        ...this.precacheUrls
      ];

      // Filter out duplicates
      const uniqueUrls = [...new Set(urlsToCache)];

      await cache.addAll(uniqueUrls);
      console.log('[SW] Pre-cached critical assets:', uniqueUrls);

      // Activate immediately (skip waiting)
      await self.skipWaiting();
      console.log('[SW] Skip waiting - activating immediately');
    } catch (error) {
      console.error('[SW] Install failed:', error);
      throw error;
    }
  }

  /**
   * Handle service worker activate event
   * Cleans up old caches and claims clients
   * @returns {Promise<void>}
   */
  async handleActivate() {
    console.log('[SW] Activating service worker...');

    try {
      // Get all cache names
      const cacheKeys = await caches.keys();
      const currentCacheNames = Object.values(this.cacheNames);

      // Delete old caches (not in current version)
      const deletePromises = cacheKeys
        .filter(key => !currentCacheNames.includes(key))
        .map(key => {
          console.log('[SW] Deleting old cache:', key);
          return caches.delete(key);
        });

      await Promise.all(deletePromises);

      // Claim all clients immediately
      await self.clients.claim();
      console.log('[SW] Claimed all clients');
    } catch (error) {
      console.error('[SW] Activate failed:', error);
      throw error;
    }
  }

  /**
   * Get cache name for a specific type
   * @param {string} type - Cache type (static, images, pages)
   * @returns {string} Cache name with version
   */
  getCacheName(type) {
    return this.cacheNames[type] || `${type}-${this.version}`;
  }

  /**
   * Get all current cache names
   * @returns {string[]} Array of current cache names
   */
  getAllCacheNames() {
    return Object.values(this.cacheNames);
  }
}
