# Design Document - PWA Implementation for ReLINE

**Feature ID**: FEAT-PWA-001
**Created**: 2025-11-29
**Last Updated**: 2025-11-29
**Designer**: designer agent

---

## Metadata

```yaml
design_metadata:
  feature_id: "FEAT-PWA-001"
  feature_name: "Progressive Web App Implementation"
  created: "2025-11-29"
  updated: "2025-11-29"
  iteration: 2
  target_platform: "Rails 8.1 with Propshaft and esbuild"
```

---

## 1. Overview

### 1.1 Feature Summary

This design implements Progressive Web App (PWA) capabilities for the ReLINE application, transforming it into an installable, offline-capable web application. ReLINE is a LINE bot service that helps users maintain relationships by having a virtual "cat" send LINE messages to groups after periods of inactivity. By implementing PWA features, users will be able to install the app on their devices, access it from their home screen, and enjoy basic offline functionality.

The PWA implementation will enhance user engagement by providing a native app-like experience while maintaining the web-based architecture. This includes app installation prompts, offline page caching, and optimized asset delivery through service workers.

### 1.2 Goals and Objectives

**Primary Goals:**
- Enable "Add to Home Screen" functionality for mobile and desktop users
- Provide offline access to critical static pages (landing page, terms, privacy policy)
- Improve perceived performance through asset caching
- Achieve PWA installability criteria per Lighthouse standards

**Secondary Goals:**
- Maintain compatibility with existing Rails 8.1 Turbo/Stimulus architecture
- Minimize impact on current asset pipeline (Propshaft + esbuild)
- Ensure seamless experience for both web and installed app users

### 1.3 Success Criteria

- Lighthouse PWA audit score ≥ 90/100
- Web App Manifest correctly detected by browsers
- Service Worker successfully registers and caches assets
- Install prompt appears on supported browsers (Chrome, Edge, Safari 16.4+)
- Offline fallback page displays when network unavailable
- No regression in existing functionality (Turbo navigation, Stimulus controllers)

---

## 2. Requirements Analysis

### 2.1 Functional Requirements

**FR-1: Web App Manifest**
- Create manifest.json with complete app metadata
- Include app name, short name, description, theme colors
- Define icon set (192x192, 512x512 minimum)
- Specify start URL and display mode
- Configure scope and orientation preferences

**FR-2: Service Worker**
- Register service worker on application load
- Implement cache-first strategy for static assets (CSS, JS, images)
- Implement network-first strategy with cache fallback for HTML pages
- Provide offline fallback page for uncached routes
- Handle service worker lifecycle (install, activate, fetch)

**FR-3: App Icons**
- Generate PWA icons from existing cat.webp mascot
- Create 192x192px icon (minimum installability requirement)
- Create 512x512px icon (standard PWA requirement)
- Optional: Create maskable icons for adaptive display
- Store icons in public/pwa/ directory

**FR-4: HTML Meta Tags**
- Add viewport meta tag (already exists, verify configuration)
- Add theme-color meta tag for browser chrome customization
- Add apple-mobile-web-app-capable for iOS support
- Add apple-touch-icon references for iOS home screen
- Link manifest.json in application layout

**FR-5: Offline Support**
- Cache public static pages: root path (/), /terms, /privacy_policy, /feedbacks/new
- Cache essential assets: cat.webp, favicon.ico, compiled CSS/JS
- Display offline fallback page for uncached operator routes
- Show appropriate error message when offline actions attempted

**FR-6: Install Prompt Management**
- Listen for beforeinstallprompt event (Chrome/Edge)
- Store install prompt for deferred trigger
- Optional: Add custom "Install App" button in UI
- Handle appinstalled event for analytics tracking

### 2.2 Non-Functional Requirements

**NFR-1: Performance**
- Service worker registration must not block page load
- Cache operations must complete asynchronously
- Asset cache size should not exceed 50MB
- Cache invalidation must occur on service worker updates

**NFR-2: Browser Compatibility**
- Support Chrome 90+ (full PWA support)
- Support Edge 90+ (full PWA support)
- Support Safari 16.4+ (limited PWA support, iOS 16.4+)
- Support Firefox 90+ (service worker only, no install prompt)
- Graceful degradation for older browsers

**NFR-3: Security**
- Service worker must only run over HTTPS (or localhost in development)
- Content Security Policy must allow service worker registration
- Manifest must have correct MIME type (application/manifest+json)
- Service worker scope must be properly restricted

**NFR-4: Maintainability**
- Service worker version must be easily updatable
- Cache names must include version number for invalidation
- Clear separation between PWA assets and application assets
- Documentation for cache strategy modifications

**NFR-5: Rails Integration**
- Use Propshaft for serving manifest.json and service worker
- Leverage esbuild for service worker JavaScript if needed
- Maintain compatibility with Turbo Drive navigation
- Ensure service worker doesn't interfere with Turbo Streams

### 2.3 Constraints

**Technical Constraints:**
- Must work with Rails 8.1 Propshaft asset pipeline (no Sprockets)
- Cannot use gems that depend on Sprockets (e.g., serviceworker-rails gem)
- Service worker must be served from root domain scope
- Manifest.json must be accessible at /manifest.json

**Business Constraints:**
- Zero downtime deployment required
- Existing users must not experience disruptions
- PWA installation must be optional, not mandatory
- Development and testing must be completable on localhost

**Design Constraints:**
- Icon must feature existing cat.webp mascot for brand consistency
- Theme colors must match current Bootstrap 5 color scheme
- Offline page must maintain ReLINE branding and UX
- No introduction of heavy dependencies or frameworks

---

## 3. Architecture Design

### 3.1 System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Browser (Client)                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐         ┌─────────────────────────────┐  │
│  │   HTML Page  │────────▶│   Service Worker Thread     │  │
│  │              │         │   (serviceworker.js)        │  │
│  └──────────────┘         └─────────────────────────────┘  │
│         │                            │                      │
│         │                            ▼                      │
│         │                   ┌──────────────────┐           │
│         │                   │  Cache Storage   │           │
│         │                   │  - static-v1     │           │
│         │                   │  - pages-v1      │           │
│         │                   │  - images-v1     │           │
│         │                   └──────────────────┘           │
│         │                                                   │
│         ▼                                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         Manifest.json Metadata                       │  │
│  │  - App Name: ReLINE                                  │  │
│  │  - Icons: 192x192, 512x512                           │  │
│  │  - Theme Color: #0d6efd (Bootstrap primary)         │  │
│  │  - Start URL: /                                      │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ HTTPS Requests
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  Rails 8.1 Application                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌────────────────────────────────────────────────────┐    │
│  │          Propshaft Asset Pipeline                  │    │
│  │  - Serves /manifest.json                           │    │
│  │  - Serves /serviceworker.js (from app/assets)     │    │
│  │  - Serves PWA icons (/pwa/icon-*.png)             │    │
│  │  - Serves compiled CSS/JS bundles                  │    │
│  └────────────────────────────────────────────────────┘    │
│                                                             │
│  ┌────────────────────────────────────────────────────┐    │
│  │             Application Controllers                │    │
│  │  - PagesController (public pages)                  │    │
│  │  - OperatorControllers (protected routes)          │    │
│  │  - LINE WebhookController                          │    │
│  │  - Api::Pwa::ConfigsController (config endpoint)   │    │
│  │  - Api::MetricsController (metrics collection)     │    │
│  │  - Api::ClientLogsController (error tracking)      │    │
│  └────────────────────────────────────────────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 Component Breakdown

**Component 1: Web App Manifest (Dynamic)**
- **Location**: Generated by `ManifestsController#show`
- **Responsibility**: Provide browser with app metadata for installation
- **Dependencies**: PWA icon assets in `public/pwa/`, I18n translations
- **Configuration**: Dynamic generation based on `config/pwa_config.yml` and environment variables
- **Extensibility**: Supports multi-language, theme customization, environment-specific configuration

**Component 2: Service Worker (Modular)**
- **Location**: `app/javascript/serviceworker.js` (entry point, compiled by esbuild)
- **Sub-modules**:
  - `pwa/lifecycle_manager.js` - Handles install/activate events
  - `pwa/strategy_router.js` - Routes fetch requests to appropriate strategy
  - `pwa/cache_manager.js` - Manages cache operations
  - `pwa/strategies/` - Individual cache strategy implementations
- **Responsibility**: Intercept network requests, manage caching, enable offline functionality
- **Dependencies**: Configuration from `/api/pwa/config`
- **Lifecycle**: Install → Activate → Fetch

**Component 3: Cache Strategy System (Pluggable)**
- **Location**: `app/javascript/pwa/strategies/`
- **Base Interface**: `base_strategy.js` - Abstract class for all strategies
- **Implementations**:
  - `cache_first_strategy.js` - Serve from cache, fall back to network
  - `network_first_strategy.js` - Try network first, fall back to cache
  - `network_only_strategy.js` - Always use network
  - `stale_while_revalidate_strategy.js` - Serve stale cache, update in background (future)
- **Responsibility**: Define caching behavior for different resource types
- **Extensibility**: New strategies can be added without modifying core service worker

**Component 4: Configuration System**
- **Location**: `config/pwa_config.yml`, environment variables
- **API Endpoint**: `GET /api/pwa/config` - Serves configuration to service worker
- **Responsibility**: Centralize all PWA configuration (cache versions, timeouts, feature flags)
- **Configuration Points**:
  - Cache version numbers
  - Network timeout values
  - Theme colors and branding
  - Feature flags (install prompt, push notifications, background sync)
  - Environment-specific overrides
- **Extensibility**: New configuration options can be added without code changes

**Component 5: Service Worker Registration**
- **Location**: `app/javascript/pwa/service_worker_registration.js`
- **Responsibility**: Register service worker on page load
- **Dependencies**: Service worker file, navigator.serviceWorker API
- **Execution**: Runs after DOM content loaded
- **Error Handling**: Graceful degradation if registration fails

**Component 6: Install Prompt Manager**
- **Location**: `app/javascript/pwa/install_prompt_manager.js`
- **Responsibility**: Handle beforeinstallprompt event, manage install flow
- **Dependencies**: Browser install prompt API
- **Extensibility**: Separate module allows custom install UX patterns

**Component 7: PWA Icons**
- **Location**: `public/pwa/` directory
- **Files**:
  - `icon-192.png` (192x192px)
  - `icon-512.png` (512x512px)
  - `icon-maskable-512.png` (optional maskable icon)
- **Generation**: Created from existing `app/assets/images/cat.webp`
- **Format**: PNG with transparency

**Component 8: Offline Fallback Page**
- **Location**: `public/offline.html` (static HTML file)
- **Responsibility**: Display when user navigates to uncached route offline
- **Design**: Minimal HTML with inline CSS, cat mascot image (base64 embedded)
- **Content**: "You're offline" message with branding

**Component 9: Meta Tags in Layout**
- **Location**: `app/views/layouts/application.html.slim`
- **Responsibility**: Link manifest, set theme colors, configure PWA display
- **Tags**: manifest link, theme-color, apple-mobile-web-app-capable, apple-touch-icon

