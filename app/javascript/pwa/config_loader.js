/**
 * ConfigLoader - PWA Configuration Loader
 * Fetches configuration from backend API with fallback defaults
 */
export class ConfigLoader {
  static CONFIG_URL = '/api/pwa/config';

  /**
   * Load PWA configuration from backend API
   * Falls back to defaults if API request fails
   * @returns {Promise<Object>} Configuration object
   */
  static async load() {
    try {
      const response = await fetch(this.CONFIG_URL, {
        method: 'GET',
        headers: {
          'Accept': 'application/json'
        }
      });

      if (!response.ok) {
        throw new Error(`Config API returned ${response.status}`);
      }

      const config = await response.json();
      console.log('[SW] Loaded config from API:', config.version);
      return config;
    } catch (error) {
      console.warn('[SW] Failed to load config from API, using defaults:', error.message);
      return this.getDefaults();
    }
  }

  /**
   * Get default configuration (fallback)
   * Used when API is unavailable or returns error
   * @returns {Object} Default configuration object
   */
  static getDefaults() {
    return {
      version: 'v1',
      cache: {
        static: {
          strategy: 'cache-first',
          patterns: ['\\.(?:css|js|woff2?)$'],
          max_age: 86400
        },
        images: {
          strategy: 'cache-first',
          patterns: ['\\.(?:png|jpg|jpeg|gif|webp|svg|ico)$'],
          max_age: 604800
        },
        pages: {
          strategy: 'network-first',
          patterns: ['^/$', '^/terms$', '^/privacy_policy$'],
          timeout: 3000
        },
        api: {
          strategy: 'network-only',
          patterns: ['^/api/', '^/operator/']
        }
      },
      network: {
        timeout: 3000,
        retries: 1
      },
      manifest: {
        theme_color: '#0d6efd',
        background_color: '#ffffff'
      },
      features: {
        install_prompt: true,
        push_notifications: false,
        background_sync: false
      }
    };
  }

  /**
   * Get configuration value by path
   * @param {Object} config - Configuration object
   * @param {string} path - Dot-separated path (e.g., 'cache.static.strategy')
   * @param {*} defaultValue - Default value if path not found
   * @returns {*} Configuration value
   */
  static get(config, path, defaultValue = null) {
    const keys = path.split('.');
    let value = config;

    for (const key of keys) {
      if (value === null || value === undefined || typeof value !== 'object') {
        return defaultValue;
      }
      value = value[key];
    }

    return value !== undefined ? value : defaultValue;
  }
}
