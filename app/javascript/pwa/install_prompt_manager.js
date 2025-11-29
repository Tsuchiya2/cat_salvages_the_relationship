import { logger } from '../lib/logger.js';
import { pwaMetrics } from '../lib/metrics.js';

/**
 * InstallPromptManager - Handles PWA install prompt lifecycle
 */
export class InstallPromptManager {
  constructor() {
    this.deferredPrompt = null;
    this.isInstalled = false;
    this.initialized = false;
  }

  /**
   * Initialize the install prompt manager
   * Sets up event listeners for beforeinstallprompt and appinstalled
   */
  init() {
    if (this.initialized) return;

    if (typeof window === 'undefined') {
      return;
    }

    // Listen for beforeinstallprompt event
    window.addEventListener('beforeinstallprompt', (event) => {
      this.handleBeforeInstallPrompt(event);
    });

    // Listen for appinstalled event
    window.addEventListener('appinstalled', () => {
      this.handleAppInstalled();
    });

    // Check if already installed (standalone mode)
    if (window.matchMedia('(display-mode: standalone)').matches) {
      this.isInstalled = true;
      logger.info('App is running in standalone mode (already installed)');
    }

    this.initialized = true;
    logger.info('Install prompt manager initialized');
  }

  /**
   * Handle beforeinstallprompt event
   * Stores the event for later use
   * @param {BeforeInstallPromptEvent} event
   * @private
   */
  handleBeforeInstallPrompt(event) {
    // Prevent the mini-infobar from appearing on mobile
    event.preventDefault();

    // Store the event for later use
    this.deferredPrompt = event;

    logger.info('Install prompt available');
    pwaMetrics.installPromptShown();

    // Dispatch custom event for UI components
    window.dispatchEvent(new CustomEvent('pwaInstallAvailable', {
      detail: { prompt: this }
    }));
  }

  /**
   * Handle appinstalled event
   * Called when the app is successfully installed
   * @private
   */
  handleAppInstalled() {
    this.isInstalled = true;
    this.deferredPrompt = null;

    logger.info('App was installed successfully');
    pwaMetrics.appInstalled();

    // Dispatch custom event
    window.dispatchEvent(new CustomEvent('pwaInstalled'));
  }

  /**
   * Show the install prompt to the user
   * @returns {Promise<string>} User's choice: 'accepted' or 'dismissed'
   */
  async showInstallPrompt() {
    if (!this.deferredPrompt) {
      logger.warn('No install prompt available');
      return null;
    }

    try {
      // Show the install prompt
      this.deferredPrompt.prompt();

      // Wait for the user's choice
      const { outcome } = await this.deferredPrompt.userChoice;

      logger.info('Install prompt result', { outcome });

      if (outcome === 'accepted') {
        pwaMetrics.installPromptAccepted();
      } else {
        pwaMetrics.installPromptDismissed();
      }

      // Clear the deferred prompt (can only be used once)
      this.deferredPrompt = null;

      return outcome;
    } catch (error) {
      logger.error('Error showing install prompt', { error: error.message });
      return null;
    }
  }

  /**
   * Check if the install prompt is available
   * @returns {boolean}
   */
  canInstall() {
    return this.deferredPrompt !== null && !this.isInstalled;
  }

  /**
   * Check if the app is already installed
   * @returns {boolean}
   */
  isAppInstalled() {
    return this.isInstalled;
  }
}

// Export singleton instance
export const installPromptManager = new InstallPromptManager();

/**
 * Initialize install prompt manager
 * Call this function on page load
 */
export function initInstallPrompt() {
  installPromptManager.init();
}
