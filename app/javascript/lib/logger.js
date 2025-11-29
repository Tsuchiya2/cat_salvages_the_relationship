/**
 * Logger - Client-side structured logging with buffering
 * Buffers logs and sends them in batches to the backend
 */
import { getCurrentTraceId } from './tracing.js';

export class Logger {
  constructor(options = {}) {
    this.buffer = [];
    this.maxBufferSize = options.maxBufferSize || 50;
    this.flushInterval = options.flushInterval || 30000; // 30 seconds
    this.endpoint = options.endpoint || '/api/client_logs';
    this.debugMode = options.debug || false;

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
   * Log an error message
   * @param {string} message - Log message
   * @param {Object} context - Additional context
   */
  error(message, context = {}) {
    this._log('error', message, context);
  }

  /**
   * Log a warning message
   * @param {string} message - Log message
   * @param {Object} context - Additional context
   */
  warn(message, context = {}) {
    this._log('warn', message, context);
  }

  /**
   * Log an info message
   * @param {string} message - Log message
   * @param {Object} context - Additional context
   */
  info(message, context = {}) {
    this._log('info', message, context);
  }

  /**
   * Log a debug message
   * @param {string} message - Log message
   * @param {Object} context - Additional context
   */
  debug(message, context = {}) {
    this._log('debug', message, context);
  }

  /**
   * Internal log method
   * @private
   */
  _log(level, message, context) {
    const entry = {
      level,
      message,
      context: {
        ...context,
        timestamp: new Date().toISOString()
      },
      url: typeof window !== 'undefined' ? window.location.href : null,
      trace_id: getCurrentTraceId()
    };

    // Mirror to console in development
    if (this.debugMode) {
      const consoleFn = console[level] || console.log;
      consoleFn(`[${level.toUpperCase()}]`, message, context);
    }

    this.buffer.push(entry);

    // Auto-flush if buffer is full
    if (this.buffer.length >= this.maxBufferSize) {
      this.flush();
    }
  }

  /**
   * Flush buffered logs to backend
   * @param {boolean} useBeacon - Use sendBeacon for reliable delivery
   */
  async flush(useBeacon = false) {
    if (this.buffer.length === 0) {
      return;
    }

    const logs = [...this.buffer];
    this.buffer = [];

    const payload = JSON.stringify({ logs });

    try {
      if (useBeacon && navigator.sendBeacon) {
        // Use sendBeacon for page unload (more reliable)
        const blob = new Blob([payload], { type: 'application/json' });
        navigator.sendBeacon(this.endpoint, blob);
      } else {
        // Normal fetch for regular flushes
        const response = await fetch(this.endpoint, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': this._getCsrfToken()
          },
          body: payload
        });

        if (!response.ok) {
          // Retry once on failure
          console.warn('[Logger] Flush failed, retrying...');
          await this._retry(logs);
        }
      }
    } catch (error) {
      console.warn('[Logger] Flush error:', error.message);
      // Put logs back in buffer for next attempt
      this.buffer = [...logs, ...this.buffer].slice(0, this.maxBufferSize);
    }
  }

  /**
   * Retry sending logs once
   * @private
   */
  async _retry(logs) {
    try {
      await fetch(this.endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this._getCsrfToken()
        },
        body: JSON.stringify({ logs })
      });
    } catch (error) {
      console.warn('[Logger] Retry failed:', error.message);
    }
  }

  /**
   * Get CSRF token from meta tag (Rails convention)
   * @private
   */
  _getCsrfToken() {
    if (typeof document === 'undefined') {
      return '';
    }
    const meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.content : '';
  }

  /**
   * Stop the logger and clear timer
   */
  destroy() {
    if (this.flushTimer) {
      clearInterval(this.flushTimer);
    }
    this.flush(true);
  }
}

// Export singleton instance
export const logger = new Logger({
  debug: typeof window !== 'undefined' && window.location.hostname === 'localhost'
});
