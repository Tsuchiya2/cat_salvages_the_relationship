import { CacheFirstStrategy } from './strategies/cache_first_strategy.js';
import { NetworkFirstStrategy } from './strategies/network_first_strategy.js';
import { NetworkOnlyStrategy } from './strategies/network_only_strategy.js';

/**
 * StrategyRouter - Routes fetch requests to appropriate caching strategies
 * Matches URL patterns to determine which strategy to use
 */
export class StrategyRouter {
  /**
   * @param {Object} config - Configuration object from ConfigLoader
   */
  constructor(config) {
    this.config = config;
    this.strategies = [];
    this.version = config.version || 'v1';
    this.initializeStrategies(config);
  }

  /**
   * Initialize strategy instances from configuration
   * @param {Object} config - Configuration object
   */
  initializeStrategies(config) {
    const cacheConfig = config.cache || {};

    // Process each cache configuration
    for (const [name, settings] of Object.entries(cacheConfig)) {
      const cacheName = `${name}-${this.version}`;
      const strategyClass = this.getStrategyClass(settings.strategy);
      const options = {
        timeout: settings.timeout || config.network?.timeout || 3000,
        maxAge: settings.max_age || 86400
      };

      const strategy = new strategyClass(cacheName, options);

      // Convert pattern strings to RegExp
      const patterns = (settings.patterns || []).map(pattern => {
        try {
          return new RegExp(pattern);
        } catch (e) {
          console.warn('[SW] Invalid pattern:', pattern);
          return null;
        }
      }).filter(Boolean);

      this.strategies.push({
        name,
        patterns,
        strategy
      });
    }

    console.log('[SW] Initialized strategies:', this.strategies.map(s => s.name));
  }

  /**
   * Get strategy class by name
   * @param {string} strategyName - Strategy name (cache-first, network-first, network-only)
   * @returns {Function} Strategy class constructor
   */
  getStrategyClass(strategyName) {
    const strategyMap = {
      'cache-first': CacheFirstStrategy,
      'network-first': NetworkFirstStrategy,
      'network-only': NetworkOnlyStrategy
    };

    return strategyMap[strategyName] || NetworkFirstStrategy;
  }

  /**
   * Handle a fetch event by routing to appropriate strategy
   * @param {FetchEvent} event - The fetch event
   * @returns {Promise<Response>} The response from the strategy
   */
  async handleFetch(event) {
    const request = event.request;
    const url = new URL(request.url);

    // Skip non-GET requests
    if (request.method !== 'GET') {
      return fetch(request);
    }

    // Skip cross-origin requests (except for allowed CDNs)
    if (url.origin !== self.location.origin) {
      return fetch(request);
    }

    // Find matching strategy
    const matched = this.findStrategy(url.pathname);

    if (matched) {
      console.log('[SW] Using strategy:', matched.name, 'for', url.pathname);
      return matched.strategy.handle(request);
    }

    // No match - use default network fetch
    console.log('[SW] No strategy match, using network:', url.pathname);
    return fetch(request);
  }

  /**
   * Find a strategy that matches the URL
   * @param {string} pathname - URL pathname to match
   * @returns {Object|null} Matched strategy object or null
   */
  findStrategy(pathname) {
    for (const strategyConfig of this.strategies) {
      for (const pattern of strategyConfig.patterns) {
        if (pattern.test(pathname)) {
          return strategyConfig;
        }
      }
    }
    return null;
  }

  /**
   * Get all registered strategy names
   * @returns {string[]} Array of strategy names
   */
  getStrategyNames() {
    return this.strategies.map(s => s.name);
  }
}