**Component 10: Observability System**
- **Location**: `app/javascript/lib/` directory
- **Sub-modules**:
  - `logger.js` - Client-side structured logging
  - `metrics.js` - Metrics collection and reporting
  - `tracing.js` - Trace ID generation and propagation
  - `health.js` - PWA health check diagnostics
- **Backend Endpoints**:
  - `POST /api/client_logs` - Receive client-side logs
  - `POST /api/metrics` - Receive metrics data
- **Responsibility**: Track PWA health, errors, and performance
- **Integration**: Sentry for error tracking (recommended)

### 3.3 Data Flow

**Installation Flow:**
```
1. User visits ReLINE website (/)
   ↓
2. Browser fetches manifest.json from /manifest.json
   ↓
3. Browser evaluates PWA installability criteria:
   - HTTPS enabled ✓
   - Manifest with name, icons, start_url ✓
   - Service worker registered ✓
   ↓
4. Browser triggers beforeinstallprompt event
   ↓
5. InstallPromptManager stores deferred prompt
   ↓
6. User clicks "Install" (browser prompt or custom button)
   ↓
7. App installed to home screen/app drawer
   ↓
8. App opens in standalone mode (no browser chrome)
   ↓
9. appinstalled event tracked via metrics system
```

**Caching Flow (First Visit):**
```
1. User visits page
   ↓
2. Service worker intercepts fetch request
   ↓
3. StrategyRouter determines strategy based on URL pattern
   ↓
4. Strategy checks cache (cache miss)
   ↓
5. Strategy fetches from network
   ↓
6. CacheManager stores response in appropriate cache
   ↓
7. Response returned to browser
   ↓
8. Metrics system records cache miss
```

**Caching Flow (Subsequent Visits):**
```
1. User visits page
   ↓
2. Service worker intercepts fetch request
   ↓
3. StrategyRouter determines strategy
   ↓
4. Strategy checks cache (cache hit)
   ↓
5. Cached response returned immediately
   ↓
6. (Optional) Background network fetch for revalidation
   ↓
7. Metrics system records cache hit
```

**Offline Flow:**
```
1. User visits uncached page while offline
   ↓
2. Service worker intercepts fetch request
   ↓
3. Network request fails (no connection)
   ↓
4. Cache lookup fails (page not cached)
   ↓
5. Service worker returns offline.html fallback
   ↓
6. User sees "You're offline" message
   ↓
7. Error logged to client-side logger (queued for later transmission)
```

### 3.4 Configuration Management

**Configuration File Structure:**

```yaml
# config/pwa_config.yml
defaults: &defaults
  cache:
    version: 'v1'
    max_size_mb: 50
    strategies:
      static:
        name: 'static'
        pattern: '\.(css|js|woff2?)$'
        strategy: 'cache-first'
        max_age_days: 7
      images:
        name: 'images'
        pattern: '\.(png|jpg|webp|svg|ico)$'
        strategy: 'cache-first'
        max_age_days: 30
      pages:
        name: 'pages'
        pattern: '^\/(terms|privacy_policy|feedbacks\/new)?$'
        strategy: 'network-first'
        timeout_ms: 3000

  network:
    timeout_ms: 3000
    retry_attempts: 3
    retry_delay_ms: 1000

  manifest:
    theme_color: '#0d6efd'
    background_color: '#ffffff'
    display: 'standalone'
    orientation: 'portrait-primary'

  features:
    enable_push_notifications: false
    enable_background_sync: false
    enable_install_prompt: true
    install_prompt_delay_seconds: 30

development:
  <<: *defaults
  manifest:
    theme_color: '#dc3545'  # Red theme for dev
    start_url: '/?source=pwa-dev'
  features:
    enable_push_notifications: true  # Enable in dev for testing

staging:
  <<: *defaults
  manifest:
    theme_color: '#ffc107'  # Yellow theme for staging
    start_url: '/?source=pwa-staging'

production:
  <<: *defaults
  cache:
    max_size_mb: 100  # Higher limit in production
```

**Environment Variables:**

```bash
# .env.production
PWA_CACHE_VERSION=v1
PWA_THEME_COLOR=#0d6efd
PWA_MAX_CACHE_SIZE_MB=100
PWA_NETWORK_TIMEOUT_MS=3000
PWA_APP_NAME=ReLINE - Cat Relationship Manager
PWA_SHORT_NAME=ReLINE

# .env.development
PWA_CACHE_VERSION=v1-dev
PWA_THEME_COLOR=#dc3545
PWA_MAX_CACHE_SIZE_MB=30
PWA_NETWORK_TIMEOUT_MS=5000
```

**Configuration Loading Flow:**

```
1. Service worker install event fires
   ↓
2. ConfigLoader fetches /api/pwa/config
   ↓
3. Api::Pwa::ConfigsController generates config from:
   - pwa_config.yml (environment-specific section)
   - Environment variables (override config file)
   - Feature flags (runtime toggles)
   ↓
4. Service worker uses config for:
   - Cache version numbers
   - Strategy timeouts
   - Feature enablement
   ↓
5. Config changes require service worker update
   (or can be hot-reloaded via message passing)
```

---

## 4. Data Model

### 4.1 Web App Manifest Structure

**Dynamic Manifest Generation:**

```ruby
# app/controllers/manifests_controller.rb
class ManifestsController < ApplicationController
  def show
    manifest = {
      name: I18n.t('pwa.name', default: ENV.fetch('PWA_APP_NAME', 'ReLINE - Cat Relationship Manager')),
      short_name: I18n.t('pwa.short_name', default: ENV.fetch('PWA_SHORT_NAME', 'ReLINE')),
      description: I18n.t('pwa.description'),
      start_url: start_url_with_tracking,
      scope: '/',
      display: pwa_config[:manifest][:display],
      orientation: pwa_config[:manifest][:orientation],
      theme_color: pwa_config[:manifest][:theme_color],
      background_color: pwa_config[:manifest][:background_color],
      icons: icon_definitions,
      categories: ['productivity', 'social'],
      lang: I18n.locale.to_s,
      dir: 'ltr'
    }

    render json: manifest, content_type: 'application/manifest+json'
  end

  private

  def start_url_with_tracking
    url = pwa_config.dig(:manifest, :start_url) || '/'
    "#{url}?utm_source=pwa&utm_medium=homescreen"
  end

  def icon_definitions
    base_path = '/pwa'
    [
      {
        src: "#{base_path}/icon-192.png",
        sizes: '192x192',
        type: 'image/png',
        purpose: 'any'
      },
      {
        src: "#{base_path}/icon-512.png",
        sizes: '512x512',
        type: 'image/png',
        purpose: 'any'
      },
      {
        src: "#{base_path}/icon-maskable-512.png",
        sizes: '512x512',
        type: 'image/png',
        purpose: 'maskable'
      }
    ]
  end

  def pwa_config
    @pwa_config ||= Rails.application.config_for(:pwa_config)
  end
end
```

**Translation Files:**

```yaml
# config/locales/pwa.ja.yml
ja:
  pwa:
    name: "ReLINE - ネコと関係を管理"
    short_name: "ReLINE"
    description: "LINEボットで関係を維持するサービス"

# config/locales/pwa.en.yml
en:
  pwa:
    name: "ReLINE - Cat Relationship Manager"
    short_name: "ReLINE"
    description: "LINE bot service for maintaining relationships"
```

**Example Manifest Output:**

```json
{
  "name": "ReLINE - Cat Relationship Manager",
  "short_name": "ReLINE",
  "description": "LINE bot service that helps maintain relationships through automated messages",
  "start_url": "/?utm_source=pwa&utm_medium=homescreen",
  "scope": "/",
  "display": "standalone",
  "orientation": "portrait-primary",
  "theme_color": "#0d6efd",
  "background_color": "#ffffff",
  "icons": [
    {
      "src": "/pwa/icon-192.png",
      "sizes": "192x192",
      "type": "image/png",
      "purpose": "any"
    },
    {
      "src": "/pwa/icon-512.png",
      "sizes": "512x512",
      "type": "image/png",
      "purpose": "any"
    },
    {
      "src": "/pwa/icon-maskable-512.png",
      "sizes": "512x512",
      "type": "image/png",
      "purpose": "maskable"
    }
  ],
  "categories": ["productivity", "social"],
  "lang": "ja",
  "dir": "ltr"
}
```

### 4.2 Service Worker Cache Structure

**Cache Configuration Object:**

```javascript
// Loaded from /api/pwa/config
const cacheConfig = {
  version: 'v1',
  caches: {
    static: {
      name: 'static-v1',
      strategy: 'cache-first',
      patterns: [/\.(css|js|woff2?|ttf|eot)$/],
      maxAge: 7 * 24 * 60 * 60 * 1000
    },
    images: {
      name: 'images-v1',
      strategy: 'cache-first',
      patterns: [/\.(png|jpg|jpeg|webp|svg|gif|ico)$/],
      maxAge: 30 * 24 * 60 * 60 * 1000
    },
    pages: {
      name: 'pages-v1',
      strategy: 'network-first',
      patterns: [/^\/(terms|privacy_policy|feedbacks\/new)?$/],
      timeout: 3000
    }
  }
};
```

**Cache Contents:**

```javascript
// static-v1 cache
[
  '/assets/application-[hash].css',
  '/assets/application-[hash].js',
  '/favicon.ico'
]

// images-v1 cache
[
  '/assets/cat-[hash].webp',
  '/assets/undraw_*(various illustrations)',
  '/pwa/icon-192.png',
  '/pwa/icon-512.png'
]

// pages-v1 cache
[
  '/',                    // Landing page
  '/terms',               // Terms of service
  '/privacy_policy',      // Privacy policy
  '/feedbacks/new'        // Feedback form
]

// offline-v1 cache
[
  '/offline.html'
]
```

### 4.3 Cache Strategy Interface

**Base Strategy Class:**

```javascript
// app/javascript/pwa/strategies/base_strategy.js
export class CacheStrategy {
  constructor(cacheName, options = {}) {
    this.cacheName = cacheName;
    this.options = options;
  }

  async handle(request) {
    throw new Error('Strategy must implement handle()');
  }

  async cacheResponse(request, response) {
    if (!this.shouldCache(response)) return;

    const cache = await caches.open(this.cacheName);
    await cache.put(request, response);
  }

  shouldCache(response) {
    return response &&
           response.status === 200 &&
           response.type === 'basic';
  }

  async fetchWithTimeout(request, timeout = 3000) {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeout);

    try {
      const response = await fetch(request, { signal: controller.signal });
      clearTimeout(timeoutId);
      return response;
    } catch (error) {
      clearTimeout(timeoutId);
      throw error;
    }
  }

  async getFallback() {
    return caches.match('/offline.html');
  }
}
```

**Strategy Implementations:**

