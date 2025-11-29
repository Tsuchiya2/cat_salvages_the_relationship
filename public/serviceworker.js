(() => {
  var __defProp = Object.defineProperty;
  var __defNormalProp = (obj, key, value) => key in obj ? __defProp(obj, key, { enumerable: true, configurable: true, writable: true, value }) : obj[key] = value;
  var __publicField = (obj, key, value) => __defNormalProp(obj, typeof key !== "symbol" ? key + "" : key, value);

  // app/javascript/pwa/config_loader.js
  var ConfigLoader = class {
    /**
     * Load PWA configuration from backend API
     * Falls back to defaults if API request fails
     * @returns {Promise<Object>} Configuration object
     */
    static async load() {
      try {
        const response = await fetch(this.CONFIG_URL, {
          method: "GET",
          headers: {
            "Accept": "application/json"
          }
        });
        if (!response.ok) {
          throw new Error(`Config API returned ${response.status}`);
        }
        const config2 = await response.json();
        console.log("[SW] Loaded config from API:", config2.version);
        return config2;
      } catch (error) {
        console.warn("[SW] Failed to load config from API, using defaults:", error.message);
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
        version: "v1",
        cache: {
          static: {
            strategy: "cache-first",
            patterns: ["\\.(?:css|js|woff2?)$"],
            max_age: 86400
          },
          images: {
            strategy: "cache-first",
            patterns: ["\\.(?:png|jpg|jpeg|gif|webp|svg|ico)$"],
            max_age: 604800
          },
          pages: {
            strategy: "network-first",
            patterns: ["^/$", "^/terms$", "^/privacy_policy$"],
            timeout: 3e3
          },
          api: {
            strategy: "network-only",
            patterns: ["^/api/", "^/operator/"]
          }
        },
        network: {
          timeout: 3e3,
          retries: 1
        },
        manifest: {
          theme_color: "#0d6efd",
          background_color: "#ffffff"
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
    static get(config2, path, defaultValue = null) {
      const keys = path.split(".");
      let value = config2;
      for (const key of keys) {
        if (value === null || value === void 0 || typeof value !== "object") {
          return defaultValue;
        }
        value = value[key];
      }
      return value !== void 0 ? value : defaultValue;
    }
  };
  __publicField(ConfigLoader, "CONFIG_URL", "/api/pwa/config");

  // app/javascript/pwa/lifecycle_manager.js
  var LifecycleManager = class {
    /**
     * @param {Object} config - Configuration object
     * @param {string} config.version - Cache version (e.g., "v1")
     * @param {string[]} config.precacheUrls - URLs to pre-cache during install
     */
    constructor(config2) {
      this.version = config2.version || "v1";
      this.precacheUrls = config2.precacheUrls || ["/offline.html"];
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
      console.log("[SW] Installing service worker...");
      try {
        const cache = await caches.open(this.cacheNames.static);
        const urlsToCache = [
          "/",
          "/offline.html",
          ...this.precacheUrls
        ];
        const uniqueUrls = [...new Set(urlsToCache)];
        await cache.addAll(uniqueUrls);
        console.log("[SW] Pre-cached critical assets:", uniqueUrls);
        await self.skipWaiting();
        console.log("[SW] Skip waiting - activating immediately");
      } catch (error) {
        console.error("[SW] Install failed:", error);
        throw error;
      }
    }
    /**
     * Handle service worker activate event
     * Cleans up old caches and claims clients
     * @returns {Promise<void>}
     */
    async handleActivate() {
      console.log("[SW] Activating service worker...");
      try {
        const cacheKeys = await caches.keys();
        const currentCacheNames = Object.values(this.cacheNames);
        const deletePromises = cacheKeys.filter((key) => !currentCacheNames.includes(key)).map((key) => {
          console.log("[SW] Deleting old cache:", key);
          return caches.delete(key);
        });
        await Promise.all(deletePromises);
        await self.clients.claim();
        console.log("[SW] Claimed all clients");
      } catch (error) {
        console.error("[SW] Activate failed:", error);
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
  };

  // app/javascript/pwa/strategies/base_strategy.js
  var CacheStrategy = class _CacheStrategy {
    /**
     * @param {string} cacheName - Name of the cache to use
     * @param {Object} options - Strategy options
     * @param {number} options.timeout - Network timeout in milliseconds
     * @param {number} options.maxAge - Maximum cache age in seconds
     */
    constructor(cacheName, options = {}) {
      this.cacheName = cacheName;
      this.timeout = options.timeout || 3e3;
      this.maxAge = options.maxAge || 86400;
      if (this.constructor === _CacheStrategy) {
        throw new Error("CacheStrategy is an abstract class and cannot be instantiated directly");
      }
    }
    /**
     * Handle a fetch request - MUST be implemented by subclasses
     * @param {Request} request - The fetch request to handle
     * @returns {Promise<Response>} The response
     * @abstract
     */
    async handle(request) {
      throw new Error("handle() method must be implemented by subclass");
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
        await cache.put(request, response.clone());
        console.log("[SW] Cached:", request.url);
      } catch (error) {
        console.warn("[SW] Failed to cache:", request.url, error.message);
      }
    }
    /**
     * Check if a response should be cached
     * @param {Response} response - The response to validate
     * @returns {boolean} True if response should be cached
     */
    shouldCache(response) {
      if (!response || response.status !== 200) {
        return false;
      }
      if (response.type === "opaque") {
        return false;
      }
      if (response.type !== "basic" && response.type !== "cors") {
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
        if (error.name === "AbortError") {
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
        const offlineResponse = await caches.match("/offline.html");
        if (offlineResponse) {
          console.log("[SW] Serving offline fallback");
          return offlineResponse;
        }
      } catch (error) {
        console.warn("[SW] Failed to get offline fallback:", error.message);
      }
      return new Response(
        '<!DOCTYPE html><html><head><meta charset="utf-8"><title>Offline</title></head><body><h1>Offline</h1><p>You are currently offline.</p></body></html>',
        {
          status: 503,
          statusText: "Service Unavailable",
          headers: {
            "Content-Type": "text/html; charset=utf-8"
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
        console.warn("[SW] Cache read error:", error.message);
        return void 0;
      }
    }
  };

  // app/javascript/pwa/strategies/cache_first_strategy.js
  var CacheFirstStrategy = class extends CacheStrategy {
    /**
     * Handle a fetch request with cache-first strategy
     * @param {Request} request - The fetch request
     * @returns {Promise<Response>} The response (from cache or network)
     */
    async handle(request) {
      try {
        const cachedResponse = await this.getCached(request);
        if (cachedResponse) {
          console.log("[SW] Cache hit:", request.url);
          this.updateCacheInBackground(request);
          return cachedResponse;
        }
        console.log("[SW] Cache miss, fetching:", request.url);
        const networkResponse = await fetch(request);
        await this.cacheResponse(request, networkResponse);
        return networkResponse;
      } catch (error) {
        console.error("[SW] CacheFirst error:", error.message);
        const cachedResponse = await this.getCached(request);
        if (cachedResponse) {
          return cachedResponse;
        }
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
          console.log("[SW] Background cache update:", request.url);
        }
      } catch (error) {
        console.log("[SW] Background update failed (ok):", request.url);
      }
    }
  };

  // app/javascript/pwa/strategies/network_first_strategy.js
  var NetworkFirstStrategy = class extends CacheStrategy {
    /**
     * Handle a fetch request with network-first strategy
     * @param {Request} request - The fetch request
     * @returns {Promise<Response>} The response (from network or cache)
     */
    async handle(request) {
      try {
        console.log("[SW] NetworkFirst: fetching", request.url);
        const networkResponse = await this.fetchWithTimeout(request, this.timeout);
        await this.cacheResponse(request, networkResponse);
        return networkResponse;
      } catch (error) {
        console.warn("[SW] Network failed:", error.message);
        const cachedResponse = await this.getCached(request);
        if (cachedResponse) {
          console.log("[SW] Serving from cache:", request.url);
          return cachedResponse;
        }
        console.log("[SW] No cache, serving fallback");
        return this.getFallback();
      }
    }
  };

  // app/javascript/pwa/strategies/network_only_strategy.js
  var NetworkOnlyStrategy = class extends CacheStrategy {
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
        console.log("[SW] NetworkOnly: fetching", request.url);
        const response = await fetch(request);
        return response;
      } catch (error) {
        console.error("[SW] NetworkOnly failed:", error.message);
        if (request.mode === "navigate") {
          return this.getFallback();
        }
        return new Response(
          JSON.stringify({ error: "Network unavailable" }),
          {
            status: 503,
            statusText: "Service Unavailable",
            headers: {
              "Content-Type": "application/json"
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
      return;
    }
  };

  // app/javascript/pwa/strategy_router.js
  var StrategyRouter = class {
    /**
     * @param {Object} config - Configuration object from ConfigLoader
     */
    constructor(config2) {
      this.config = config2;
      this.strategies = [];
      this.version = config2.version || "v1";
      this.initializeStrategies(config2);
    }
    /**
     * Initialize strategy instances from configuration
     * @param {Object} config - Configuration object
     */
    initializeStrategies(config2) {
      const cacheConfig = config2.cache || {};
      for (const [name, settings] of Object.entries(cacheConfig)) {
        const cacheName = `${name}-${this.version}`;
        const strategyClass = this.getStrategyClass(settings.strategy);
        const options = {
          timeout: settings.timeout || config2.network?.timeout || 3e3,
          maxAge: settings.max_age || 86400
        };
        const strategy = new strategyClass(cacheName, options);
        const patterns = (settings.patterns || []).map((pattern) => {
          try {
            return new RegExp(pattern);
          } catch (e) {
            console.warn("[SW] Invalid pattern:", pattern);
            return null;
          }
        }).filter(Boolean);
        this.strategies.push({
          name,
          patterns,
          strategy
        });
      }
      console.log("[SW] Initialized strategies:", this.strategies.map((s) => s.name));
    }
    /**
     * Get strategy class by name
     * @param {string} strategyName - Strategy name (cache-first, network-first, network-only)
     * @returns {Function} Strategy class constructor
     */
    getStrategyClass(strategyName) {
      const strategyMap = {
        "cache-first": CacheFirstStrategy,
        "network-first": NetworkFirstStrategy,
        "network-only": NetworkOnlyStrategy
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
      if (request.method !== "GET") {
        return fetch(request);
      }
      if (url.origin !== self.location.origin) {
        return fetch(request);
      }
      const matched = this.findStrategy(url.pathname);
      if (matched) {
        console.log("[SW] Using strategy:", matched.name, "for", url.pathname);
        return matched.strategy.handle(request);
      }
      console.log("[SW] No strategy match, using network:", url.pathname);
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
      return this.strategies.map((s) => s.name);
    }
  };

  // app/javascript/serviceworker.js
  var config = null;
  var lifecycleManager = null;
  var strategyRouter = null;
  async function initialize() {
    if (config) {
      return;
    }
    console.log("[SW] Initializing service worker...");
    config = await ConfigLoader.load();
    lifecycleManager = new LifecycleManager({
      version: config.version,
      precacheUrls: ["/", "/offline.html"]
    });
    strategyRouter = new StrategyRouter(config);
    console.log("[SW] Service worker initialized with version:", config.version);
  }
  self.addEventListener("install", (event) => {
    console.log("[SW] Install event triggered");
    event.waitUntil(
      (async () => {
        try {
          await initialize();
          await lifecycleManager.handleInstall();
          console.log("[SW] Install completed successfully");
        } catch (error) {
          console.error("[SW] Install failed:", error);
          throw error;
        }
      })()
    );
  });
  self.addEventListener("activate", (event) => {
    console.log("[SW] Activate event triggered");
    event.waitUntil(
      (async () => {
        try {
          await initialize();
          await lifecycleManager.handleActivate();
          console.log("[SW] Activate completed successfully");
        } catch (error) {
          console.error("[SW] Activate failed:", error);
          throw error;
        }
      })()
    );
  });
  self.addEventListener("fetch", (event) => {
    if (!strategyRouter) {
      return;
    }
    event.respondWith(
      (async () => {
        try {
          return await strategyRouter.handleFetch(event);
        } catch (error) {
          console.error("[SW] Fetch handling failed:", error);
          return new Response("Service Worker Error", {
            status: 500,
            statusText: "Internal Error"
          });
        }
      })()
    );
  });
  self.addEventListener("message", (event) => {
    console.log("[SW] Message received:", event.data);
    if (event.data && event.data.type === "SKIP_WAITING") {
      self.skipWaiting();
    }
  });
  console.log("[SW] Service worker script loaded");
})();
//# sourceMappingURL=serviceworker.js.map
