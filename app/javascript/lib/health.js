/**
 * HealthCheck - PWA Health Diagnostics
 * Checks service worker, cache, and network status
 */
export class HealthCheck {
  constructor() {
    this.lastCheck = null;
    this.cachedReport = null;
    this.cacheTimeout = 30000; // 30 seconds
  }

  /**
   * Check service worker registration status
   * @returns {Promise<Object>} Service worker status
   */
  async checkServiceWorker() {
    const result = {
      supported: 'serviceWorker' in navigator,
      registered: false,
      state: null,
      scriptURL: null
    };

    if (!result.supported) {
      return result;
    }

    try {
      const registration = await navigator.serviceWorker.getRegistration();
      if (registration) {
        result.registered = true;
        result.scriptURL = registration.active?.scriptURL ||
                          registration.waiting?.scriptURL ||
                          registration.installing?.scriptURL;
        result.state = registration.active?.state ||
                      registration.waiting?.state ||
                      registration.installing?.state || 'unknown';
      }
    } catch (error) {
      result.error = error.message;
    }

    return result;
  }

  /**
   * Check cache storage status
   * @returns {Promise<Object>} Cache status
   */
  async checkCaches() {
    const result = {
      available: 'caches' in self,
      caches: [],
      totalSize: 0,
      estimatedQuota: 0,
      estimatedUsage: 0
    };

    if (!result.available) {
      return result;
    }

    try {
      // Get cache names
      const cacheNames = await caches.keys();
      result.caches = cacheNames;

      // Get storage estimate if available
      if (navigator.storage && navigator.storage.estimate) {
        const estimate = await navigator.storage.estimate();
        result.estimatedQuota = estimate.quota || 0;
        result.estimatedUsage = estimate.usage || 0;
        result.totalSize = estimate.usage || 0;
      }
    } catch (error) {
      result.error = error.message;
    }

    return result;
  }

  /**
   * Check network status
   * @returns {Object} Network status
   */
  checkNetwork() {
    const result = {
      online: navigator.onLine,
      connectionType: null,
      effectiveType: null,
      downlink: null,
      rtt: null
    };

    // Network Information API (if available)
    if (navigator.connection) {
      result.connectionType = navigator.connection.type || null;
      result.effectiveType = navigator.connection.effectiveType || null;
      result.downlink = navigator.connection.downlink || null;
      result.rtt = navigator.connection.rtt || null;
    }

    return result;
  }

  /**
   * Get full health report
   * Caches results for 30 seconds to avoid excessive checks
   * @param {boolean} [force=false] - Force fresh check
   * @returns {Promise<Object>} Full health report
   */
  async getReport(force = false) {
    const now = Date.now();

    // Return cached report if still valid
    if (!force && this.cachedReport && this.lastCheck &&
        (now - this.lastCheck) < this.cacheTimeout) {
      return this.cachedReport;
    }

    const [serviceWorker, caches, network] = await Promise.all([
      this.checkServiceWorker(),
      this.checkCaches(),
      Promise.resolve(this.checkNetwork())
    ]);

    // Determine overall status
    const checks = {
      serviceWorker: serviceWorker.registered && serviceWorker.state === 'activated',
      caches: caches.available && caches.caches.length > 0,
      network: network.online
    };

    const overallStatus = Object.values(checks).every(Boolean) ? 'healthy' :
                         Object.values(checks).some(Boolean) ? 'degraded' : 'unhealthy';

    this.cachedReport = {
      timestamp: new Date().toISOString(),
      overall_status: overallStatus,
      checks: {
        service_worker: { status: checks.serviceWorker ? 'pass' : 'fail', details: serviceWorker },
        caches: { status: checks.caches ? 'pass' : 'fail', details: caches },
        network: { status: checks.network ? 'pass' : 'fail', details: network }
      }
    };

    this.lastCheck = now;
    return this.cachedReport;
  }

  /**
   * Clear cached report
   */
  clearCache() {
    this.cachedReport = null;
    this.lastCheck = null;
  }
}

// Export singleton instance
export const healthCheck = new HealthCheck();

// Expose to window for console debugging
if (typeof window !== 'undefined') {
  window.PWA = window.PWA || {};
  window.PWA.checkHealth = () => healthCheck.getReport(true);
}
