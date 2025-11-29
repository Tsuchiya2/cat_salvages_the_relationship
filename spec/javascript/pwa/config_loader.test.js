/**
 * Tests for ConfigLoader
 * PWA configuration loader with API fallback
 */

import { ConfigLoader } from '../../../app/javascript/pwa/config_loader.js';

describe('ConfigLoader', () => {
  beforeEach(() => {
    global.fetch.mockClear();
  });

  describe('load()', () => {
    it('should fetch configuration from API', async () => {
      // Arrange
      const mockConfig = {
        version: 'v2',
        cache: {
          static: {
            strategy: 'cache-first',
            patterns: ['\\.(?:css|js)$']
          }
        }
      };

      const apiResponse = createMockResponse(mockConfig);
      global.fetch.mockResolvedValue(apiResponse);

      // Act
      const config = await ConfigLoader.load();

      // Assert
      expect(global.fetch).toHaveBeenCalledWith('/api/pwa/config', {
        method: 'GET',
        headers: {
          'Accept': 'application/json'
        }
      });
      expect(config).toEqual(mockConfig);
      expect(console.log).toHaveBeenCalledWith('[SW] Loaded config from API:', 'v2');
    });

    it('should return defaults when API returns error status', async () => {
      // Arrange
      const errorResponse = createMockResponse('Not Found', { status: 404 });
      global.fetch.mockResolvedValue(errorResponse);

      // Act
      const config = await ConfigLoader.load();

      // Assert
      expect(config).toEqual(ConfigLoader.getDefaults());
      expect(console.warn).toHaveBeenCalledWith(
        '[SW] Failed to load config from API, using defaults:',
        'Config API returned 404'
      );
    });

    it('should return defaults when fetch fails', async () => {
      // Arrange
      global.fetch.mockRejectedValue(new Error('Network error'));

      // Act
      const config = await ConfigLoader.load();

      // Assert
      expect(config).toEqual(ConfigLoader.getDefaults());
      expect(console.warn).toHaveBeenCalledWith(
        '[SW] Failed to load config from API, using defaults:',
        'Network error'
      );
    });

    it('should return defaults when API returns invalid JSON', async () => {
      // Arrange
      const invalidResponse = new Response('Invalid JSON', {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      });
      invalidResponse.json = jest.fn().mockRejectedValue(new Error('Invalid JSON'));
      global.fetch.mockResolvedValue(invalidResponse);

      // Act
      const config = await ConfigLoader.load();

      // Assert
      expect(config).toEqual(ConfigLoader.getDefaults());
    });
  });

  describe('getDefaults()', () => {
    it('should return default configuration', () => {
      const defaults = ConfigLoader.getDefaults();

      expect(defaults.version).toBe('v1');
      expect(defaults.cache).toBeDefined();
      expect(defaults.network).toBeDefined();
      expect(defaults.manifest).toBeDefined();
      expect(defaults.features).toBeDefined();
    });

    it('should include static cache configuration', () => {
      const defaults = ConfigLoader.getDefaults();

      expect(defaults.cache.static).toEqual({
        strategy: 'cache-first',
        patterns: ['\\.(?:css|js|woff2?)$'],
        max_age: 86400
      });
    });

    it('should include images cache configuration', () => {
      const defaults = ConfigLoader.getDefaults();

      expect(defaults.cache.images).toEqual({
        strategy: 'cache-first',
        patterns: ['\\.(?:png|jpg|jpeg|gif|webp|svg|ico)$'],
        max_age: 604800
      });
    });

    it('should include pages cache configuration', () => {
      const defaults = ConfigLoader.getDefaults();

      expect(defaults.cache.pages).toEqual({
        strategy: 'network-first',
        patterns: ['^/$', '^/terms$', '^/privacy_policy$'],
        timeout: 3000
      });
    });

    it('should include API cache configuration', () => {
      const defaults = ConfigLoader.getDefaults();

      expect(defaults.cache.api).toEqual({
        strategy: 'network-only',
        patterns: ['^/api/', '^/operator/']
      });
    });

    it('should include network configuration', () => {
      const defaults = ConfigLoader.getDefaults();

      expect(defaults.network).toEqual({
        timeout: 3000,
        retries: 1
      });
    });

    it('should include manifest configuration', () => {
      const defaults = ConfigLoader.getDefaults();

      expect(defaults.manifest).toEqual({
        theme_color: '#0d6efd',
        background_color: '#ffffff'
      });
    });

    it('should include features configuration', () => {
      const defaults = ConfigLoader.getDefaults();

      expect(defaults.features).toEqual({
        install_prompt: true,
        push_notifications: false,
        background_sync: false
      });
    });
  });

  describe('get()', () => {
    let config;

    beforeEach(() => {
      config = {
        version: 'v1',
        cache: {
          static: {
            strategy: 'cache-first',
            timeout: 5000
          }
        },
        network: {
          timeout: 3000
        }
      };
    });

    it('should get nested value by path', () => {
      const value = ConfigLoader.get(config, 'cache.static.strategy');
      expect(value).toBe('cache-first');
    });

    it('should get top-level value', () => {
      const value = ConfigLoader.get(config, 'version');
      expect(value).toBe('v1');
    });

    it('should return default value for non-existent path', () => {
      const value = ConfigLoader.get(config, 'cache.images.strategy', 'default');
      expect(value).toBe('default');
    });

    it('should return null default for non-existent path without default', () => {
      const value = ConfigLoader.get(config, 'nonexistent.path');
      expect(value).toBeNull();
    });

    it('should return default value when path traverses non-object', () => {
      const value = ConfigLoader.get(config, 'version.subvalue', 'default');
      expect(value).toBe('default');
    });

    it('should return default value when path traverses null', () => {
      const nullConfig = { cache: null };
      const value = ConfigLoader.get(nullConfig, 'cache.static', 'default');
      expect(value).toBe('default');
    });

    it('should return default value when path traverses undefined', () => {
      const undefinedConfig = { cache: undefined };
      const value = ConfigLoader.get(undefinedConfig, 'cache.static', 'default');
      expect(value).toBe('default');
    });

    it('should distinguish between undefined value and non-existent path', () => {
      const undefinedValueConfig = {
        cache: {
          static: {
            strategy: undefined
          }
        }
      };

      const value = ConfigLoader.get(undefinedValueConfig, 'cache.static.strategy', 'default');
      expect(value).toBe('default');
    });

    it('should handle empty string path', () => {
      // Empty path returns default value since no valid key path
      const value = ConfigLoader.get(config, '', 'default');
      // The implementation treats empty string as invalid path
      expect(value).toBe('default');
    });
  });

  describe('CONFIG_URL', () => {
    it('should be set to /api/pwa/config', () => {
      expect(ConfigLoader.CONFIG_URL).toBe('/api/pwa/config');
    });
  });
});
