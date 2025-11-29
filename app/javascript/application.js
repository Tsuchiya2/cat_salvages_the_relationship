// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "./controllers"
import * as bootstrap from "bootstrap"
import '@fortawesome/fontawesome-free/js/all'
import "./scroll.js"

// PWA Service Worker Registration
import { initServiceWorker } from './pwa/service_worker_registration.js';

// PWA Install Prompt Manager
import { initInstallPrompt } from './pwa/install_prompt_manager.js';

// Register service worker after page load
if ('serviceWorker' in navigator) {
  initServiceWorker();
}

// Initialize install prompt manager
initInstallPrompt();
