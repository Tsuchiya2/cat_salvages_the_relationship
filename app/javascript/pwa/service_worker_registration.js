/**
 * ServiceWorkerRegistration - Handles service worker registration and lifecycle
 */
import { logger } from '../lib/logger.js';
import { pwaMetrics } from '../lib/metrics.js';

export class ServiceWorkerRegistration {
  constructor() {
    this.registration = null;
    this.updateAvailable = false;
  }

  /**
   * Register the service worker
   * Should be called after DOMContentLoaded
   * @returns {Promise<ServiceWorkerRegistration|null>}
   */
  async register() {
    // Check if service workers are supported
    if (!('serviceWorker' in navigator)) {
      logger.warn('Service workers are not supported in this browser');
      return null;
    }

    try {
      logger.info('Registering service worker...');

      this.registration = await navigator.serviceWorker.register('/serviceworker.js', {
        scope: '/'
      });

      logger.info('Service worker registered successfully', {
        scope: this.registration.scope
      });

      pwaMetrics.serviceWorkerRegistered();

      // Set up lifecycle event handlers
      this.setupLifecycleHandlers();

      return this.registration;
    } catch (error) {
      logger.error('Service worker registration failed', {
        error: error.message
      });
      pwaMetrics.serviceWorkerFailed({ error: error.message });
      return null;
    }
  }

  /**
   * Set up service worker lifecycle event handlers
   * @private
   */
  setupLifecycleHandlers() {
    if (!this.registration) return;

    // Handle new service worker installing
    this.registration.addEventListener('updatefound', () => {
      const newWorker = this.registration.installing;
      logger.info('New service worker found, installing...');

      if (newWorker) {
        newWorker.addEventListener('statechange', () => {
          this.handleStateChange(newWorker);
        });
      }
    });

    // Handle controller change (new SW took over)
    navigator.serviceWorker.addEventListener('controllerchange', () => {
      logger.info('Service worker controller changed');
      // Optionally reload the page when new SW takes control
      // window.location.reload();
    });
  }

  /**
   * Handle service worker state changes
   * @param {ServiceWorker} worker - The service worker instance
   * @private
   */
  handleStateChange(worker) {
    logger.info('Service worker state changed', { state: worker.state });

    switch (worker.state) {
      case 'installed':
        if (navigator.serviceWorker.controller) {
          // New update available
          this.updateAvailable = true;
          logger.info('New service worker installed, update available');
          this.notifyUpdateAvailable();
        } else {
          // First install
          logger.info('Service worker installed for the first time');
        }
        break;
      case 'activated':
        logger.info('Service worker activated');
        break;
      case 'redundant':
        logger.warn('Service worker became redundant');
        break;
    }
  }

  /**
   * Notify that an update is available
   * Can be customized to show UI notification
   * @private
   */
  notifyUpdateAvailable() {
    // Dispatch custom event for UI components to listen
    if (typeof window !== 'undefined') {
      window.dispatchEvent(new CustomEvent('swUpdateAvailable', {
        detail: { registration: this.registration }
      }));
    }
  }

  /**
   * Skip waiting and activate new service worker
   * Call this when user confirms update
   */
  async applyUpdate() {
    if (this.registration && this.registration.waiting) {
      this.registration.waiting.postMessage({ type: 'SKIP_WAITING' });
    }
  }

  /**
   * Check if service worker is active
   * @returns {boolean}
   */
  isActive() {
    return !!(this.registration && this.registration.active);
  }

  /**
   * Get current service worker state
   * @returns {string|null}
   */
  getState() {
    if (!this.registration) return null;
    if (this.registration.active) return this.registration.active.state;
    if (this.registration.waiting) return 'waiting';
    if (this.registration.installing) return 'installing';
    return null;
  }
}

// Export singleton instance
export const swRegistration = new ServiceWorkerRegistration();

/**
 * Initialize service worker registration
 * Call this function on page load
 */
export async function initServiceWorker() {
  // Wait for DOM to be ready
  if (document.readyState === 'loading') {
    await new Promise(resolve => {
      document.addEventListener('DOMContentLoaded', resolve);
    });
  }

  return swRegistration.register();
}