```javascript
// app/javascript/pwa/strategies/cache_first_strategy.js
import { CacheStrategy } from './base_strategy';

export class CacheFirstStrategy extends CacheStrategy {
  async handle(request) {
    const cached = await caches.match(request);
    if (cached) {
      // Update cache in background
      this.updateCacheInBackground(request);
      return cached;
    }

    const response = await fetch(request);
    await this.cacheResponse(request, response.clone());
    return response;
  }

  async updateCacheInBackground(request) {
    try {
      const response = await fetch(request);
      await this.cacheResponse(request, response);
    } catch (error) {
      // Silent fail - we already served from cache
    }
  }
}

// app/javascript/pwa/strategies/network_first_strategy.js
import { CacheStrategy } from './base_strategy';

export class NetworkFirstStrategy extends CacheStrategy {
  async handle(request) {
    try {
      const timeout = this.options.timeout || 3000;
      const response = await this.fetchWithTimeout(request, timeout);
      await this.cacheResponse(request, response.clone());
      return response;
    } catch (error) {
      const cached = await caches.match(request);
      if (cached) return cached;

      return this.getFallback();
    }
  }
}

// app/javascript/pwa/strategies/network_only_strategy.js
import { CacheStrategy } from './base_strategy';

export class NetworkOnlyStrategy extends CacheStrategy {
  async handle(request) {
    try {
      return await fetch(request);
    } catch (error) {
      return this.getFallback();
    }
  }
}

// app/javascript/pwa/strategies/stale_while_revalidate_strategy.js
import { CacheStrategy } from './base_strategy';

export class StaleWhileRevalidateStrategy extends CacheStrategy {
  async handle(request) {
    const cached = await caches.match(request);

    const fetchPromise = fetch(request).then(response => {
      this.cacheResponse(request, response.clone());
      return response;
    });

    return cached || fetchPromise;
  }
}
```

**Strategy Router:**

```javascript
// app/javascript/pwa/strategy_router.js
import { CacheFirstStrategy } from './strategies/cache_first_strategy';
import { NetworkFirstStrategy } from './strategies/network_first_strategy';
import { NetworkOnlyStrategy } from './strategies/network_only_strategy';

export class StrategyRouter {
  constructor(config) {
    this.strategies = this.initializeStrategies(config);
  }

  initializeStrategies(config) {
    const strategies = [];

    Object.entries(config.caches).forEach(([key, cacheConfig]) => {
      const StrategyClass = this.getStrategyClass(cacheConfig.strategy);
      const strategy = new StrategyClass(cacheConfig.name, cacheConfig);

      cacheConfig.patterns.forEach(pattern => {
        strategies.push({
          pattern: new RegExp(pattern),
          strategy: strategy
        });
      });
    });

    return strategies;
  }

  getStrategyClass(strategyName) {
    const strategyMap = {
      'cache-first': CacheFirstStrategy,
      'network-first': NetworkFirstStrategy,
      'network-only': NetworkOnlyStrategy
    };

    return strategyMap[strategyName] || NetworkFirstStrategy;
  }

  async handleFetch(event) {
    const { request } = event;
    const strategy = this.findStrategy(request.url);

    if (!strategy) {
      return fetch(request);
    }

    return strategy.handle(request);
  }

  findStrategy(url) {
    const match = this.strategies.find(s => s.pattern.test(url));
    return match ? match.strategy : null;
  }
}
```

---

## 5. API Design

### 5.1 Service Worker API (Modular)

**Service Worker Entry Point:**

```javascript
// app/javascript/serviceworker.js
import { LifecycleManager } from './pwa/lifecycle_manager';
import { StrategyRouter } from './pwa/strategy_router';
import { ConfigLoader } from './pwa/config_loader';

let lifecycleManager;
let strategyRouter;

self.addEventListener('install', (event) => {
  event.waitUntil(
    ConfigLoader.load().then(config => {
      lifecycleManager = new LifecycleManager(config);
      strategyRouter = new StrategyRouter(config);
      return lifecycleManager.handleInstall();
    })
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    lifecycleManager.handleActivate()
  );
});

self.addEventListener('fetch', (event) => {
  event.respondWith(
    strategyRouter.handleFetch(event)
  );
});
```

**Lifecycle Manager:**

```javascript
// app/javascript/pwa/lifecycle_manager.js
export class LifecycleManager {
  constructor(config) {
    this.config = config;
    this.cacheNames = this.generateCacheNames(config);
  }

  generateCacheNames(config) {
    const names = {};
    Object.entries(config.caches).forEach(([key, cache]) => {
      names[key] = cache.name;
    });
    names.offline = `offline-${config.version}`;
    return names;
  }

  async handleInstall() {
    const cache = await caches.open(this.cacheNames.offline);
    await cache.addAll(['/offline.html']);

    // Pre-cache critical assets
    const staticCache = await caches.open(this.cacheNames.static);
    await staticCache.addAll([
      '/',
      '/assets/application.css',
      '/assets/application.js',
      '/assets/cat.webp'
    ]);

    self.skipWaiting();
  }

  async handleActivate() {
    const validCacheNames = Object.values(this.cacheNames);
    const cacheNames = await caches.keys();

    await Promise.all(
      cacheNames
        .filter(name => !validCacheNames.includes(name))
        .map(name => caches.delete(name))
    );

    await self.clients.claim();
  }
}
```

**Config Loader:**

```javascript
// app/javascript/pwa/config_loader.js
export class ConfigLoader {
  static async load() {
    try {
      const response = await fetch('/api/pwa/config');
      return await response.json();
    } catch (error) {
      console.warn('Failed to load PWA config, using defaults');
      return this.getDefaults();
    }
  }

  static getDefaults() {
    return {
      version: 'v1',
      caches: {
        static: {
          name: 'static-v1',
          strategy: 'cache-first',
          patterns: ['\\.css$', '\\.js$'],
          maxAge: 604800000
        },
        images: {
          name: 'images-v1',
          strategy: 'cache-first',
          patterns: ['\\.png$', '\\.webp$', '\\.jpg$'],
          maxAge: 2592000000
        }
      }
    };
  }
}
```

### 5.2 Configuration API

**Configuration Endpoint:**

```ruby
# app/controllers/api/pwa/configs_controller.rb
module Api
  module Pwa
    class ConfigsController < ApplicationController
      skip_before_action :verify_authenticity_token

      def show
        config = {
          version: pwa_cache_version,
          caches: cache_strategies_config,
          network: network_config,
          features: features_config
        }

        render json: config
      end

      private

      def pwa_cache_version
        ENV.fetch('PWA_CACHE_VERSION', pwa_config[:cache][:version])
      end

      def cache_strategies_config
        pwa_config[:cache][:strategies].transform_values do |strategy|
          {
            name: "#{strategy[:name]}-#{pwa_cache_version}",
            strategy: strategy[:strategy],
            patterns: strategy[:pattern].is_a?(Array) ? strategy[:pattern] : [strategy[:pattern]],
            maxAge: strategy[:max_age_days] * 24 * 60 * 60 * 1000,
            timeout: strategy[:timeout_ms] || pwa_config[:network][:timeout_ms]
          }
        end
      end

      def network_config
        {
          timeout_ms: ENV.fetch('PWA_NETWORK_TIMEOUT_MS', pwa_config[:network][:timeout_ms]).to_i,
          retry_attempts: pwa_config[:network][:retry_attempts],
          retry_delay_ms: pwa_config[:network][:retry_delay_ms]
        }
      end

      def features_config
        {
          enable_push_notifications: feature_enabled?(:pwa_push_notifications),
          enable_background_sync: feature_enabled?(:pwa_background_sync),
          enable_install_prompt: feature_enabled?(:pwa_install_prompt)
        }
      end

      def feature_enabled?(feature_name)
        pwa_config.dig(:features, feature_name) || false
      end

      def pwa_config
        @pwa_config ||= Rails.application.config_for(:pwa_config)
      end
    end
  end
end
```

**Routes:**

```ruby
# config/routes.rb
namespace :api do
  namespace :pwa do
    resource :config, only: [:show]
  end
end
```

### 5.3 Registration API (Client-Side)

**Service Worker Registration Module:**

```javascript
// app/javascript/pwa/service_worker_registration.js
import { logger } from '../lib/logger';
import { metrics } from '../lib/metrics';

export class ServiceWorkerRegistration {
  constructor() {
    this.registration = null;
  }

  async register() {
    if (!('serviceWorker' in navigator)) {
      logger.warn('Service Worker not supported');
      return null;
    }

    try {
      this.registration = await navigator.serviceWorker.register('/serviceworker.js');

      logger.info('Service Worker registered', {
        scope: this.registration.scope
      });

      metrics.trackServiceWorkerRegistration(true);

      this.setupUpdateHandler();

      return this.registration;
    } catch (error) {
      logger.error('Service Worker registration failed', {
        error: error.message,
        stack: error.stack
      });

      metrics.trackServiceWorkerRegistration(false, error);

      return null;
    }
  }

  setupUpdateHandler() {
    this.registration.addEventListener('updatefound', () => {
      const newWorker = this.registration.installing;

      newWorker.addEventListener('statechange', () => {
        if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
          logger.info('New Service Worker available');
          this.notifyUpdateAvailable();
        }
      });
    });
  }

  notifyUpdateAvailable() {
    // Show update notification to user
    if (window.confirm('新しいバージョンが利用可能です。ページを再読み込みしますか？')) {
      window.location.reload();
    }
  }
}
```

**Install Prompt Manager:**

```javascript
// app/javascript/pwa/install_prompt_manager.js
import { logger } from '../lib/logger';
import { metrics } from '../lib/metrics';

export class InstallPromptManager {
  constructor() {
    this.deferredPrompt = null;
    this.setupListeners();
  }

  setupListeners() {
    window.addEventListener('beforeinstallprompt', (event) => {
      event.preventDefault();
      this.deferredPrompt = event;

      logger.info('Install prompt available');
      metrics.trackInstallPrompt(true, false);
    });

    window.addEventListener('appinstalled', () => {
      logger.info('PWA installed');
      metrics.trackInstallPrompt(true, true);
      this.deferredPrompt = null;
    });
  }

  async showPrompt() {
    if (!this.deferredPrompt) {
      logger.warn('Install prompt not available');
      return false;
    }

    this.deferredPrompt.prompt();
    const choiceResult = await this.deferredPrompt.userChoice;

    logger.info('Install prompt result', {
      outcome: choiceResult.outcome
    });

    const accepted = choiceResult.outcome === 'accepted';
    metrics.trackInstallPrompt(true, accepted);

    this.deferredPrompt = null;
    return accepted;
  }

  isAvailable() {
    return this.deferredPrompt !== null;
  }
}
```

**Application Entry Point:**

```javascript
// app/javascript/application.js
import { ServiceWorkerRegistration } from './pwa/service_worker_registration';
import { InstallPromptManager } from './pwa/install_prompt_manager';

// Initialize PWA features
window.addEventListener('load', async () => {
  const swRegistration = new ServiceWorkerRegistration();
  await swRegistration.register();

  const installManager = new InstallPromptManager();

  // Expose to global scope for debugging
  window.PWA = {
    installManager,
    swRegistration
  };
});
```

### 5.4 Observability APIs

**Client Logs Endpoint:**

