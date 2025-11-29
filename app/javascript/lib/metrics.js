import { getCurrentTraceId } from './tracing.js';

/**
 * Metrics - Client-side metrics collection with buffering
 * Collects and batches metrics for backend transmission
 */
export class Metrics {
  constructor(options = {}) {
    this.buffer = [];
    this.maxBufferSize = options.maxBufferSize || 100;
    this.flushInterval = options.flushInterval || 60000; // 60 seconds
    this.endpoint = options.endpoint || '/api/metrics';

    // Start periodic flush
    this.flushTimer = setInterval(() => this.flush(), this.flushInterval);

    // Flush on page unload
    if (typeof window !== 'undefined') {
      window.addEventListener('beforeunload', () => this.flush(true));
      window.addEventListener('visibilitychange', () => {
        if (document.visibilityState === 'hidden') {
          this.flush(true);
        }
      });
    }
  }

  /**
   * Record a metric
   * @param {string} name - Metric name
   * @param {number} value - Metric value
   * @param {Object} options - Additional options (unit, tags)
   */
  record(name, value, options = {}) {
    const entry = {
      name,
      value,
      unit: options.unit || 'count',
      tags: options.tags || {},
      trace_id: getCurrentTraceId(),
      timestamp: new Date().toISOString()
    };

    this.buffer.push(entry);

    // Auto-flush if buffer is full
    if (this.buffer.length >= this.maxBufferSize) {
      this.flush();
    }
  }

  /**
   * Increment a counter metric
   * @param {string} name - Metric name
   * @param {Object} tags - Optional tags
   */
  increment(name, tags = {}) {
    this.record(name, 1, { unit: 'count', tags });
  }

  /**
   * Record a timing metric
   * @param {string} name - Metric name
   * @param {number} duration - Duration in milliseconds
   * @param {Object} tags - Optional tags
   */
  timing(name, duration, tags = {}) {
    this.record(name, duration, { unit: 'ms', tags });
  }

  /**
   * Record a gauge metric
   * @param {string} name - Metric name
   * @param {number} value - Current value
   * @param {Object} tags - Optional tags
   */
  gauge(name, value, tags = {}) {
    this.record(name, value, { unit: 'gauge', tags });
  }

  /**
   * Measure execution time of a function
   * @param {string} name - Metric name
   * @param {Function} fn - Function to measure
   * @param {Object} tags - Optional tags
   * @returns {*} Result of the function
   */
  async measure(name, fn, tags = {}) {
    const start = performance.now();
    try {
      return await fn();
    } finally {
      const duration = performance.now() - start;
      this.timing(name, duration, tags);
    }
  }

  /**
   * Flush buffered metrics to backend
   * @param {boolean} useBeacon - Use sendBeacon for reliable delivery
   */
  async flush(useBeacon = false) {
    if (this.buffer.length === 0) {
      return;
    }

    const metrics = [...this.buffer];
    this.buffer = [];

    const payload = JSON.stringify({ metrics });

    try {
      if (useBeacon && navigator.sendBeacon) {
        const blob = new Blob([payload], { type: 'application/json' });
        navigator.sendBeacon(this.endpoint, blob);
      } else {
        const response = await fetch(this.endpoint, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          },
          body: payload
        });

        if (!response.ok) {
          console.warn('[Metrics] Flush failed:', response.status);
        }
      }
    } catch (error) {
      console.warn('[Metrics] Flush error:', error.message);
      // Put metrics back in buffer for next attempt
      this.buffer = [...metrics, ...this.buffer].slice(0, this.maxBufferSize);
    }
  }

  /**
   * Stop the metrics collector and clear timer
   */
  destroy() {
    if (this.flushTimer) {
      clearInterval(this.flushTimer);
    }
    this.flush(true);
  }
}

// Export singleton instance
export const metrics = new Metrics();

// Pre-defined metric helpers for common PWA metrics
export const pwaMetrics = {
  serviceWorkerRegistered: (tags = {}) => metrics.increment('service_worker_registration', tags),
  serviceWorkerFailed: (tags = {}) => metrics.increment('service_worker_registration_failed', tags),
  cacheHit: (cacheName) => metrics.increment('cache_hit', { cache_name: cacheName }),
  cacheMiss: (cacheName) => metrics.increment('cache_miss', { cache_name: cacheName }),
  installPromptShown: () => metrics.increment('install_prompt_shown'),
  installPromptAccepted: () => metrics.increment('install_prompt_accepted'),
  installPromptDismissed: () => metrics.increment('install_prompt_dismissed'),
  appInstalled: () => metrics.increment('app_installed')
};
