/**
 * Tests for LifecycleManager
 * Service Worker lifecycle management
 */

import { LifecycleManager } from '../../../app/javascript/pwa/lifecycle_manager.js';

describe('LifecycleManager', () => {
  let manager;
  let mockCache;

  beforeEach(() => {
    manager = new LifecycleManager({
      version: 'v2',
      precacheUrls: ['/offline.html', '/assets/app.js', '/assets/app.css']
    });

    mockCache = setupCacheMock();
  });

  describe('constructor()', () => {
    it('should initialize with config', () => {
      expect(manager.version).toBe('v2');
      expect(manager.precacheUrls).toEqual(['/offline.html', '/assets/app.js', '/assets/app.css']);
    });

    it('should use default version if not provided', () => {
      const defaultManager = new LifecycleManager({});
      expect(defaultManager.version).toBe('v1');
    });

    it('should use default precacheUrls if not provided', () => {
      const defaultManager = new LifecycleManager({});
      expect(defaultManager.precacheUrls).toEqual(['/offline.html']);
    });

    it('should create cache names with version', () => {
      expect(manager.cacheNames.static).toBe('static-v2');
      expect(manager.cacheNames.images).toBe('images-v2');
      expect(manager.cacheNames.pages).toBe('pages-v2');
    });
  });

  describe('handleInstall()', () => {
    it('should pre-cache critical assets', async () => {
      // Arrange
      const expectedUrls = [
        '/',
        '/offline.html',
        '/assets/app.js',
        '/assets/app.css'
      ];

      // Act
      await manager.handleInstall();

      // Assert
      expect(global.caches.open).toHaveBeenCalledWith('static-v2');
      expect(mockCache.addAll).toHaveBeenCalledWith(expectedUrls);
      expect(console.log).toHaveBeenCalledWith(
        '[SW] Pre-cached critical assets:',
        expectedUrls
      );
    });

    it('should remove duplicate URLs before caching', async () => {
      // Arrange
      manager.precacheUrls = ['/', '/offline.html', '/']; // Duplicate '/'

      // Act
      await manager.handleInstall();

      // Assert
      const cachedUrls = mockCache.addAll.mock.calls[0][0];
      expect(cachedUrls.filter(url => url === '/')).toHaveLength(1);
    });

    it('should call skipWaiting', async () => {
      // Act
      await manager.handleInstall();

      // Assert
      expect(global.self.skipWaiting).toHaveBeenCalled();
      expect(console.log).toHaveBeenCalledWith('[SW] Skip waiting - activating immediately');
    });

    it('should log install start', async () => {
      // Act
      await manager.handleInstall();

      // Assert
      expect(console.log).toHaveBeenCalledWith('[SW] Installing service worker...');
    });

    it('should throw error on cache failure', async () => {
      // Arrange
      const cacheError = new Error('Cache quota exceeded');
      mockCache.addAll.mockRejectedValue(cacheError);

      // Act & Assert
      await expect(manager.handleInstall()).rejects.toThrow('Cache quota exceeded');
      expect(console.error).toHaveBeenCalledWith('[SW] Install failed:', cacheError);
    });

    it('should handle skipWaiting errors', async () => {
      // Arrange
      global.self.skipWaiting.mockRejectedValue(new Error('skipWaiting failed'));

      // Act & Assert
      await expect(manager.handleInstall()).rejects.toThrow('skipWaiting failed');
    });
  });

  describe('handleActivate()', () => {
    it('should delete old caches', async () => {
      // Arrange
      global.caches.keys.mockResolvedValue([
        'static-v1',   // old
        'static-v2',   // current
        'images-v1',   // old
        'images-v2',   // current
        'pages-v2',    // current
        'other-cache'  // old
      ]);

      // Act
      await manager.handleActivate();

      // Assert
      expect(global.caches.delete).toHaveBeenCalledWith('static-v1');
      expect(global.caches.delete).toHaveBeenCalledWith('images-v1');
      expect(global.caches.delete).toHaveBeenCalledWith('other-cache');
      expect(global.caches.delete).not.toHaveBeenCalledWith('static-v2');
      expect(global.caches.delete).not.toHaveBeenCalledWith('images-v2');
      expect(global.caches.delete).not.toHaveBeenCalledWith('pages-v2');
    });

    it('should log deleted cache names', async () => {
      // Arrange
      global.caches.keys.mockResolvedValue(['old-cache-v1']);

      // Act
      await manager.handleActivate();

      // Assert
      expect(console.log).toHaveBeenCalledWith('[SW] Deleting old cache:', 'old-cache-v1');
    });

    it('should claim all clients', async () => {
      // Arrange
      global.caches.keys.mockResolvedValue([]);

      // Act
      await manager.handleActivate();

      // Assert
      expect(global.self.clients.claim).toHaveBeenCalled();
      expect(console.log).toHaveBeenCalledWith('[SW] Claimed all clients');
    });

    it('should log activation start', async () => {
      // Arrange
      global.caches.keys.mockResolvedValue([]);

      // Act
      await manager.handleActivate();

      // Assert
      expect(console.log).toHaveBeenCalledWith('[SW] Activating service worker...');
    });

    it('should handle activation errors', async () => {
      // Arrange
      const activateError = new Error('Activation failed');
      global.caches.keys.mockRejectedValue(activateError);

      // Act & Assert
      await expect(manager.handleActivate()).rejects.toThrow('Activation failed');
      expect(console.error).toHaveBeenCalledWith('[SW] Activate failed:', activateError);
    });

    it('should not delete any caches if all are current', async () => {
      // Arrange
      global.caches.keys.mockResolvedValue(['static-v2', 'images-v2', 'pages-v2']);

      // Act
      await manager.handleActivate();

      // Assert
      expect(global.caches.delete).not.toHaveBeenCalled();
    });
  });

  describe('getCacheName()', () => {
    it('should return cache name with version for known types', () => {
      expect(manager.getCacheName('static')).toBe('static-v2');
      expect(manager.getCacheName('images')).toBe('images-v2');
      expect(manager.getCacheName('pages')).toBe('pages-v2');
    });

    it('should return generated cache name for unknown types', () => {
      expect(manager.getCacheName('custom')).toBe('custom-v2');
    });
  });

  describe('getAllCacheNames()', () => {
    it('should return all current cache names', () => {
      const names = manager.getAllCacheNames();
      expect(names).toEqual(['static-v2', 'images-v2', 'pages-v2']);
    });

    it('should return array with all cache names', () => {
      const names = manager.getAllCacheNames();
      expect(Array.isArray(names)).toBe(true);
      expect(names).toHaveLength(3);
    });
  });
});