```ruby
# app/controllers/api/client_logs_controller.rb
module Api
  class ClientLogsController < ApplicationController
    skip_before_action :verify_authenticity_token

    def create
      ClientLog.create!(
        level: params[:level],
        message: params[:message],
        user_id: params[:userId],
        session_id: params[:sessionId],
        service_worker_version: params[:serviceWorkerVersion],
        user_agent: params[:userAgent],
        url: params[:url],
        context: context_params
      )

      head :created
    rescue => e
      Rails.logger.error("Failed to save client log: #{e.message}")
      head :no_content
    end

    private

    def context_params
      params.except(
        :level, :message, :userId, :sessionId,
        :serviceWorkerVersion, :userAgent, :url,
        :controller, :action, :format
      )
    end
  end
end
```

**Metrics Endpoint:**

```ruby
# app/controllers/api/metrics_controller.rb
module Api
  class MetricsController < ApplicationController
    skip_before_action :verify_authenticity_token

    def create
      Metric.create!(
        name: params[:name],
        value: params[:value],
        timestamp: Time.at(params[:timestamp] / 1000.0),
        tags: params[:tags]
      )

      head :created
    rescue => e
      Rails.logger.error("Failed to save metric: #{e.message}")
      head :no_content
    end
  end
end
```

**Database Schema for Observability:**

```ruby
# db/migrate/xxx_create_client_logs.rb
class CreateClientLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :client_logs do |t|
      t.string :level, null: false
      t.text :message, null: false
      t.string :user_id
      t.string :session_id
      t.string :service_worker_version
      t.string :user_agent
      t.string :url
      t.jsonb :context, default: {}

      t.timestamps
    end

    add_index :client_logs, :level
    add_index :client_logs, :user_id
    add_index :client_logs, :session_id
    add_index :client_logs, :created_at
  end
end

# db/migrate/xxx_create_metrics.rb
class CreateMetrics < ActiveRecord::Migration[8.0]
  def change
    create_table :metrics do |t|
      t.string :name, null: false
      t.decimal :value, precision: 10, scale: 2
      t.datetime :timestamp, null: false
      t.jsonb :tags, default: {}

      t.timestamps
    end

    add_index :metrics, :name
    add_index :metrics, :timestamp
    add_index :metrics, [:name, :timestamp]
  end
end
```

### 5.5 HTTP Headers

**Required Headers:**

```ruby
# config/initializers/pwa_headers.rb
Rails.application.config.middleware.use(
  Rack::Deflater
)

Rails.application.config.after_initialize do
  # Manifest headers
  ActionDispatch::Static.new(Rails.application).tap do |middleware|
    middleware.instance_eval do
      def set_headers(headers, path, _etag)
        if path.end_with?('.json') && path.include?('manifest')
          headers['Content-Type'] = 'application/manifest+json'
          headers['Cache-Control'] = 'public, max-age=3600'
        elsif path.end_with?('serviceworker.js')
          headers['Content-Type'] = 'application/javascript'
          headers['Service-Worker-Allowed'] = '/'
          headers['Cache-Control'] = 'no-cache'
        elsif path.start_with?('/pwa/') && path.end_with?('.png')
          headers['Content-Type'] = 'image/png'
          headers['Cache-Control'] = 'public, max-age=2592000'
        end
      end
    end
  end
end
```

---

## 6. Security Considerations

### 6.1 Threat Model

**Threat 1: Service Worker Hijacking**
- **Description**: Attacker injects malicious service worker to intercept all traffic
- **Impact**: Data theft, session hijacking, malware distribution
- **Likelihood**: Low (requires HTTPS compromise or XSS vulnerability)

**Threat 2: Cache Poisoning**
- **Description**: Attacker serves malicious content that gets cached
- **Impact**: Persistent XSS, malware delivery via cached assets
- **Likelihood**: Medium (requires compromised CDN or network attack)

**Threat 3: Unauthorized Access to Cached Data**
- **Description**: Cached operator pages accessible offline without authentication
- **Impact**: Information disclosure of sensitive admin data
- **Likelihood**: High if operator routes cached

**Threat 4: Service Worker Scope Escalation**
- **Description**: Service worker controls broader scope than intended
- **Impact**: Interception of unrelated sites or subdomains
- **Likelihood**: Low (requires misconfiguration)

**Threat 5: Manifest Manipulation**
- **Description**: Attacker modifies manifest.json to change app behavior
- **Impact**: Phishing (app name/icon changes), start URL redirection
- **Likelihood**: Low (requires file system access or XSS)

### 6.2 Security Controls

**Control 1: HTTPS Enforcement**
- **Mitigation for**: Threat 1 (Service Worker Hijacking)
- **Implementation**:
  - Force HTTPS in production via Rails config
  - Service worker only registers on HTTPS origins
  - HSTS headers configured
- **Validation**: Service worker registration fails on HTTP

**Control 2: Service Worker Scope Restriction**
- **Mitigation for**: Threat 4 (Scope Escalation)
- **Implementation**:
  - Service worker scope set to '/' in manifest
  - Service-Worker-Allowed header validates scope
  - No cross-origin service worker registration
- **Validation**: Browser enforces scope limits

