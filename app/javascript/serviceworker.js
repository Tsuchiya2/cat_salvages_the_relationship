/**
 * Service Worker Entry Point
 * ReLINE PWA Service Worker
 */

import { ConfigLoader } from './pwa/config_loader.js';
import { LifecycleManager } from './pwa/lifecycle_manager.js';
import { StrategyRouter } from './pwa/strategy_router.js';

// Global instances
let config = null;
let lifecycleManager = null;
let strategyRouter = null;

/**
 * Initialize the service worker with configuration
 * @returns {Promise<void>}
 */
async function initialize() {
  if (config) {
    return; // Already initialized
  }

  console.log('[SW] Initializing service worker...');

  // Load configuration
  config = await ConfigLoader.load();

  // Initialize managers
  lifecycleManager = new LifecycleManager({
    version: config.version,
    precacheUrls: ['/', '/offline.html']
  });

  strategyRouter = new StrategyRouter(config);

  console.log('[SW] Service worker initialized with version:', config.version);
}

// ============================================
// Install Event
// ============================================
self.addEventListener('install', (event) => {
  console.log('[SW] Install event triggered');

  event.waitUntil(
    (async () => {
      try {
        await initialize();
        await lifecycleManager.handleInstall();
        console.log('[SW] Install completed successfully');
      } catch (error) {
        console.error('[SW] Install failed:', error);
        throw error;
      }
    })()
  );
});

// ============================================
// Activate Event
// ============================================
self.addEventListener('activate', (event) => {
  console.log('[SW] Activate event triggered');

  event.waitUntil(
    (async () => {
      try {
        await initialize();
        await lifecycleManager.handleActivate();
        console.log('[SW] Activate completed successfully');
      } catch (error) {
        console.error('[SW] Activate failed:', error);
        throw error;
      }
    })()
  );
});

// ============================================
// Fetch Event
// ============================================
self.addEventListener('fetch', (event) => {
  // Skip if not initialized yet
  if (!strategyRouter) {
    return;
  }

  // Handle the fetch through strategy router
  event.respondWith(
    (async () => {
      try {
        return await strategyRouter.handleFetch(event);
      } catch (error) {
        console.error('[SW] Fetch handling failed:', error);
        // Return a basic error response
        return new Response('Service Worker Error', {
          status: 500,
          statusText: 'Internal Error'
        });
      }
    })()
  );
});

// ============================================
// Message Event (for future use)
// ============================================
self.addEventListener('message', (event) => {
  console.log('[SW] Message received:', event.data);

  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});

console.log('[SW] Service worker script loaded');