**Control 3: Authentication-Required Routes Excluded from Cache**
- **Mitigation for**: Threat 3 (Unauthorized Access)
- **Implementation**:
  - Operator routes use 'network-only' strategy
  - No caching of /operator/* paths
  - Authentication required for all operator actions
- **Validation**: Offline operator routes show offline.html, not cached content

**Control 4: Cache Integrity Validation**
- **Mitigation for**: Threat 2 (Cache Poisoning)
- **Implementation**:
  - Subresource Integrity (SRI) hashes for critical assets
  - Cache version busting on service worker updates
  - Content-Type validation before caching
- **Validation**: Service worker skips caching if response headers invalid

**Control 5: Content Security Policy**
- **Mitigation for**: Threat 1, 2, 5 (XSS-based attacks)
- **Implementation**:
  ```ruby
  # config/initializers/content_security_policy.rb
  Rails.application.config.content_security_policy do |policy|
    policy.default_src :self
    policy.script_src  :self, :unsafe_inline  # Required for Turbo
    policy.style_src   :self, :unsafe_inline  # Required for Bootstrap
    policy.img_src     :self, :data, :https
    policy.manifest_src :self
    policy.worker_src  :self  # Allow service worker from same origin
  end
  ```
- **Validation**: CSP violations logged to console

**Control 6: Service Worker Versioning**
- **Mitigation for**: Threat 2 (Cache Poisoning persistence)
- **Implementation**:
  - Cache names include version number (static-v1)
  - Service worker update triggers cache invalidation
  - Clients check for updates every 24 hours
- **Validation**: Old caches deleted on activation

**Control 7: No Caching of Sensitive Data**
- **Mitigation for**: Threat 3 (Data Exposure)
- **Implementation**:
  - Never cache POST/PUT/DELETE requests
  - Never cache responses with Set-Cookie headers
  - Never cache API responses with user data
- **Validation**: Service worker code review

### 6.3 Data Protection Measures

**Measure 1: No Personal Data in Cache**
- Public pages contain no user-specific information
- Operator pages not cached (network-only strategy)
- LINE webhook responses not cached

**Measure 2: Cache Storage Encryption**
- Browser-managed cache storage encrypted at rest (OS-level)
- No additional encryption layer needed for public content

**Measure 3: Cache Expiration**
- Static assets: 7-day max age
- Images: 30-day max age
- HTML pages: 0-second max age (always revalidate)
- Offline fallback: Never expires

**Measure 4: Secure Cookie Handling**
- Session cookies marked Secure, HttpOnly, SameSite=Strict
- Service worker cannot access HttpOnly cookies
- Authentication state not stored in cache

---

## 7. Error Handling

### 7.1 Error Scenarios

**Scenario 1: Service Worker Registration Failure**
- **Cause**: Browser lacks service worker support, HTTPS not enabled
- **Detection**: `navigator.serviceWorker.register()` promise rejection
- **Handling**:
  ```javascript
  navigator.serviceWorker.register('/serviceworker.js')
    .catch((error) => {
      logger.error('Service worker registration failed', {
        error: error.message,
        stack: error.stack,
        browser: navigator.userAgent
      });

      // App continues functioning without PWA features
      // No user-facing error message (graceful degradation)
    });
  ```
- **User Impact**: No PWA installation, no offline support, app still usable
- **Recovery**: None (browsers without SW support cannot be upgraded)

**Scenario 2: Manifest Parse Error**
- **Cause**: Invalid JSON syntax in manifest.json
- **Detection**: Browser console error "Manifest parsing failed"
- **Handling**:
  - Validate manifest.json with JSON schema in tests
  - Monitor browser DevTools for manifest errors
  - Log parse errors to client logger
- **User Impact**: Install prompt won't appear, app still loads
- **Recovery**: Fix manifest.json syntax, redeploy

**Scenario 3: Cache Storage Quota Exceeded**
- **Cause**: Browser cache storage limit reached (varies by browser, ~50-100MB)
- **Detection**: `caches.open()` or `cache.put()` promise rejection with QuotaExceededError
- **Handling**:
  ```javascript
  cache.put(request, response).catch((error) => {
    if (error.name === 'QuotaExceededError') {
      logger.warn('Cache quota exceeded, clearing old caches');
      metrics.recordMetric('cache_quota_exceeded', 1);
      return clearOldestCache();
    }
  });
  ```
- **User Impact**: New assets not cached, older cached content still available
- **Recovery**: Delete oldest caches, retry caching operation

**Scenario 4: Network Timeout During Cache Fallback**
- **Cause**: Slow network connection during network-first strategy
- **Detection**: Network request exceeds 3-second timeout
- **Handling**:
  ```javascript
  const networkPromise = fetch(request);
  const timeoutPromise = new Promise((_, reject) =>
    setTimeout(() => reject(new Error('Timeout')), 3000)
  );

  return Promise.race([networkPromise, timeoutPromise])
    .catch((error) => {
      logger.warn('Network timeout, falling back to cache', {
        url: request.url,
        timeout: 3000
      });
      return caches.match(request);
    });
  ```
- **User Impact**: Slightly stale content displayed (from cache)
- **Recovery**: Automatic retry on next navigation

**Scenario 5: Service Worker Update Failure**
- **Cause**: New service worker fails to install (e.g., network error during fetch)
- **Detection**: `install` event `waitUntil()` promise rejection
- **Handling**:
  ```javascript
  self.addEventListener('install', (event) => {
    event.waitUntil(
      cacheAssets().catch((error) => {
        logger.error('Service worker install failed', {
          error: error.message,
          version: CACHE_VERSION
        });
        // Old service worker continues running
        // New service worker won't activate
      })
    );
  });
  ```
- **User Impact**: Old service worker continues functioning
- **Recovery**: Fix network issue, browser retries update automatically

**Scenario 6: Offline Page Not Cached**
- **Cause**: Service worker install failed before offline.html cached
- **Detection**: `caches.match('/offline.html')` returns undefined
- **Handling**:
  ```javascript
  fetch(request)
    .catch(() => caches.match(request))
    .catch(() => caches.match('/offline.html'))
    .catch(() => {
      logger.error('Offline page not cached', {
        url: request.url
      });

      // Last resort: Return minimal HTML response
      return new Response(
        '<h1>Offline</h1><p>No connection available.</p>',
        { headers: { 'Content-Type': 'text/html' } }
      );
    });
  ```
- **User Impact**: Minimal fallback HTML displayed
- **Recovery**: Cache offline.html on next online session

**Scenario 7: Icon Loading Failure**
- **Cause**: PWA icons missing or incorrect path in manifest
- **Detection**: Browser console error "Failed to load icon"
- **Handling**:
  - Validate icon paths exist in automated tests
  - Monitor Lighthouse audits for icon issues
  - Log icon load errors
- **User Impact**: Default browser icon used, install still works
- **Recovery**: Fix icon paths in manifest.json, redeploy

**Scenario 8: Turbo Drive Conflict**
- **Cause**: Service worker interferes with Turbo page navigation
- **Detection**: Pages don't update after Turbo navigation
- **Handling**:
  - Always set Cache-Control: no-cache for HTML pages
  - Use network-first strategy for HTML
  - Let Turbo handle navigation, service worker only caches final responses
- **User Impact**: None if handled correctly
- **Recovery**: Adjust cache strategy for HTML requests

### 7.2 Error Messages

**User-Facing Messages:**
```javascript
const ERROR_MESSAGES = {
  offline: {
    title: 'オフラインです',
    body: 'インターネット接続を確認してください。',
    image: '/pwa/offline-cat.png'
  },
  update_available: {
    title: '新しいバージョンが利用可能です',
    body: 'ページを再読み込みして更新してください。',
    action: 'リロード'
  },
  quota_exceeded: {
    title: 'キャッシュ容量が不足しています',
    body: '古いキャッシュを削除してください。',
    action: '削除'
  }
};
```

**Developer Messages (Console & Logs):**
```javascript
const DEV_MESSAGES = {
  sw_registered: 'Service worker registered successfully',
  sw_updated: 'Service worker updated, new version will activate on next page load',
  cache_hit: 'Serving from cache: [url]',
  cache_miss: 'Cache miss, fetching from network: [url]',
  quota_exceeded: 'Cache quota exceeded, clearing old caches',
  registration_failed: 'Service worker registration failed: [error]',
  install_failed: 'Service worker install failed: [error]'
};
```

### 7.3 Recovery Strategies

**Strategy 1: Automatic Service Worker Update**
- On service worker update detected, prompt user to reload
- Store update flag in session storage
- Show notification: "新しいバージョンが利用可能です - リロード"

**Strategy 2: Cache Cleanup on Quota Exceeded**
- Implement LRU (Least Recently Used) cache eviction
- Delete oldest cache entries when quota reached
- Prioritize critical assets (offline.html, main CSS/JS)

**Strategy 3: Graceful Degradation**
- If service worker registration fails, app works as regular website
- No error messages shown to user
- PWA features silently disabled

**Strategy 4: Manual Cache Clear**
- Provide developer tool or admin UI to clear all caches
- Accessible via console: `PWA.clearAllCaches()`
- Useful for debugging or forcing updates

**Strategy 5: Fallback Chain**
```javascript
// Hierarchical fallback for maximum resilience
fetch(request)
  .catch(() => caches.match(request))           // Try cache
  .catch(() => caches.match('/offline.html'))   // Try offline page
  .catch(() => createMinimalResponse())          // Last resort
```

---

## 8. Observability & Monitoring

### 8.1 Client-Side Logging

**Logger Implementation:**

```javascript
// app/javascript/lib/logger.js
class PWALogger {
  constructor() {
    this.userId = this.getUserId();
    this.sessionId = this.getSessionId();
    this.serviceWorkerVersion = 'v1';
  }

  log(level, message, context = {}) {
    const logEntry = {
      timestamp: new Date().toISOString(),
      level: level,
      message: message,
      userId: this.userId,
      sessionId: this.sessionId,
      serviceWorkerVersion: this.serviceWorkerVersion,
      userAgent: navigator.userAgent,
      url: window.location.href,
      ...context
    };

    // Console logging for development
    console[level.toLowerCase()](message, logEntry);

    // Send to server for production monitoring
    if (this.shouldSendToServer()) {
      this.sendToServer(logEntry);
    }
  }

  info(message, context) { this.log('INFO', message, context); }
  warn(message, context) { this.log('WARN', message, context); }
  error(message, context) { this.log('ERROR', message, context); }
  debug(message, context) { this.log('DEBUG', message, context); }

  shouldSendToServer() {
    return process.env.NODE_ENV === 'production' ||
           localStorage.getItem('pwa_debug') === 'true';
  }

  sendToServer(logEntry) {
    // Non-blocking log transmission
    if (navigator.sendBeacon) {
      navigator.sendBeacon('/api/client_logs', JSON.stringify(logEntry));
    } else {
      // Fallback for browsers without sendBeacon
      fetch('/api/client_logs', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(logEntry),
        keepalive: true
      }).catch(() => {
        // Silent fail - don't block user experience
      });
    }
  }

  getUserId() {
    const match = document.cookie.match(/user_id=([^;]+)/);
    return match ? match[1] : 'anonymous';
  }

  getSessionId() {
    let sessionId = sessionStorage.getItem('session_id');
    if (!sessionId) {
      sessionId = `sess_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
      sessionStorage.setItem('session_id', sessionId);
    }
    return sessionId;
  }
}

export const logger = new PWALogger();
```

**Usage in Service Worker:**

```javascript
// serviceworker.js
import { logger } from './lib/logger';

self.addEventListener('install', (event) => {
  logger.info('Service worker installing', {
    version: CACHE_VERSION,
    cachingAssets: CACHE_URLS.length
  });

  event.waitUntil(
    cacheAssets().catch((error) => {
      logger.error('Service worker install failed', {
        error: error.message,
        stack: error.stack,
        failedAssets: error.failedAssets
      });
      throw error;
    })
  );
});

self.addEventListener('fetch', (event) => {
  const startTime = performance.now();

  event.respondWith(
    handleFetch(event.request)
      .then(response => {
        const duration = performance.now() - startTime;
        logger.debug('Fetch handled', {
          url: event.request.url,
          duration: duration,
          fromCache: response.fromCache
        });
        return response;
      })
      .catch(error => {
        logger.error('Fetch failed', {
          url: event.request.url,
          error: error.message
        });
        throw error;
      })
  );
});
```

### 8.2 Metrics Collection

**Metrics System:**

```javascript
// app/javascript/lib/metrics.js
class PWAMetrics {
  constructor() {
    this.sessionStart = Date.now();
    this.metrics = [];
  }

  recordMetric(name, value, tags = {}) {
    const metric = {
      name: name,
      value: value,
      timestamp: Date.now(),
      tags: {
        userId: this.getUserId(),
        sessionId: this.getSessionId(),
        serviceWorkerVersion: this.getServiceWorkerVersion(),
        ...tags
      }
    };

    this.metrics.push(metric);
    this.sendMetric(metric);
  }

  sendMetric(metric) {
    // Send to backend metrics endpoint
    navigator.sendBeacon('/api/metrics', JSON.stringify(metric));

    // Send to Google Analytics (if configured)
    if (window.gtag) {
      gtag('event', metric.name, {
        value: metric.value,
        ...metric.tags
      });
    }
  }

  // Service Worker Metrics
  trackServiceWorkerRegistration(success, error = null) {
    this.recordMetric('service_worker_registration', success ? 1 : 0, {
      success: success,
      error: error ? error.message : null
    });
  }

  trackCacheHit(url, hit) {
    this.recordMetric('cache_hit', hit ? 1 : 0, {
      url: url,
      hit: hit
    });
  }

  // Install Metrics
  trackInstallPrompt(shown, accepted) {
    this.recordMetric('install_prompt', shown ? 1 : 0, {
      shown: shown,
      accepted: accepted
    });
  }

  // Performance Metrics
  trackPerformance() {
    const perfData = performance.getEntriesByType('navigation')[0];

    this.recordMetric('time_to_first_paint',
      perfData.domContentLoadedEventEnd - perfData.fetchStart);

    this.recordMetric('time_to_interactive',
      perfData.loadEventEnd - perfData.fetchStart);

    // Track service worker impact
    const serviceWorkerStart = perfData.workerStart || 0;
    if (serviceWorkerStart > 0) {
      this.recordMetric('service_worker_overhead',
        serviceWorkerStart - perfData.fetchStart);
    }
  }

  trackCacheStorageUsage() {
    if (navigator.storage && navigator.storage.estimate) {
      navigator.storage.estimate().then(estimate => {
        this.recordMetric('cache_storage_usage_bytes', estimate.usage);
        this.recordMetric('cache_storage_quota_bytes', estimate.quota);
        this.recordMetric('cache_storage_usage_percent',
          (estimate.usage / estimate.quota) * 100);
      });
    }
  }

  // Error Metrics
  trackError(errorType, message) {
    this.recordMetric('error', 1, {
      errorType: errorType,
      message: message
    });
  }

  getUserId() {
    const match = document.cookie.match(/user_id=([^;]+)/);
    return match ? match[1] : 'anonymous';
  }

  getSessionId() {
    return sessionStorage.getItem('session_id') || 'unknown';
  }

  getServiceWorkerVersion() {
    return 'v1'; // Should match cache version
  }
}

export const metrics = new PWAMetrics();
```

**Automatic Metrics Collection:**

```javascript
// app/javascript/application.js
import { metrics } from './lib/metrics';

window.addEventListener('load', () => {
  // Track initial page load performance
  setTimeout(() => {
    metrics.trackPerformance();
    metrics.trackCacheStorageUsage();
  }, 1000);

  // Track cache storage usage periodically
  setInterval(() => {
    metrics.trackCacheStorageUsage();
  }, 60000); // Every minute
});
```

### 8.3 Distributed Tracing

**Tracing System:**

```javascript
// app/javascript/lib/tracing.js
class PWATracing {
  generateTraceId() {
    return `trace_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  generateSpanId() {
    return `span_${Math.random().toString(36).substr(2, 9)}`;
  }

  startSpan(name, traceId = null) {
    const span = {
      name: name,
      traceId: traceId || this.generateTraceId(),
      spanId: this.generateSpanId(),
      startTime: performance.now(),
      tags: {}
    };

    return {
      span: span,
      end: (tags = {}) => {
        span.duration = performance.now() - span.startTime;
        span.tags = { ...span.tags, ...tags };
        this.recordSpan(span);
        return span.traceId;
      }
    };
  }

  recordSpan(span) {
    logger.info(`Span: ${span.name}`, {
      traceId: span.traceId,
      spanId: span.spanId,
      duration: span.duration,
      ...span.tags
    });

    // Send to tracing backend
    navigator.sendBeacon('/api/traces', JSON.stringify(span));
  }
}

export const tracing = new PWATracing();
```

**Instrumentation Example:**

```javascript
// app/javascript/pwa/service_worker_registration.js
import { tracing } from '../lib/tracing';
import { logger } from '../lib/logger';

async register() {
  const { span, end } = tracing.startSpan('service_worker_registration');

  try {
    this.registration = await navigator.serviceWorker.register('/serviceworker.js');
    const traceId = end({
      success: true,
      scope: this.registration.scope
    });

    logger.info('SW registered', { traceId, scope: this.registration.scope });
  } catch (error) {
    const traceId = end({
      success: false,
      error: error.message
    });

    logger.error('SW registration failed', { traceId, error: error.message });
  }
}
```

### 8.4 Health Checks & Diagnostics

**Health Check System:**

```javascript
// app/javascript/lib/health.js
class PWAHealth {
  async checkHealth() {
    const health = {
      timestamp: new Date().toISOString(),
      serviceWorker: await this.checkServiceWorker(),
      cacheStorage: await this.checkCacheStorage(),
      manifest: await this.checkManifest(),
      browserSupport: this.checkBrowserSupport()
    };

    return health;
  }

  async checkServiceWorker() {
    if (!('serviceWorker' in navigator)) {
      return { status: 'unsupported', error: 'Service worker API not available' };
    }

    try {
      const registration = await navigator.serviceWorker.getRegistration();
      if (!registration) {
        return { status: 'not_registered', error: 'No service worker registered' };
      }

      return {
        status: 'healthy',
        scope: registration.scope,
        active: !!registration.active,
        waiting: !!registration.waiting,
        installing: !!registration.installing,
        updateViaCache: registration.updateViaCache
      };
    } catch (error) {
      return { status: 'error', error: error.message };
    }
  }

  async checkCacheStorage() {
    if (!('caches' in window)) {
      return { status: 'unsupported', error: 'Cache Storage API not available' };
    }

    try {
      const cacheNames = await caches.keys();
      const estimate = await navigator.storage.estimate();

      return {
        status: 'healthy',
        cacheCount: cacheNames.length,
        cacheNames: cacheNames,
        storageUsed: estimate.usage,
        storageQuota: estimate.quota,
        storageUsedPercent: (estimate.usage / estimate.quota) * 100
      };
    } catch (error) {
      return { status: 'error', error: error.message };
    }
  }

  async checkManifest() {
    try {
      const response = await fetch('/manifest.json');
      if (!response.ok) {
        return { status: 'error', error: `HTTP ${response.status}` };
      }

      const manifest = await response.json();
      return {
        status: 'healthy',
        name: manifest.name,
        shortName: manifest.short_name,
        startUrl: manifest.start_url,
        display: manifest.display,
        iconCount: manifest.icons?.length || 0
      };
    } catch (error) {
      return { status: 'error', error: error.message };
    }
  }

  checkBrowserSupport() {
    return {
      serviceWorker: 'serviceWorker' in navigator,
      cacheStorage: 'caches' in window,
      pushNotifications: 'PushManager' in window,
      notifications: 'Notification' in window,
      backgroundSync: 'sync' in (ServiceWorkerRegistration.prototype || {})
    };
  }
}

export const health = new PWAHealth();
```

**Expose in Console:**

```javascript
// app/javascript/application.js
window.PWA = {
  checkHealth: async () => {
    const healthStatus = await health.checkHealth();
    console.table(healthStatus);
    return healthStatus;
  },

  clearAllCaches: async () => {
    const cacheNames = await caches.keys();
    await Promise.all(cacheNames.map(name => caches.delete(name)));
    logger.info(`Cleared ${cacheNames.length} caches`);
  },

  updateServiceWorker: async () => {
    const registration = await navigator.serviceWorker.getRegistration();
    if (registration) {
      await registration.update();
      logger.info('Service worker update check triggered');
    }
  },

  getMetrics: () => {
    return metrics.metrics;
  }
};
```

### 8.5 Monitoring Dashboard & Alerts

**Recommended Monitoring Stack:**

- **Error Tracking**: Sentry Browser SDK (lightweight, comprehensive)
- **Metrics Collection**: Custom `/api/metrics` endpoint + Google Analytics
- **Visualization**: Grafana dashboards (self-hosted) or Google Analytics
- **Alerting**: Email alerts via Rails + optional Slack integration

**Key Metrics to Monitor:**

1. **Service Worker Registration Rate**: ≥ 95% (Alert if < 90%)
2. **Cache Hit Rate**: ≥ 80% (Alert if < 60%)
3. **Install Conversion Rate**: ≥ 5% (Track, no alert)
4. **Cache Storage Usage**: < 90% (Alert if ≥ 90%)
5. **Error Rate**: < 1% (Alert if ≥ 5%)
6. **Time to First Paint**: < 1s (Track, no alert)

**Alert Configuration Example:**

```ruby
# app/models/pwa_alert_monitor.rb
class PwaAlertMonitor
  ALERT_THRESHOLDS = {
    service_worker_registration_failure_rate: 0.10, # 10%
    cache_storage_usage_percent: 90,
    error_rate: 0.05 # 5%
  }

  def self.check_and_alert
    check_service_worker_registration_rate
    check_cache_storage_usage
    check_error_rate
  end

  def self.check_service_worker_registration_rate
    last_hour = 1.hour.ago
    total = Metric.where(name: 'service_worker_registration', timestamp: last_hour..).count
    failures = Metric.where(
      name: 'service_worker_registration',
      timestamp: last_hour..,
      tags: { success: false }
    ).count

    failure_rate = failures.to_f / total
    if failure_rate > ALERT_THRESHOLDS[:service_worker_registration_failure_rate]
      send_alert(
        "High Service Worker Registration Failure Rate",
        "#{(failure_rate * 100).round(2)}% of registrations failing (threshold: 10%)"
      )
    end
  end

  def self.check_cache_storage_usage
    latest_usage = Metric.where(name: 'cache_storage_usage_percent')
                         .order(timestamp: :desc)
                         .first

    if latest_usage && latest_usage.value > ALERT_THRESHOLDS[:cache_storage_usage_percent]
      send_alert(
        "Cache Storage Quota Nearly Exceeded",
        "Cache storage at #{latest_usage.value.round(2)}% (threshold: 90%)"
      )
    end
  end

  def self.send_alert(title, message)
    # Email alert
    AlertMailer.pwa_alert(title, message).deliver_later

    # Slack alert (if configured)
    SlackNotifier.notify(title, message) if ENV['SLACK_WEBHOOK_URL']

    # Log alert
    Rails.logger.error("[PWA ALERT] #{title}: #{message}")
  end
end

# config/schedule.rb (whenever gem)
every 5.minutes do
  runner "PwaAlertMonitor.check_and_alert"
end
```

---

## 9. Testing Strategy

### 9.1 Unit Testing

**Test 1: Manifest.json Validity**
```ruby
# spec/requests/manifest_spec.rb
RSpec.describe 'Manifest', type: :request do
  it 'returns valid manifest JSON' do
    get '/manifest.json'

    expect(response).to have_http_status(:success)
    expect(response.content_type).to include('application/json')

    manifest = JSON.parse(response.body)
    expect(manifest['name']).to eq('ReLINE - Cat Relationship Manager')
    expect(manifest['short_name']).to eq('ReLINE')
    expect(manifest['start_url']).to include('/')
    expect(manifest['display']).to eq('standalone')
    expect(manifest['icons']).to be_an(Array)
    expect(manifest['icons'].length).to be >= 2
  end

  it 'includes required icon sizes' do
    get '/manifest.json'
    manifest = JSON.parse(response.body)
    icon_sizes = manifest['icons'].map { |icon| icon['sizes'] }

    expect(icon_sizes).to include('192x192')
    expect(icon_sizes).to include('512x512')
  end

  it 'supports multi-language' do
    get '/manifest.json', headers: { 'Accept-Language': 'en' }
    manifest = JSON.parse(response.body)
    expect(manifest['lang']).to eq('en')
    expect(manifest['name']).to include('Cat Relationship Manager')
  end
end
```

**Test 2: PWA Icon Existence**
```ruby
# spec/assets/pwa_icons_spec.rb
RSpec.describe 'PWA Icons' do
  it 'has required icon files' do
    expect(File.exist?(Rails.root.join('public/pwa/icon-192.png'))).to be true
    expect(File.exist?(Rails.root.join('public/pwa/icon-512.png'))).to be true
  end

  it 'has correct icon dimensions' do
    require 'mini_magick'

    icon_192 = MiniMagick::Image.open(Rails.root.join('public/pwa/icon-192.png'))
    expect(icon_192.width).to eq(192)
    expect(icon_192.height).to eq(192)

    icon_512 = MiniMagick::Image.open(Rails.root.join('public/pwa/icon-512.png'))
    expect(icon_512.width).to eq(512)
    expect(icon_512.height).to eq(512)
  end
end
```

**Test 3: PWA Configuration API**
```ruby
# spec/requests/api/pwa/configs_spec.rb
RSpec.describe 'Api::Pwa::Configs', type: :request do
  it 'returns valid PWA configuration' do
    get '/api/pwa/config'

    expect(response).to have_http_status(:success)
    config = JSON.parse(response.body)

    expect(config['version']).to be_present
    expect(config['caches']).to be_a(Hash)
    expect(config['network']).to be_a(Hash)
    expect(config['features']).to be_a(Hash)
  end

  it 'includes cache strategy configuration' do
    get '/api/pwa/config'
    config = JSON.parse(response.body)

    expect(config['caches']['static']).to include('name', 'strategy', 'patterns')
    expect(config['caches']['images']).to include('name', 'strategy', 'patterns')
  end
end
```

**Test 4: Service Worker Registration Script (JavaScript)**
```javascript
// spec/javascript/serviceworker_registration.test.js
import { ServiceWorkerRegistration } from 'pwa/service_worker_registration';

describe('Service Worker Registration', () => {
  beforeEach(() => {
    delete navigator.serviceWorker;
  });

  it('registers service worker when supported', async () => {
    const mockRegister = jest.fn().mockResolvedValue({ scope: '/' });
    navigator.serviceWorker = { register: mockRegister };

    const registration = new ServiceWorkerRegistration();
    await registration.register();

    expect(mockRegister).toHaveBeenCalledWith('/serviceworker.js');
  });

  it('does not throw error when unsupported', async () => {
    const registration = new ServiceWorkerRegistration();

    await expect(registration.register()).resolves.toBeNull();
  });
});
```

### 9.2 Integration Testing

**Test 5: Service Worker Lifecycle (Manual Browser Test)**
```javascript
// Test in Chrome DevTools → Application → Service Workers
describe('Service Worker Lifecycle', () => {
  it('Step 1: Register service worker', async () => {
    // Navigate to http://localhost:3000
    // Open DevTools → Application → Service Workers
    // Verify: Status shows "activated and running"
    // Verify: Scope is "http://localhost:3000/"
  });

  it('Step 2: Cache assets on install', async () => {
    // DevTools → Application → Cache Storage
    // Verify: static-v1 cache exists
    // Verify: offline.html is cached
    // Verify: application.css is cached
  });

  it('Step 3: Serve from cache when offline', async () => {
    // DevTools → Network → Throttling → Offline
    // Navigate to /
    // Verify: Page loads from cache
    // Verify: Network shows "(from ServiceWorker)"
  });

  it('Step 4: Update service worker', async () => {
    // Modify serviceworker.js (change cache version)
    // Refresh page
    // DevTools → Application → Service Workers
    // Verify: "waiting to activate" status
    // Click "skipWaiting"
    // Verify: Old caches deleted, new caches created
  });
});
```

**Test 6: Offline Functionality (System Test)**
```ruby
# spec/system/pwa_offline_spec.rb
RSpec.describe 'PWA Offline Functionality', type: :system, js: true do
  before do
    visit root_path
    # Wait for service worker registration
    sleep 1
  end

  it 'displays offline page when network unavailable' do
    # Simulate offline mode (requires browser capability)
    page.driver.browser.network_conditions = { offline: true }

    visit operator_dashboard_path

    expect(page).to have_content('オフラインです')
    expect(page).to have_css('img[alt="Offline Cat"]')
  end

  it 'serves cached public pages offline' do
    # Visit page while online to cache it
    visit terms_path
    expect(page).to have_content('利用規約')

    # Go offline
    page.driver.browser.network_conditions = { offline: true }

    # Navigate to cached page
    visit terms_path
    expect(page).to have_content('利用規約')
  end
end
```

### 9.3 Lighthouse Auditing

**Test 7: PWA Lighthouse Audit**
```bash
# Run Lighthouse CLI
lighthouse http://localhost:3000 \
  --only-categories=pwa \
  --output=html \
  --output-path=./tmp/lighthouse-pwa-report.html

# Expected results:
# - PWA score: ≥ 90/100
# - ✓ Installable
# - ✓ PWA optimized
# - ✓ Fast and reliable
```

**Lighthouse Checklist:**
- [ ] Registers a service worker that controls page and start_url
- [ ] Web app manifest meets installability requirements
- [ ] Configured for a custom splash screen
- [ ] Sets a theme color for the address bar
- [ ] Content sized correctly for viewport
- [ ] Has a <meta name="viewport"> tag with width or initial-scale
- [ ] Provides a valid apple-touch-icon
- [ ] Redirects HTTP traffic to HTTPS
- [ ] Page load is fast enough on mobile networks

### 9.4 Edge Cases Testing

**Test 8: Browser Compatibility**
```javascript
// Test on multiple browsers:
const browsers = [
  { name: 'Chrome', version: '90+', install_supported: true },
  { name: 'Edge', version: '90+', install_supported: true },
  { name: 'Safari', version: '16.4+', install_supported: true },
  { name: 'Firefox', version: '90+', install_supported: false },
  { name: 'Chrome Android', version: '90+', install_supported: true },
  { name: 'Safari iOS', version: '16.4+', install_supported: true }
];

// For each browser:
// 1. Verify service worker registers
// 2. Verify manifest detected (DevTools)
// 3. Verify install prompt appears (if supported)
// 4. Verify offline caching works
```

**Test 9: Cache Size Limits**
```javascript
// Test cache quota handling
it('handles quota exceeded error gracefully', async () => {
  // Fill cache with large assets until quota exceeded
  const largeAsset = new Response('x'.repeat(10 * 1024 * 1024)); // 10MB
  const cache = await caches.open('test-cache');

  try {
    for (let i = 0; i < 100; i++) {
      await cache.put(`/large-asset-${i}`, largeAsset.clone());
    }
  } catch (error) {
    expect(error.name).toBe('QuotaExceededError');
    // Verify old caches get cleaned up
  }
});
```

**Test 10: Turbo Drive Compatibility**
```ruby
# spec/system/pwa_turbo_spec.rb
RSpec.describe 'PWA + Turbo Drive', type: :system, js: true do
  it 'navigates with Turbo without cache conflicts' do
    visit root_path

    # Click link that uses Turbo Drive
    click_link '利用規約'
    expect(page).to have_current_path(terms_path)

    # Verify Turbo handled navigation (no full page reload)
    expect(page).to have_css('body[data-turbo]')

    # Go back with Turbo
    page.go_back
    expect(page).to have_current_path(root_path)
  end
end
```

**Test 11: Install Prompt Behavior**
```javascript
// Manual test checklist:
// 1. Clear browser data for localhost:3000
// 2. Visit site (service worker registers)
// 3. Wait 30 seconds (Chrome requires engagement)
// 4. Verify beforeinstallprompt event fires (console log)
// 5. Click install button (if implemented)
// 6. Verify prompt appears
// 7. Accept prompt
// 8. Verify app appears in app drawer/home screen
// 9. Launch app from home screen
// 10. Verify app opens in standalone mode (no browser UI)
```

### 9.5 Performance Testing

**Test 12: Cache Performance Metrics**
```javascript
// Measure cache hit rate
describe('Cache Performance', () => {
  it('achieves >80% cache hit rate on repeat visits', async () => {
    const requests = [];

    // First visit: Populate cache
    await visitPage('/');

    // Second visit: Measure cache hits
    const cacheHits = requests.filter(r => r.fromCache).length;
    const cacheHitRate = cacheHits / requests.length;

    expect(cacheHitRate).toBeGreaterThan(0.8);
  });

  it('reduces load time by >50% on cached visits', async () => {
    const firstLoadTime = await measurePageLoad('/');
    const cachedLoadTime = await measurePageLoad('/');

    expect(cachedLoadTime).toBeLessThan(firstLoadTime * 0.5);
  });
});
```

---

## 10. Implementation Plan

### 10.1 Phase 1: Foundation (Week 1)

**Tasks:**
1. Create PWA icon assets from cat.webp
   - Generate 192x192px icon
   - Generate 512x512px icon
   - Generate maskable 512x512px icon (optional)
   - Place in `public/pwa/` directory

2. Create manifest controller and configuration
   - Create `ManifestsController#show`
   - Create `config/pwa_config.yml`
   - Configure routes for `/manifest.json`
   - Add I18n translations for manifest

3. Add PWA meta tags to layout
   - Edit `app/views/layouts/application.html.slim`
   - Add manifest link tag
   - Add theme-color meta tag
   - Add apple-mobile-web-app-capable
   - Add apple-touch-icon references

**Deliverables:**
- `/public/pwa/icon-192.png`
- `/public/pwa/icon-512.png`
- `/public/pwa/icon-maskable-512.png`
- `ManifestsController` with dynamic generation
- `config/pwa_config.yml` with environment-specific configs
- Updated `application.html.slim` with PWA meta tags

**Validation:**
- Manifest accessible at http://localhost:3000/manifest.json
- Icons load correctly in browser
- Chrome DevTools → Application → Manifest shows correct data

### 10.2 Phase 2: Service Worker Core (Week 2)

**Tasks:**
1. Create modular service worker structure
   - Write `app/javascript/serviceworker.js` (entry point)
   - Create `pwa/lifecycle_manager.js`
   - Create `pwa/config_loader.js`
   - Create `pwa/cache_manager.js`

2. Implement cache strategy system
   - Create `pwa/strategies/base_strategy.js`
   - Implement `cache_first_strategy.js`
   - Implement `network_first_strategy.js`
   - Implement `network_only_strategy.js`
   - Create `pwa/strategy_router.js`

3. Configure esbuild to compile service worker
   - Update `package.json` build scripts
   - Ensure service worker compiled to `/serviceworker.js`
   - Verify correct content-type header

**Deliverables:**
- Modular service worker architecture
- Pluggable cache strategy system
- Configuration-driven service worker
- Service worker accessible at `/serviceworker.js`

**Validation:**
- Service worker compiles without errors
- All strategy modules load correctly
- Config endpoint returns valid JSON

### 10.3 Phase 3: Registration & Observability (Week 3)

**Tasks:**
1. Create registration and install prompt modules
   - Write `pwa/service_worker_registration.js`
   - Write `pwa/install_prompt_manager.js`
   - Integrate into `application.js`

2. Implement observability system
   - Create `lib/logger.js`
   - Create `lib/metrics.js`
   - Create `lib/tracing.js`
   - Create `lib/health.js`

3. Create backend endpoints
   - Implement `Api::Pwa::ConfigsController`
   - Implement `Api::ClientLogsController`
   - Implement `Api::MetricsController`
   - Create database migrations for logs and metrics

**Deliverables:**
- Service worker registration module
- Install prompt management
- Complete observability system
- Backend API endpoints
- Database schema for observability

**Validation:**
- Service worker registers successfully
- Logs sent to backend endpoint
- Metrics collected and stored
- Health check returns valid data

### 10.4 Phase 4: Offline Support & Testing (Week 4)

**Tasks:**
1. Create offline fallback page
   - Design `public/offline.html` with cat mascot
   - Embed cat image as base64
   - Add minimal inline CSS
   - Test display in browsers

2. Implement complete caching strategies
   - Configure cache strategies in `pwa_config.yml`
   - Test cache-first for static assets
   - Test network-first for HTML pages
   - Test network-only for operator routes

3. Write automated tests
   - RSpec tests for manifest
   - RSpec tests for config API
   - System tests for offline functionality
   - JavaScript tests for registration

**Deliverables:**
- `/public/offline.html`
- Complete cache strategy configuration
- Full test suite
- Offline testing checklist completed

**Validation:**
- Navigate to cached page while offline → page loads
- Navigate to uncached page while offline → offline.html displays
- Operator routes offline → offline.html (not cached admin data)
- All tests passing

### 10.5 Phase 5: Polish & Launch (Week 5)

**Tasks:**
1. Performance optimization
   - Minimize service worker file size
   - Optimize cache sizes
   - Implement cache expiration
   - Add cache version management

2. Run Lighthouse audits
   - Achieve PWA score ≥ 90
   - Fix any identified issues
   - Document results

3. Cross-browser testing
   - Test on Chrome, Edge, Safari, Firefox
   - Test on iOS and Android
   - Verify graceful degradation

4. Deploy to production
   - Deploy with HTTPS enabled
   - Verify service worker registers in production
   - Monitor for errors
   - Set up alerting

**Deliverables:**
- Optimized service worker
- Lighthouse audit report (≥ 90 score)
- Browser compatibility matrix
- Production deployment checklist
- Monitoring dashboard setup

**Validation:**
- All tests passing
- Lighthouse PWA audit ≥ 90/100
- No console errors in production
- Install prompt appears for users
- Metrics being collected successfully

---

## 11. Success Metrics

### 11.1 Technical Metrics

**Metric 1: Lighthouse PWA Score**
- **Target**: ≥ 90/100
- **Measurement**: Run Lighthouse audit on production URL
- **Success Criteria**: All core PWA criteria met (installable, fast, reliable)

**Metric 2: Service Worker Registration Rate**
- **Target**: ≥ 95% of visitors (on supported browsers)
- **Measurement**: Track `service_worker_registration` metric
- **Tracking**: Custom `/api/metrics` endpoint

**Metric 3: Cache Hit Rate**
- **Target**: ≥ 80% for repeat visitors
- **Measurement**: Track `cache_hit` metric in service worker
- **Tracking**: Custom `/api/metrics` endpoint

**Metric 4: Install Conversion Rate**
- **Target**: ≥ 5% of eligible visitors install app
- **Measurement**: Track `install_prompt` metric (shown vs accepted)
- **Tracking**: Custom `/api/metrics` endpoint + Google Analytics

**Metric 5: Offline Page Views**
- **Target**: < 1% of total page views (most content cached)
- **Measurement**: Track offline.html views via service worker
- **Tracking**: Custom metrics endpoint

### 11.2 Performance Metrics

**Metric 6: Time to First Paint (FP)**
- **Baseline**: Current average (uncached)
- **Target**: 50% improvement on cached visits
- **Measurement**: `performance.getEntriesByType('navigation')`
- **Success Criteria**: Cached FP < 500ms

**Metric 7: Time to Interactive (TTI)**
- **Baseline**: Current average
- **Target**: 40% improvement on cached visits
- **Measurement**: Lighthouse performance audit
- **Success Criteria**: Cached TTI < 2 seconds

**Metric 8: Cache Storage Usage**
- **Target**: < 50MB per user
- **Measurement**: `navigator.storage.estimate()`
- **Success Criteria**: No quota exceeded errors in logs

### 11.3 User Engagement Metrics

**Metric 9: App Install Count**
- **Target**: ≥ 100 installs in first month
- **Measurement**: Track `appinstalled` events
- **Tracking**: Custom metrics + Google Analytics

**Metric 10: Standalone Mode Sessions**
- **Target**: ≥ 30% of sessions for installed users
- **Measurement**: Detect `display-mode: standalone` media query
- **Tracking**: Google Analytics custom dimension

**Metric 11: Return Visitor Rate (Installed vs Web)**
- **Hypothesis**: Installed users return more frequently
- **Measurement**: Compare return rate of standalone sessions vs browser sessions
- **Tracking**: Google Analytics cohort analysis

### 11.4 Error Metrics

**Metric 12: Service Worker Error Rate**
- **Target**: < 0.1% of registrations fail
- **Measurement**: Track `service_worker_registration` failures
- **Tracking**: Client logs + Sentry

**Metric 13: Cache Failure Rate**
- **Target**: < 0.5% of cache operations fail
- **Measurement**: Track cache operation errors in service worker
- **Tracking**: Client logs

**Metric 14: Manifest Parse Error Rate**
- **Target**: 0 manifest errors
- **Measurement**: Monitor browser console errors
- **Tracking**: Client logs + Sentry

---

## 12. Rollout Plan

### 12.1 Development Phase (Weeks 1-5)

- Implement all PWA components per Implementation Plan
- Test on localhost:3000
- Achieve Lighthouse score ≥ 90 in development

### 12.2 Staging Deployment (Week 6)

- Deploy to staging environment (with HTTPS)
- Run full test suite
- Perform manual cross-browser testing
- Fix any staging-specific issues

### 12.3 Beta Launch (Week 7)

- Deploy to production
- Enable PWA features for 10% of users (feature flag)
- Monitor error rates and metrics
- Collect user feedback

### 12.4 Full Launch (Week 8)

- Enable PWA for 100% of users
- Announce PWA availability (blog post, social media)
- Monitor adoption metrics
- Plan future enhancements

### 12.5 Post-Launch Monitoring

- Track all success metrics weekly
- Review service worker logs for errors
- Monitor Lighthouse scores monthly
- Plan iteration based on feedback

---

## 13. Future Enhancements

### 13.1 Push Notifications (Phase 2)

**Architecture designed for extensibility:**

```ruby
# Database schema ready for push notifications
class CreatePushSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :push_subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :endpoint, null: false, index: { unique: true }
      t.text :p256dh_key
      t.text :auth_key
      t.string :user_agent
      t.datetime :last_sent_at

      t.timestamps
    end
  end
end
```

**API endpoints:**
- `POST /api/push_subscriptions` - Subscribe to push notifications
- `DELETE /api/push_subscriptions/:id` - Unsubscribe

**Client-side implementation:**
```javascript
// app/javascript/pwa/notifications/notification_service.js (interface)
export class NotificationService {
  async requestPermission() { throw new Error('Must implement'); }
  async subscribe(options) { throw new Error('Must implement'); }
  async unsubscribe() { throw new Error('Must implement'); }
}

// app/javascript/pwa/notifications/web_push_service.js
export class WebPushService extends NotificationService {
  async requestPermission() {
    return await Notification.requestPermission();
  }

  async subscribe(options) {
    const registration = await navigator.serviceWorker.ready;
    return await registration.pushManager.subscribe(options);
  }
}
```

### 13.2 Background Sync (Phase 3)

**Architecture designed for extensibility:**

```javascript
// app/javascript/pwa/sync/sync_queue.js
export class SyncQueue {
  async enqueue(request, data) {
    // Store in IndexedDB for offline persistence
    const db = await this.openDB();
    return db.add('queue', { request, data, timestamp: Date.now() });
  }

  async processQueue() {
    const items = await this.getAllQueued();
    for (const item of items) {
      try {
        await fetch(item.request, { body: JSON.stringify(item.data) });
        await this.remove(item.id);
      } catch (error) {
        await this.updateRetryCount(item.id);
      }
    }
  }
}

// Service worker sync event handler
self.addEventListener('sync', (event) => {
  if (event.tag === 'sync-queue') {
    event.waitUntil(new SyncQueue().processQueue());
  }
});
```

### 13.3 Advanced Caching (Phase 4)

- Implement stale-while-revalidate strategy (already designed)
- Add predictive prefetching for likely next pages
- Create separate cache for user-specific data (if applicable)

**Already supported via pluggable strategy system:**

```javascript
// Just add new strategy class
import { StaleWhileRevalidateStrategy } from './strategies/stale_while_revalidate_strategy';

// Register in config
{
  caches: {
    dynamic: {
      strategy: 'stale-while-revalidate',
      patterns: ['^/api/'],
      maxAge: 300000
    }
  }
}
```

### 13.4 App Shortcuts (Phase 5)

- Add app shortcuts to manifest for quick actions
- Example: "Send Message", "View Groups", "Settings"
- Accessible from app icon long-press

```json
{
  "shortcuts": [
    {
      "name": "Send Message",
      "short_name": "Send",
      "url": "/operator/messages/new",
      "icons": [{ "src": "/pwa/shortcut-send.png", "sizes": "96x96" }]
    },
    {
      "name": "View Groups",
      "short_name": "Groups",
      "url": "/operator/groups",
      "icons": [{ "src": "/pwa/shortcut-groups.png", "sizes": "96x96" }]
    }
  ]
}
```

---

## 14. Appendix

### 14.1 References

- [PWA Checklist - web.dev](https://web.dev/pwa-checklist/)
- [Service Worker API - MDN](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API)
- [Web App Manifest - MDN](https://developer.mozilla.org/en-US/docs/Web/Manifest)
- [Workbox (Google's Service Worker Library)](https://developers.google.com/web/tools/workbox)
- [Rails Asset Pipeline - Propshaft](https://github.com/rails/propshaft)
- [Sentry Browser SDK](https://docs.sentry.io/platforms/javascript/)

### 14.2 File Structure

```
cat_salvages_the_relationship/
├── app/
│   ├── assets/
│   │   └── builds/
│   │       └── (manifest.json served dynamically)
│   ├── controllers/
│   │   ├── manifests_controller.rb
│   │   └── api/
│   │       ├── client_logs_controller.rb
│   │       ├── metrics_controller.rb
│   │       └── pwa/
│   │           └── configs_controller.rb
│   ├── javascript/
│   │   ├── application.js
│   │   ├── serviceworker.js (entry point)
│   │   ├── lib/
│   │   │   ├── logger.js
│   │   │   ├── metrics.js
│   │   │   ├── tracing.js
│   │   │   └── health.js
│   │   └── pwa/
│   │       ├── lifecycle_manager.js
│   │       ├── strategy_router.js
│   │       ├── cache_manager.js
│   │       ├── config_loader.js
│   │       ├── service_worker_registration.js
│   │       ├── install_prompt_manager.js
│   │       └── strategies/
│   │           ├── base_strategy.js
│   │           ├── cache_first_strategy.js
│   │           ├── network_first_strategy.js
│   │           ├── network_only_strategy.js
│   │           └── stale_while_revalidate_strategy.js
│   ├── models/
│   │   ├── client_log.rb
│   │   ├── metric.rb
│   │   └── pwa_alert_monitor.rb
│   └── views/
│       └── layouts/
│           └── application.html.slim (PWA meta tags)
├── config/
│   ├── locales/
│   │   ├── pwa.ja.yml
│   │   └── pwa.en.yml
│   ├── pwa_config.yml
│   └── routes.rb
├── public/
│   ├── pwa/
│   │   ├── icon-192.png
│   │   ├── icon-512.png
│   │   └── icon-maskable-512.png
│   └── offline.html
├── spec/
│   ├── requests/
│   │   ├── manifest_spec.rb
│   │   └── api/
│   │       └── pwa/
│   │           └── configs_spec.rb
│   ├── system/
│   │   ├── pwa_offline_spec.rb
│   │   └── pwa_turbo_spec.rb
│   ├── javascript/
│   │   └── serviceworker_registration.test.js
│   └── assets/
│       └── pwa_icons_spec.rb
└── docs/
    └── designs/
        └── pwa-implementation.md (this document)
```

### 14.3 Browser Compatibility Matrix

| Browser           | Version | Service Worker | Manifest | Install Prompt | Standalone Mode |
|-------------------|---------|----------------|----------|----------------|-----------------|
| Chrome (Desktop)  | 90+     | ✅             | ✅       | ✅             | ✅              |
| Chrome (Android)  | 90+     | ✅             | ✅       | ✅             | ✅              |
| Edge (Desktop)    | 90+     | ✅             | ✅       | ✅             | ✅              |
| Safari (Desktop)  | 16.4+   | ✅             | ✅       | ✅             | ✅              |
| Safari (iOS)      | 16.4+   | ✅             | ✅       | ✅             | ✅              |
| Firefox (Desktop) | 90+     | ✅             | ⚠️       | ❌             | ❌              |
| Firefox (Android) | 90+     | ✅             | ⚠️       | ❌             | ❌              |

Legend:
- ✅ Full support
- ⚠️ Partial support (manifest recognized but install not supported)
- ❌ Not supported

### 14.4 Glossary

- **PWA**: Progressive Web App - web application with native app-like capabilities
- **Service Worker**: JavaScript worker script that runs in background, intercepts network requests
- **Manifest**: JSON file describing web app metadata for installation
- **Cache-First**: Strategy that serves from cache if available, falls back to network
- **Network-First**: Strategy that tries network first, falls back to cache if offline
- **Standalone Mode**: Display mode where app opens without browser UI
- **Installability**: Criteria that must be met for browser to offer installation
- **beforeinstallprompt**: Browser event fired when PWA installability criteria met
- **Propshaft**: Rails 7+ asset pipeline (replacement for Sprockets)
- **Observability**: Ability to understand system state through logs, metrics, and traces

---

**End of Design Document**

**Next Steps:**
1. Design document updated based on evaluator feedback
2. Main Claude Code should re-execute design evaluators for validation
3. Address any remaining feedback
4. Proceed to Phase 2 (Planning) once approved
