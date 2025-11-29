# Task Plan - Progressive Web App Implementation

**Feature ID**: FEAT-PWA-001
**Design Document**: docs/designs/pwa-implementation.md
**Created**: 2025-11-29
**Planner**: planner agent

---

## Metadata

```yaml
task_plan_metadata:
  feature_id: "FEAT-PWA-001"
  feature_name: "Progressive Web App Implementation"
  total_tasks: 32
  estimated_duration: "4-5 weeks"
  critical_path: ["PWA-001", "PWA-005", "PWA-010", "PWA-015", "PWA-020", "PWA-025", "PWA-30"]
  scope: "MVP - Installability, offline support, basic caching (Phases 1-4)"
```

---

## 1. Overview

**Feature Summary**: Transform ReLINE into a Progressive Web App with installability, offline support, and optimized asset caching. This implementation enables "Add to Home Screen" functionality, provides offline access to public pages, and improves performance through service worker caching strategies.

**Total Tasks**: 32 tasks
**Execution Phases**: 4 major phases (Foundation → Service Worker → Observability → Testing)
**Parallel Opportunities**: 15 tasks can run in parallel across different phases

**Technology Stack**:
- Rails 8.1 with Propshaft + esbuild
- Vanilla JavaScript (no Workbox)
- MySQL 8.0 for metrics/logs storage
- RSpec for testing

**Out of Scope (Future Phases)**:
- Push notifications
- Background sync
- Advanced caching strategies (stale-while-revalidate)

---

## 2. Task Breakdown

### Phase 1: Foundation (PWA Icons, Manifest, Meta Tags)

#### PWA-001: Generate PWA Icon Assets
**Description**: Create required PWA icons (192x192, 512x512, maskable) from existing cat.webp mascot image.

**Dependencies**: None

**Worker Type**: `frontend-worker`

**Deliverables**:
- `/public/pwa/icon-192.png` (192x192px PNG with transparency)
- `/public/pwa/icon-512.png` (512x512px PNG with transparency)
- `/public/pwa/icon-maskable-512.png` (512x512px PNG maskable format)
- `/public/pwa/.gitkeep` (ensure directory tracked)

**Acceptance Criteria**:
- All icons generated from `app/assets/images/cat.webp`
- Icons have correct dimensions (verify with ImageMagick)
- PNG format with transparency preserved
- Maskable icon has safe zone padding (20% minimum)
- File sizes optimized (< 50KB each)

**Estimated Complexity**: Low

**Implementation Notes**:
- Use ImageMagick or similar tool for image conversion
- Ensure cat mascot is centered in icon
- Add padding for maskable icon to prevent cropping

---

#### PWA-002: Create PWA Configuration File
**Description**: Create `config/pwa_config.yml` with environment-specific PWA settings (cache versions, theme colors, feature flags).

**Dependencies**: None

**Worker Type**: `backend-worker`

**Deliverables**:
- `/config/pwa_config.yml` with sections:
  - `defaults`: Base configuration
  - `development`: Dev-specific overrides (red theme)
  - `staging`: Staging overrides (yellow theme)
  - `production`: Production overrides

**Acceptance Criteria**:
- YAML file validates without syntax errors
- Contains all required keys: `cache`, `network`, `manifest`, `features`
- Cache strategies defined for: static, images, pages
- Theme colors specified for each environment
- Feature flags for: install_prompt, push_notifications (disabled), background_sync (disabled)
- Network timeout and retry configuration present

**Estimated Complexity**: Low

**Implementation Notes**:
- Follow structure from design document section 3.4
- Use YAML anchors for DRY configuration
- Document all configuration options with comments

---

#### PWA-003: Create ManifestsController
**Description**: Implement Rails controller to dynamically generate manifest.json with I18n support.

**Dependencies**: [PWA-001, PWA-002]

**Worker Type**: `backend-worker`

**Deliverables**:
- `/app/controllers/manifests_controller.rb` with `show` action
- Route: `GET /manifest.json` mapped to `manifests#show`
- Controller sets `Content-Type: application/manifest+json`
- Dynamic icon paths reference `/pwa/icon-*.png`

**Acceptance Criteria**:
- Controller generates valid manifest JSON per Web App Manifest spec
- Includes all required fields: `name`, `short_name`, `start_url`, `display`, `icons`
- Icons array references PWA-001 icon files
- `theme_color` and `background_color` loaded from `pwa_config.yml`
- Start URL includes UTM tracking: `/?utm_source=pwa&utm_medium=homescreen`
- Manifest responds with correct MIME type
- Supports I18n (uses `I18n.t()` for name/description)

**Estimated Complexity**: Medium

**Implementation Notes**:
- Use `Rails.application.config_for(:pwa_config)` to load config
- Implement private method `icon_definitions` to generate icon array
- Include `categories: ['productivity', 'social']`
- Set `lang` and `dir` based on current locale

---

#### PWA-004: Add I18n Translations for Manifest
**Description**: Create translation files for PWA manifest strings (app name, description) in English and Japanese.

**Dependencies**: None

**Worker Type**: `backend-worker`

**Deliverables**:
- `/config/locales/pwa.en.yml` with English translations
- `/config/locales/pwa.ja.yml` with Japanese translations
- Keys: `pwa.name`, `pwa.short_name`, `pwa.description`

**Acceptance Criteria**:
- Both locale files validate as valid YAML
- English translations:
  - `name`: "ReLINE - Cat Relationship Manager"
  - `short_name`: "ReLINE"
  - `description`: "LINE bot service for maintaining relationships"
- Japanese translations:
  - `name`: "ReLINE - ネコと関係を管理"
  - `short_name`: "ReLINE"
  - `description`: "LINEボットで関係を維持するサービス"

**Estimated Complexity**: Low

---

#### PWA-005: Add PWA Meta Tags to Application Layout
**Description**: Update `application.html.slim` to include PWA-required meta tags and manifest link.

**Dependencies**: [PWA-003]

**Worker Type**: `frontend-worker`

**Deliverables**:
- Updated `/app/views/layouts/application.html.slim` with:
  - `<link rel="manifest" href="/manifest.json">`
  - `<meta name="theme-color" content="#0d6efd">`
  - `<meta name="apple-mobile-web-app-capable" content="yes">`
  - `<meta name="apple-mobile-web-app-status-bar-style" content="default">`
  - `<link rel="apple-touch-icon" href="/pwa/icon-192.png">`

**Acceptance Criteria**:
- All meta tags added to `<head>` section
- Manifest link appears before other resources
- Theme color matches Bootstrap primary color (#0d6efd)
- Apple-specific tags for iOS PWA support
- Viewport meta tag already exists (verify configuration)
- No duplicate meta tags introduced

**Estimated Complexity**: Low

**Implementation Notes**:
- Place manifest link tag near top of `<head>`
- Ensure theme-color is dynamically loaded in future (hardcode for MVP)

---

### Phase 2: Service Worker Core (Modular Architecture)

#### PWA-006: Create Service Worker Entry Point
**Description**: Create main service worker file (`serviceworker.js`) with event listeners for install, activate, fetch.

**Dependencies**: None

**Worker Type**: `frontend-worker`

**Deliverables**:
- `/app/javascript/serviceworker.js` with:
  - Import statements for lifecycle_manager, strategy_router, config_loader
  - `install` event listener
  - `activate` event listener
  - `fetch` event listener
  - Global variables for manager instances

**Acceptance Criteria**:
- File uses ES6 module syntax (import/export)
- All event listeners use `event.waitUntil()` for async operations
- Service worker compiles without errors via esbuild
- Install event loads config and initializes managers
- Activate event delegates to lifecycle_manager
- Fetch event delegates to strategy_router

**Estimated Complexity**: Medium

**Implementation Notes**:
- Keep this file minimal - delegate logic to modules
- Use `self` context for service worker scope
- Handle errors gracefully with try-catch

---

#### PWA-007: Create LifecycleManager Module
**Description**: Implement service worker lifecycle management (install/activate events, cache initialization, old cache cleanup).

**Dependencies**: None

**Worker Type**: `frontend-worker`

**Deliverables**:
- `/app/javascript/pwa/lifecycle_manager.js` exporting `LifecycleManager` class
- Methods:
  - `constructor(config)` - Initialize with cache names
  - `handleInstall()` - Pre-cache critical assets
  - `handleActivate()` - Delete old caches, claim clients

**Acceptance Criteria**:
- Class accepts config object in constructor
- `handleInstall()` creates offline cache and pre-caches: `['/offline.html']`
- `handleInstall()` pre-caches critical static assets (root path, CSS, JS, cat.webp)
- `handleInstall()` calls `self.skipWaiting()` to activate immediately
- `handleActivate()` deletes caches not in current version
- `handleActivate()` calls `self.clients.claim()` to control all pages
- Generates cache names with version suffix (e.g., "static-v1")

**Estimated Complexity**: Medium

**Implementation Notes**:
- Use `caches.open()` and `cache.addAll()` for pre-caching
- Use `caches.keys()` and `caches.delete()` for cleanup
- Log lifecycle events for debugging

---

#### PWA-008: Create ConfigLoader Module
**Description**: Implement module to fetch PWA configuration from backend API endpoint.

**Dependencies**: None

**Worker Type**: `frontend-worker`

**Deliverables**:
- `/app/javascript/pwa/config_loader.js` exporting `ConfigLoader` class
- Static method: `load()` - Fetches `/api/pwa/config` and returns JSON
- Static method: `getDefaults()` - Returns fallback config if API fails

**Acceptance Criteria**:
- `load()` makes fetch request to `/api/pwa/config`
- Returns parsed JSON config object
- On fetch failure, logs warning and returns `getDefaults()`
- Default config includes basic cache strategies for static, images
- Handles network errors gracefully
- Returns promise resolving to config object

**Estimated Complexity**: Low

**Implementation Notes**:
- Use try-catch for error handling
- Default config should match production config structure
- Cache config locally in service worker (future optimization)

---

#### PWA-009: Create CacheStrategy Base Class
**Description**: Implement abstract base class for all caching strategies with common methods.

**Dependencies**: None

**Worker Type**: `frontend-worker`

**Deliverables**:
- `/app/javascript/pwa/strategies/base_strategy.js` exporting `CacheStrategy` class
- Methods:
  - `constructor(cacheName, options)` - Initialize strategy
  - `handle(request)` - Abstract method (throws error)
  - `cacheResponse(request, response)` - Store response in cache
  - `shouldCache(response)` - Validate response before caching
  - `fetchWithTimeout(request, timeout)` - Network fetch with timeout
  - `getFallback()` - Return offline.html from cache

**Acceptance Criteria**:
- Base class is not directly instantiated (abstract)
- `handle()` method throws error if not overridden
- `shouldCache()` validates: status 200, type 'basic', not opaque
- `fetchWithTimeout()` uses AbortController for timeout
- `getFallback()` returns cached offline.html
- All methods return promises
- Error handling in `fetchWithTimeout()` cleans up timeout

**Estimated Complexity**: Medium

**Implementation Notes**:
- Use AbortController API for fetch timeout
- Clone responses before caching (response streams single-use)
- Document method signatures with JSDoc comments

---

#### PWA-010: Implement CacheFirstStrategy
**Description**: Create cache-first caching strategy (serve from cache, fall back to network).

**Dependencies**: [PWA-009]

**Worker Type**: `frontend-worker`

**Deliverables**:
- `/app/javascript/pwa/strategies/cache_first_strategy.js` exporting `CacheFirstStrategy` class
- Extends `CacheStrategy`
- Methods:
  - `handle(request)` - Check cache first, then network
  - `updateCacheInBackground(request)` - Update cache after serving

**Acceptance Criteria**:
- Class extends `CacheStrategy` base class
- `handle()` checks cache with `caches.match(request)`
- If cache hit, returns cached response immediately
- If cache hit, triggers background cache update
- If cache miss, fetches from network
- Network response is cached before returning
- Background update fails silently (already served from cache)

**Estimated Complexity**: Low

**Implementation Notes**:
- Used for static assets (CSS, JS, fonts)
- Background update improves cache freshness
- Don't await background update (fire-and-forget)

---

#### PWA-011: Implement NetworkFirstStrategy
**Description**: Create network-first caching strategy (try network with timeout, fall back to cache).

**Dependencies**: [PWA-009]

**Worker Type**: `frontend-worker`

**Deliverables**:
- `/app/javascript/pwa/strategies/network_first_strategy.js` exporting `NetworkFirstStrategy` class
- Extends `CacheStrategy`
- Methods:
  - `handle(request)` - Try network first, then cache, then offline fallback

**Acceptance Criteria**:
- Class extends `CacheStrategy` base class
- `handle()` calls `fetchWithTimeout(request, timeout)` from base class
- Default timeout is 3000ms (or from config)
- On network success, caches response clone before returning
- On network failure (timeout or error), checks cache
- If cache hit, returns cached response
- If cache miss, returns `getFallback()` (offline.html)

**Estimated Complexity**: Low

**Implementation Notes**:
- Used for HTML pages that change frequently
- Timeout prevents long waits on slow networks
- Always try network first for freshest content

---

#### PWA-012: Implement NetworkOnlyStrategy
**Description**: Create network-only strategy (never cache, only network).

**Dependencies**: [PWA-009]

**Worker Type**: `frontend-worker`

**Deliverables**:
- `/app/javascript/pwa/strategies/network_only_strategy.js` exporting `NetworkOnlyStrategy` class
- Extends `CacheStrategy`
- Methods:
  - `handle(request)` - Fetch from network only, fallback to offline.html on error

**Acceptance Criteria**:
- Class extends `CacheStrategy` base class
- `handle()` calls `fetch(request)` directly
- No caching of request or response
- On network error, returns `getFallback()` (offline.html)
- Used for authenticated/dynamic routes (operator dashboard)

**Estimated Complexity**: Low

**Implementation Notes**:
- Used for admin/operator routes that should never be cached
- Prevents caching of sensitive data
- Simplest strategy implementation

---

#### PWA-013: Create StrategyRouter Module
**Description**: Implement router to match requests to appropriate caching strategies based on URL patterns.

**Dependencies**: [PWA-010, PWA-011, PWA-012]

**Worker Type**: `frontend-worker`

**Deliverables**:
- `/app/javascript/pwa/strategy_router.js` exporting `StrategyRouter` class
- Methods:
  - `constructor(config)` - Initialize strategies from config
  - `initializeStrategies(config)` - Create strategy instances
  - `getStrategyClass(strategyName)` - Map string to class
  - `handleFetch(event)` - Route fetch event to strategy
  - `findStrategy(url)` - Match URL to strategy by pattern

**Acceptance Criteria**:
- Constructor accepts config with `caches` object
- `initializeStrategies()` creates strategy instances for each cache config
- Supports pattern matching with RegExp
- `handleFetch()` finds matching strategy and calls `strategy.handle(request)`
- If no strategy matches, performs normal `fetch(request)`
- Strategy map includes: cache-first, network-first, network-only
- Returns promise resolving to Response object

**Estimated Complexity**: Medium

**Implementation Notes**:
- Store strategies in array with pattern + strategy instance
- Use `Array.find()` to match URL against patterns
- Default to network-only if no match

---

#### PWA-014: Configure esbuild for Service Worker Compilation
**Description**: Update build configuration to compile service worker separately and output to `/serviceworker.js`.

**Dependencies**: [PWA-006, PWA-007, PWA-008, PWA-013]

**Worker Type**: `backend-worker`

**Deliverables**:
- Updated `/package.json` build scripts:
  - Add `build:serviceworker` script
  - Update `build` script to include service worker
- Configure esbuild to:
  - Input: `app/javascript/serviceworker.js`
  - Output: `public/serviceworker.js` (NOT in assets directory)
  - Format: IIFE (immediately invoked function expression)
  - Target: ES2020 minimum

**Acceptance Criteria**:
- Service worker compiles to `/public/serviceworker.js`
- Accessible at `http://localhost:3000/serviceworker.js`
- Correct Content-Type header: `application/javascript` or `text/javascript`
- Service worker served from root scope (not `/assets/`)
- No errors during compilation
- All module imports resolved correctly
- Build script runs without errors

**Estimated Complexity**: Medium

**Implementation Notes**:
- Service worker MUST be served from root domain for proper scope
- Cannot use asset pipeline (would add digest to filename)
- Consider watching service worker file in development
- May need custom Rails route to serve from public/

---

### Phase 3: Observability & Backend APIs

#### PWA-015: Create Api::Pwa::ConfigsController
**Description**: Implement API endpoint to serve PWA configuration JSON to service worker.

**Dependencies**: [PWA-002]

**Worker Type**: `backend-worker`

**Deliverables**:
- `/app/controllers/api/pwa/configs_controller.rb` with `show` action
- Route: `GET /api/pwa/config` mapped to `api/pwa/configs#show`
- Controller returns JSON config from `pwa_config.yml` + environment variables

**Acceptance Criteria**:
- Controller loads config with `Rails.application.config_for(:pwa_config)`
- Returns JSON with keys: `version`, `caches`, `network`, `manifest`, `features`
- Cache strategies converted to JSON-friendly format (arrays of patterns)
- Environment-specific config section loaded (development/staging/production)
- Environment variables override config file values (if present)
- Responds with `Content-Type: application/json`
- CSRF verification skipped (public API)
- No authentication required (public endpoint)

**Estimated Complexity**: Medium

**Implementation Notes**:
- Use `skip_before_action :verify_authenticity_token`
- Convert RegExp patterns to strings for JSON serialization
- Document expected response schema with comments

---

#### PWA-016: Create ClientLog Model and Migration
**Description**: Create database model to store client-side logs (errors, warnings) sent from service worker.

**Dependencies**: None

**Worker Type**: `database-worker`

**Deliverables**:
- Migration: `db/migrate/YYYYMMDDHHMMSS_create_client_logs.rb`
- Model: `/app/models/client_log.rb`
- Columns:
  - `id` (bigint, primary key)
  - `level` (string, required) - "error", "warn", "info", "debug"
  - `message` (text, required)
  - `context` (json) - Structured log data
  - `user_agent` (text)
  - `url` (text)
  - `trace_id` (string, indexed)
  - `created_at` (timestamp)

**Acceptance Criteria**:
- Migration creates `client_logs` table
- All columns have correct types and constraints
- Index on `trace_id` for correlation
- Index on `level` and `created_at` for querying
- Model validates presence of `level` and `message`
- Model validates `level` inclusion in: ["error", "warn", "info", "debug"]
- JSON column uses MySQL JSON type (not text)

**Estimated Complexity**: Low

**Implementation Notes**:
- Consider partitioning by `created_at` for large datasets
- Add index on `created_at` for log retention cleanup
- Document expected `context` JSON structure

---

#### PWA-017: Create Metric Model and Migration
**Description**: Create database model to store PWA metrics (cache hits, service worker events).

**Dependencies**: None

**Worker Type**: `database-worker`

**Deliverables**:
- Migration: `db/migrate/YYYYMMDDHHMMSS_create_metrics.rb`
- Model: `/app/models/metric.rb`
- Columns:
  - `id` (bigint, primary key)
  - `name` (string, required, indexed) - Metric name
  - `value` (decimal, required) - Metric value
  - `unit` (string) - Unit of measurement
  - `tags` (json) - Structured tags (e.g., {strategy: "cache-first"})
  - `trace_id` (string, indexed)
  - `created_at` (timestamp)

**Acceptance Criteria**:
- Migration creates `metrics` table
- Index on `name` and `created_at` for time-series queries
- Index on `trace_id` for distributed tracing
- Model validates presence of `name` and `value`
- JSON tags column for flexible querying
- Consider composite index on (name, created_at) for performance

**Estimated Complexity**: Low

**Implementation Notes**:
- Design for high write volume (consider batch inserts)
- Plan data retention policy (e.g., keep 90 days)
- Document common metric names in model comments

---

#### PWA-018: Create Api::ClientLogsController
**Description**: Implement API endpoint to receive client-side logs from browser/service worker.

**Dependencies**: [PWA-016]

**Worker Type**: `backend-worker`

**Deliverables**:
- `/app/controllers/api/client_logs_controller.rb` with `create` action
- Route: `POST /api/client_logs` mapped to `api/client_logs#create`
- Accepts JSON array of log entries
- Batch inserts logs to database

**Acceptance Criteria**:
- Controller accepts `logs` parameter (array of log objects)
- Each log object contains: `level`, `message`, `context`, `url`, `trace_id`
- Extracts `user_agent` from request headers
- Uses `ClientLog.insert_all` for batch insert (Rails 6+)
- Returns `201 Created` on success
- Returns `422 Unprocessable Entity` on validation error
- Rate limiting applied (prevent abuse)
- CSRF verification skipped (cross-origin requests)

**Estimated Complexity**: Medium

**Implementation Notes**:
- Use `insert_all` instead of `create` for performance
- Validate log entry structure before insert
- Consider async job for large batches
- Add request size limit (e.g., max 100 logs per request)

---

#### PWA-019: Create Api::MetricsController
**Description**: Implement API endpoint to receive PWA metrics from service worker.

**Dependencies**: [PWA-017]

**Worker Type**: `backend-worker`

**Deliverables**:
- `/app/controllers/api/metrics_controller.rb` with `create` action
- Route: `POST /api/metrics` mapped to `api/metrics#create`
- Accepts JSON array of metric entries
- Batch inserts metrics to database

**Acceptance Criteria**:
- Controller accepts `metrics` parameter (array of metric objects)
- Each metric object contains: `name`, `value`, `unit`, `tags`, `trace_id`
- Uses `Metric.insert_all` for batch insert
- Returns `201 Created` on success
- Returns `422 Unprocessable Entity` on validation error
- Rate limiting applied
- CSRF verification skipped

**Estimated Complexity**: Medium

**Implementation Notes**:
- Similar implementation to ClientLogsController
- Consider aggregation before insert (e.g., sum cache hits)
- Plan for high write volume

---

#### PWA-020: Create Client-Side Logger Module
**Description**: Implement JavaScript module for structured logging with buffering and batch sending to backend.

**Dependencies**: [PWA-018]

**Worker Type**: `frontend-worker`

**Deliverables**:
- `/app/javascript/lib/logger.js` exporting `Logger` class
- Methods:
  - `error(message, context)` - Log error level
  - `warn(message, context)` - Log warning level
  - `info(message, context)` - Log info level
  - `debug(message, context)` - Log debug level
  - `flush()` - Send buffered logs to backend
- Singleton instance exported as `logger`

**Acceptance Criteria**:
- Logs buffered in memory (max 50 entries)
- Auto-flush when buffer full or every 30 seconds
- Each log includes: timestamp, level, message, context, URL, trace_id
- Generates trace_id if not provided (UUID v4)
- Posts to `/api/client_logs` endpoint
- Handles network errors gracefully (retries once)
- Console.log() mirroring for development debugging
- Structured context (object) serialized to JSON

**Estimated Complexity**: Medium

**Implementation Notes**:
- Use `setInterval()` for periodic flush
- Use `navigator.sendBeacon()` for reliable delivery on page unload
- Store failed logs in IndexedDB for retry (future enhancement)

---

#### PWA-021: Create Client-Side Metrics Module
**Description**: Implement JavaScript module for collecting and sending PWA metrics to backend.

**Dependencies**: [PWA-019]

**Worker Type**: `frontend-worker`

**Deliverables**:
- `/app/javascript/lib/metrics.js` exporting `Metrics` class
- Methods:
  - `record(name, value, options)` - Record metric
  - `increment(name, tags)` - Increment counter
  - `timing(name, duration, tags)` - Record timing
  - `flush()` - Send buffered metrics
- Singleton instance exported as `metrics`

**Acceptance Criteria**:
- Metrics buffered in memory (max 100 entries)
- Auto-flush every 60 seconds or when buffer full
- Each metric includes: name, value, unit, tags, trace_id, timestamp
- Posts to `/api/metrics` endpoint
- Common metrics pre-defined:
  - `service_worker_registration` (count)
  - `cache_hit` (count)
  - `cache_miss` (count)
  - `install_prompt_shown` (count)
  - `app_installed` (count)
- Tags support for filtering (e.g., {strategy: "cache-first"})

**Estimated Complexity**: Medium

**Implementation Notes**:
- Use Performance API for timing measurements
- Aggregate duplicate metrics before flush (sum values)
- Use `navigator.sendBeacon()` for page unload

---

#### PWA-022: Create Tracing Module
**Description**: Implement distributed tracing support (trace ID generation and propagation).

**Dependencies**: None

**Worker Type**: `frontend-worker`

**Deliverables**:
- `/app/javascript/lib/tracing.js` exporting:
  - `generateTraceId()` - Generate UUID v4
  - `getCurrentTraceId()` - Get trace ID from context
  - `setTraceId(id)` - Set trace ID for current context
  - `withTrace(fn)` - Execute function with trace context

**Acceptance Criteria**:
- `generateTraceId()` returns valid UUID v4 string
- Trace ID stored in closure/global variable
- Trace ID propagated to logs and metrics
- Trace ID included in fetch request headers (X-Trace-Id)
- Supports nested trace contexts (future enhancement)

**Estimated Complexity**: Low

**Implementation Notes**:
- Use crypto.randomUUID() if available (modern browsers)
- Fallback to manual UUID generation for older browsers
- Consider AsyncLocalStorage pattern for context (advanced)

---

#### PWA-023: Create Health Check Module
**Description**: Implement PWA health diagnostics (service worker status, cache status, network status).

**Dependencies**: None

**Worker Type**: `frontend-worker`

**Deliverables**:
- `/app/javascript/lib/health.js` exporting `HealthCheck` class
- Methods:
  - `checkServiceWorker()` - Verify SW registration
  - `checkCaches()` - Verify cache availability
  - `checkNetwork()` - Check online/offline status
  - `getReport()` - Return full health report
- Health report includes: timestamp, checks, overall_status

**Acceptance Criteria**:
- `checkServiceWorker()` returns: registered (boolean), state (string)
- `checkCaches()` returns: available (boolean), size (bytes), caches (array)
- `checkNetwork()` returns: online (boolean), connection_type (string)
- `getReport()` aggregates all checks with pass/fail status
- Uses `navigator.serviceWorker.getRegistration()` API
- Uses `navigator.storage.estimate()` for cache size
- Uses `navigator.onLine` and Network Information API

**Estimated Complexity**: Medium

**Implementation Notes**:
- Cache all health data for 30 seconds (don't re-check too frequently)
- Return health report as JSON for logging/metrics
- Consider exposing endpoint: `/api/pwa/health` (future)

---

#### PWA-024: Create Service Worker Registration Module
**Description**: Implement module to register service worker on application load with lifecycle event handling.

**Dependencies**: [PWA-006, PWA-020, PWA-021]

**Worker Type**: `frontend-worker`

**Deliverables**:
- `/app/javascript/pwa/service_worker_registration.js` exporting `ServiceWorkerRegistration` class
- Methods:
  - `register()` - Register service worker
  - `handleUpdateFound()` - Handle service worker updates
  - `handleStateChange(worker)` - Handle worker state changes
- Integrated into `application.js`

**Acceptance Criteria**:
- Checks `navigator.serviceWorker` availability before registration
- Registers `/serviceworker.js` with scope: `/`
- Listens for `updatefound` event on registration
- Logs registration events to logger module
- Records metrics for registration success/failure
- Handles registration errors gracefully (logs error, continues app)
- Listens for `controllerchange` event (page reload prompt)
- Defers registration until page load complete (`DOMContentLoaded`)

**Estimated Complexity**: Medium

**Implementation Notes**:
- Register service worker in `application.js` entry point
- Use `logger.info()` for successful registration
- Use `logger.error()` for registration failures
- Use `metrics.increment('service_worker_registration')` on success

---

#### PWA-025: Create Install Prompt Manager Module
**Description**: Implement module to handle beforeinstallprompt event and manage PWA install flow.

**Dependencies**: [PWA-020, PWA-021]

**Worker Type**: `frontend-worker`

**Deliverables**:
- `/app/javascript/pwa/install_prompt_manager.js` exporting `InstallPromptManager` class
- Methods:
  - `init()` - Listen for beforeinstallprompt
  - `handleBeforeInstallPrompt(event)` - Store deferred prompt
  - `showInstallPrompt()` - Trigger install prompt
  - `handleAppInstalled()` - Handle appinstalled event
- Integrated into `application.js`

**Acceptance Criteria**:
- Listens for `beforeinstallprompt` event on window
- Prevents default behavior (stores event for later)
- Stores deferred prompt in instance variable
- Logs prompt availability to logger
- Records metric: `install_prompt_shown`
- `showInstallPrompt()` calls `deferredPrompt.prompt()`
- Waits for user choice and logs result
- Records metric: `app_installed` if user accepts
- Listens for `appinstalled` event
- Clears deferred prompt after use

**Estimated Complexity**: Medium

**Implementation Notes**:
- Install button UI is optional for MVP (can trigger programmatically)
- Log user choice (accepted/dismissed) for analytics
- Chrome/Edge support only (Safari uses different mechanism)

---

### Phase 4: Offline Support & Testing

#### PWA-026: Create Offline Fallback Page
**Description**: Design and implement static HTML offline fallback page with embedded cat mascot.

**Dependencies**: [PWA-001]

**Worker Type**: `frontend-worker`

**Deliverables**:
- `/public/offline.html` with:
  - Minimal HTML structure (no external dependencies)
  - Inline CSS for styling
  - Base64-encoded cat image (from icon-192.png)
  - Japanese message: "オフラインです" / "現在オフラインです。インターネット接続を確認してください。"
  - ReLINE branding (logo/name)

**Acceptance Criteria**:
- Fully self-contained (no external CSS/JS/image requests)
- Cat image embedded as data URI (base64)
- Displays correctly without network
- Minimal file size (< 20KB)
- Responsive design (mobile-friendly)
- Accessible (proper semantic HTML, ARIA labels)
- Matches ReLINE brand colors (Bootstrap theme)

**Estimated Complexity**: Low

**Implementation Notes**:
- Use `<img src="data:image/png;base64,...">`
- Keep CSS minimal and inline in `<style>` tag
- Test by serving locally and going offline
- Consider adding "Retry" button (reload page)

---

#### PWA-027: Write RSpec Tests for Manifest
**Description**: Create automated tests for manifest.json endpoint and content validation.

**Dependencies**: [PWA-003, PWA-004]

**Worker Type**: `test-worker`

**Deliverables**:
- `/spec/requests/manifest_spec.rb` with test cases:
  - Returns valid manifest JSON
  - Includes required icon sizes (192x192, 512x512)
  - Supports multi-language (English/Japanese)
  - Sets correct Content-Type header
  - Includes all required fields

**Acceptance Criteria**:
- All tests pass locally
- Tests verify manifest structure per Web App Manifest spec
- Tests check icon array contains correct sizes
- Tests verify I18n support by setting Accept-Language header
- Tests validate JSON schema (name, short_name, start_url, display, icons)
- Code coverage ≥ 90% for ManifestsController

**Estimated Complexity**: Low

---

#### PWA-028: Write RSpec Tests for PWA Config API
**Description**: Create automated tests for `/api/pwa/config` endpoint.

**Dependencies**: [PWA-015]

**Worker Type**: `test-worker`

**Deliverables**:
- `/spec/requests/api/pwa/configs_spec.rb` with test cases:
  - Returns valid PWA configuration JSON
  - Includes cache strategy configuration
  - Includes network configuration
  - Includes feature flags
  - Validates JSON structure

**Acceptance Criteria**:
- All tests pass locally
- Tests verify config includes: version, caches, network, features
- Tests validate cache strategy structure (name, strategy, patterns)
- Tests check environment-specific config loading
- Code coverage ≥ 90% for Api::Pwa::ConfigsController

**Estimated Complexity**: Low

---

#### PWA-029: Write RSpec Tests for Client Logs and Metrics APIs
**Description**: Create automated tests for client logs and metrics API endpoints.

**Dependencies**: [PWA-018, PWA-019]

**Worker Type**: `test-worker`

**Deliverables**:
- `/spec/requests/api/client_logs_spec.rb` with test cases:
  - Accepts valid log entries (batch insert)
  - Rejects invalid log entries (validation)
  - Returns 201 on success
  - Returns 422 on validation error
- `/spec/requests/api/metrics_spec.rb` with test cases:
  - Accepts valid metrics (batch insert)
  - Rejects invalid metrics
  - Returns appropriate status codes

**Acceptance Criteria**:
- All tests pass locally
- Tests verify batch insert functionality
- Tests validate log entry structure (level, message, context)
- Tests validate metric structure (name, value, tags)
- Tests verify CSRF token skip for cross-origin requests
- Code coverage ≥ 90% for both controllers

**Estimated Complexity**: Medium

---

#### PWA-030: Write JavaScript Tests for Service Worker Modules
**Description**: Create unit tests for service worker JavaScript modules (strategies, router, lifecycle).

**Dependencies**: [PWA-010, PWA-011, PWA-012, PWA-013, PWA-007]

**Worker Type**: `test-worker`

**Deliverables**:
- `/spec/javascript/pwa/strategies/cache_first_strategy.test.js`
- `/spec/javascript/pwa/strategies/network_first_strategy.test.js`
- `/spec/javascript/pwa/strategies/network_only_strategy.test.js`
- `/spec/javascript/pwa/strategy_router.test.js`
- `/spec/javascript/pwa/lifecycle_manager.test.js`
- Test framework: Jest or similar

**Acceptance Criteria**:
- All tests pass locally
- Tests use mock fetch API
- Tests verify cache-first serves from cache when available
- Tests verify network-first tries network before cache
- Tests verify network-only never caches
- Tests verify strategy router matches patterns correctly
- Tests verify lifecycle manager pre-caches critical assets
- Code coverage ≥ 80% for all modules

**Estimated Complexity**: High

**Implementation Notes**:
- Mock global `caches` API
- Mock `fetch()` with different responses
- Use fake timers for timeout tests
- Consider using service-worker-mock library

---

#### PWA-031: Write System Tests for Offline Functionality
**Description**: Create end-to-end tests for PWA offline behavior using browser automation.

**Dependencies**: [PWA-026, PWA-024]

**Worker Type**: `test-worker`

**Deliverables**:
- `/spec/system/pwa_offline_spec.rb` with test cases:
  - Displays offline page when network unavailable
  - Serves cached public pages offline
  - Service worker registers successfully
  - Install prompt appears (if supported)

**Acceptance Criteria**:
- Tests run in headless Chrome with JavaScript enabled
- Tests simulate offline mode (network conditions API)
- Tests verify cached pages load offline
- Tests verify offline.html displays for uncached routes
- Tests verify service worker registration in browser
- All tests pass locally
- Tests are skipped if browser doesn't support network conditions API

**Estimated Complexity**: High

**Implementation Notes**:
- Use Capybara with Selenium or Cuprite driver
- Use `page.driver.browser.network_conditions` for offline simulation
- Wait for service worker registration before testing
- May require Chrome-specific capabilities

---

#### PWA-032: Run Lighthouse PWA Audit and Fix Issues
**Description**: Run Lighthouse PWA audit, document results, and fix any issues preventing ≥90 score.

**Dependencies**: [All previous tasks]

**Worker Type**: `test-worker`

**Deliverables**:
- Lighthouse audit report (HTML/JSON)
- Documentation of audit results in `/docs/lighthouse-pwa-audit.md`
- Fixes for any failing criteria
- Final audit score ≥ 90/100

**Acceptance Criteria**:
- Lighthouse audit run on development server (localhost with HTTPS)
- All PWA installability criteria met:
  - Web app manifest ✓
  - Service worker ✓
  - HTTPS (or localhost) ✓
  - Viewport meta tag ✓
  - Themed address bar ✓
- PWA score ≥ 90/100
- No critical PWA failures
- Audit results documented with screenshots

**Estimated Complexity**: Medium

**Implementation Notes**:
- Run Lighthouse in Chrome DevTools or via CLI
- Test on production-like environment (HTTPS)
- Address each failing audit item
- Re-run audit until score ≥ 90
- Document any exceptions or trade-offs

---

## 3. Execution Sequence

### Phase 1: Foundation (Week 1)
**Critical Path**: [PWA-001, PWA-005]

**Parallel Tracks**:
- Track A: PWA-001 (Icons) → PWA-003 (Manifest Controller) → PWA-005 (Meta Tags)
- Track B: PWA-002 (Config File) → PWA-004 (I18n)
- Track C: PWA-001 (Icons) is prerequisite for PWA-003

**Execution Order**:
1. **Start in parallel**: PWA-001, PWA-002, PWA-004
2. **After PWA-001, PWA-002**: PWA-003 (depends on both)
3. **After PWA-003**: PWA-005 (depends on manifest route)

**Phase Completion Criteria**:
- Manifest accessible at /manifest.json
- PWA meta tags in HTML head
- Icons available in public/pwa/

---

### Phase 2: Service Worker Core (Week 2)
**Critical Path**: [PWA-006, PWA-010, PWA-013, PWA-014]

**Parallel Tracks**:
- Track A: PWA-006 (SW Entry) ← depends on all modules below
- Track B: PWA-007, PWA-008 (Lifecycle, Config) - can run in parallel
- Track C: PWA-009 (Base Strategy) → PWA-010, PWA-011, PWA-012 (Strategies)
- Track D: PWA-013 (Router) ← depends on all strategies
- Track E: PWA-014 (Build Config) ← depends on PWA-006

**Execution Order**:
1. **Start in parallel**: PWA-007, PWA-008, PWA-009
2. **After PWA-009**: PWA-010, PWA-011, PWA-012 (can run in parallel)
3. **After strategies complete**: PWA-013
4. **After PWA-007, PWA-008, PWA-013**: PWA-006
5. **After PWA-006**: PWA-014

**Phase Completion Criteria**:
- Service worker compiles without errors
- Service worker accessible at /serviceworker.js
- All strategies implemented and tested

---

### Phase 3: Observability & Backend APIs (Week 3)
**Critical Path**: [PWA-015, PWA-020, PWA-024, PWA-025]

**Parallel Tracks**:
- Track A (Backend): PWA-015 (Config API) ← depends on PWA-002
- Track B (Database): PWA-016, PWA-017 (Models) - can run in parallel
- Track C (API Endpoints): PWA-018 (Logs API) ← PWA-016, PWA-019 (Metrics API) ← PWA-017
- Track D (Frontend Utils): PWA-020, PWA-021, PWA-022, PWA-023 - can run in parallel
- Track E (Integration): PWA-024, PWA-025 ← depend on Track D

**Execution Order**:
1. **Start in parallel**: PWA-015, PWA-016, PWA-017, PWA-022, PWA-023
2. **After PWA-016**: PWA-018
3. **After PWA-017**: PWA-019
4. **After PWA-018, PWA-019**: PWA-020, PWA-021 (can start earlier in parallel)
5. **After PWA-020, PWA-021**: PWA-024, PWA-025

**Phase Completion Criteria**:
- All API endpoints functional
- Logging and metrics modules integrated
- Service worker registration working
- Install prompt manager integrated

---

### Phase 4: Offline Support & Testing (Week 4)
**Critical Path**: [PWA-026, PWA-032]

**Parallel Tracks**:
- Track A: PWA-026 (Offline Page) - can start immediately
- Track B: PWA-027, PWA-028, PWA-029 (Backend Tests) - can run in parallel
- Track C: PWA-030, PWA-031 (Frontend/System Tests) - can run in parallel
- Track D: PWA-032 (Lighthouse) ← depends on ALL tasks

**Execution Order**:
1. **Start in parallel**: PWA-026, PWA-027, PWA-028, PWA-029, PWA-030, PWA-031
2. **After ALL tasks complete**: PWA-032 (final validation)

**Phase Completion Criteria**:
- All tests passing
- Lighthouse score ≥ 90
- Offline functionality verified
- Ready for production deployment

---

## 4. Dependency Graph

```
Foundation Phase:
PWA-001 ─┬─→ PWA-003 ──→ PWA-005
         │
PWA-002 ─┴─→ PWA-003
         │
PWA-004 ─┘

Service Worker Phase:
PWA-009 ──┬─→ PWA-010
          ├─→ PWA-011
          └─→ PWA-012 ──→ PWA-013 ──┐
                                     ├─→ PWA-006 ──→ PWA-014
PWA-007 ─────────────────────────────┤
PWA-008 ─────────────────────────────┘

Observability Phase:
PWA-002 ──→ PWA-015

PWA-016 ──→ PWA-018 ──┐
PWA-017 ──→ PWA-019 ──┤
                      ├─→ PWA-020 ──→ PWA-024
PWA-022 ──────────────┤
PWA-023 ──────────────┤
                      └─→ PWA-021 ──→ PWA-025

Testing Phase:
PWA-003 ──→ PWA-027
PWA-015 ──→ PWA-028
PWA-018, PWA-019 ──→ PWA-029
PWA-010, PWA-011, PWA-012, PWA-013 ──→ PWA-030
PWA-024, PWA-026 ──→ PWA-031

ALL TASKS ──→ PWA-032
```

---

## 5. Risk Assessment

### Technical Risks

**Risk 1: Service Worker Scope Issues (Medium)**
- **Description**: Service worker may not register with correct scope if served from /assets/
- **Impact**: PWA features won't work
- **Mitigation**: Ensure service worker served from `/serviceworker.js` (not `/assets/`) via PWA-014
- **Owner**: PWA-014 (esbuild configuration)

**Risk 2: esbuild Module Resolution (Medium)**
- **Description**: Service worker imports may fail if esbuild misconfigures module bundling
- **Impact**: Service worker won't compile or will error at runtime
- **Mitigation**: Test service worker compilation early (PWA-014), verify all imports resolve
- **Owner**: PWA-014, PWA-006

**Risk 3: Cache Strategy Pattern Matching (Medium)**
- **Description**: Incorrect RegExp patterns may cause requests to use wrong strategy
- **Impact**: Static assets not cached, or dynamic pages cached incorrectly
- **Mitigation**: Comprehensive unit tests for strategy router (PWA-030), manual testing
- **Owner**: PWA-013, PWA-030

**Risk 4: Offline.html Embedded Image Size (Low)**
- **Description**: Base64-encoded cat image may exceed reasonable file size
- **Impact**: Large offline.html file (slow to cache)
- **Mitigation**: Compress icon before base64 encoding, keep image small (< 10KB)
- **Owner**: PWA-026

**Risk 5: Browser Compatibility (Low)**
- **Description**: Safari PWA support is limited (iOS 16.4+), install prompt varies by browser
- **Impact**: Some users won't see install prompt or offline features
- **Mitigation**: Graceful degradation (feature detection), document browser support
- **Owner**: PWA-024, PWA-025

### Dependency Risks

**Risk 6: Critical Path Length (High)**
- **Description**: Service worker phase has long dependency chain (PWA-009 → strategies → router → entry → build)
- **Impact**: Delays in any task block entire service worker implementation
- **Mitigation**: Start PWA-009 (base strategy) as early as possible, parallelize strategy implementations
- **Owner**: Project manager / Main Claude Code

**Risk 7: Testing Phase Dependency on All Tasks (High)**
- **Description**: PWA-032 (Lighthouse audit) cannot start until ALL 31 tasks complete
- **Impact**: Late discovery of integration issues may require rework
- **Mitigation**: Run manual Lighthouse audits after Phase 2 and Phase 3 completion, fix issues early
- **Owner**: PWA-032

**Risk 8: Observability Module Integration (Medium)**
- **Description**: PWA-020, PWA-021 must integrate with PWA-024, PWA-025 correctly
- **Impact**: Metrics/logs may not be collected if integration is incorrect
- **Mitigation**: Define clear interfaces early, write integration tests
- **Owner**: PWA-024, PWA-025

### External Risks

**Risk 9: Rails 8.1 / Propshaft Compatibility (Low)**
- **Description**: Propshaft may have undocumented limitations for serving service workers
- **Impact**: Service worker may not be accessible at expected URL
- **Mitigation**: Research Propshaft documentation, test early, fallback to custom route/controller if needed
- **Owner**: PWA-014

**Risk 10: MySQL JSON Column Performance (Low)**
- **Description**: Large JSON blobs in `context` and `tags` columns may impact query performance
- **Impact**: Slow queries when filtering logs/metrics
- **Mitigation**: Add indexes on JSON fields if supported, implement data retention policy
- **Owner**: PWA-016, PWA-017

---

## 6. Quality Gates

### Gate 1: Foundation Phase Complete
**Criteria**:
- [ ] Manifest accessible at http://localhost:3000/manifest.json
- [ ] Manifest passes JSON validation
- [ ] PWA icons exist in /public/pwa/ with correct dimensions
- [ ] Meta tags present in application.html.slim
- [ ] Chrome DevTools → Application → Manifest shows data correctly
- [ ] No browser console errors

**Exit Criteria**: All checkboxes checked + PWA-005 acceptance criteria met

---

### Gate 2: Service Worker Phase Complete
**Criteria**:
- [ ] Service worker compiles without errors
- [ ] Service worker accessible at http://localhost:3000/serviceworker.js
- [ ] Service worker registers in Chrome DevTools → Application → Service Workers
- [ ] All cache strategies implemented (CacheFirstStrategy, NetworkFirstStrategy, NetworkOnlyStrategy)
- [ ] Strategy router correctly routes requests by pattern
- [ ] /api/pwa/config endpoint returns valid JSON
- [ ] No JavaScript errors in browser console

**Exit Criteria**: All checkboxes checked + PWA-014 acceptance criteria met

---

### Gate 3: Observability Phase Complete
**Criteria**:
- [ ] Client logs successfully sent to /api/client_logs
- [ ] Metrics successfully sent to /api/metrics
- [ ] Database tables created (client_logs, metrics)
- [ ] Logger module integrated into service worker
- [ ] Metrics module integrated into service worker
- [ ] Service worker registration logs visible in backend
- [ ] Install prompt manager captures beforeinstallprompt event
- [ ] No errors in Rails logs during metric collection

**Exit Criteria**: All checkboxes checked + PWA-025 acceptance criteria met

---

### Gate 4: Testing & Launch Complete
**Criteria**:
- [ ] All RSpec tests pass (manifest, config API, client logs, metrics)
- [ ] All JavaScript tests pass (strategies, router, lifecycle)
- [ ] System tests pass (offline functionality)
- [ ] Offline.html displays correctly when network disabled
- [ ] Lighthouse PWA audit score ≥ 90/100
- [ ] No critical Lighthouse failures
- [ ] Manual cross-browser testing completed (Chrome, Safari, Firefox)
- [ ] Documentation updated (README, CHANGELOG)

**Exit Criteria**: All checkboxes checked + PWA-032 acceptance criteria met

---

## 7. Success Metrics (Post-Implementation)

**Metric 1: Lighthouse PWA Score**
- Target: ≥ 90/100
- Validation Task: PWA-032

**Metric 2: Service Worker Registration Rate**
- Target: ≥ 95% of visitors (Chrome/Edge)
- Tracking: `/api/metrics` endpoint (post-deployment)

**Metric 3: Cache Hit Rate**
- Target: ≥ 80% for repeat visitors
- Tracking: Service worker cache_hit metrics

**Metric 4: Install Conversion Rate**
- Target: ≥ 5% of eligible visitors
- Tracking: install_prompt_shown vs app_installed metrics

**Metric 5: Test Coverage**
- Target: ≥ 90% for backend code, ≥ 80% for frontend code
- Validation: RSpec coverage report, Jest coverage report

---

## 8. Rollback Plan

**If PWA features cause issues in production:**

1. **Immediate Rollback** (Emergency):
   - Remove service worker registration from `application.js`
   - Delete `/public/serviceworker.js`
   - Clear browser service worker cache (requires user action)
   - Deploy without PWA features

2. **Graceful Degradation** (Preferred):
   - Add feature flag to `pwa_config.yml`: `enable_pwa: false`
   - Service worker registration checks flag before registering
   - Existing service workers continue to work (cached users)
   - New users don't get PWA features

3. **Service Worker Update** (Fix Issues):
   - Fix bug in service worker code
   - Increment cache version in `pwa_config.yml`
   - Deploy new service worker
   - Old service worker auto-updates on next page visit

---

## 9. Notes for Workers

### For Frontend Workers (PWA-001, PWA-005, PWA-006-014, PWA-020-026)

**Service Worker Constraints**:
- Service worker MUST be served from root scope (`/serviceworker.js`, NOT `/assets/serviceworker-[hash].js`)
- Service worker can only control pages at its scope or below
- Use ES6 modules (`import`/`export`), esbuild will bundle
- Test service worker locally with `http://localhost:3000` (HTTPS not required for localhost)

**Offline Testing**:
- Chrome DevTools → Network → Throttling → Offline
- Service Workers panel shows registration status
- Application → Cache Storage shows cached resources

**Common Pitfalls**:
- Forgetting to clone response before caching (response stream is single-use)
- Not handling AbortController cleanup in timeout
- Cache naming conflicts (include version in cache name)

---

### For Backend Workers (PWA-002, PWA-003, PWA-014-019)

**Rails Integration**:
- Use `Rails.application.config_for(:pwa_config)` to load YAML config
- Skip CSRF verification for public APIs (`skip_before_action :verify_authenticity_token`)
- Use `insert_all` for batch inserts (Rails 6+, better performance than `create`)

**Security**:
- Rate limit `/api/client_logs` and `/api/metrics` endpoints (prevent abuse)
- Validate log/metric structure before insert
- Add request size limits (max 100 entries per request)

**Performance**:
- Consider async jobs for large log batches (ActiveJob)
- Plan data retention policy (delete old logs/metrics after 90 days)
- Index timestamp columns for efficient queries

---

### For Database Workers (PWA-016, PWA-017)

**Schema Design**:
- Use MySQL JSON type for `context` and `tags` columns (not TEXT)
- Add composite indexes for time-series queries: `(name, created_at)` for metrics
- Add index on `trace_id` for distributed tracing correlation

**Data Volume**:
- Expect high write volume for metrics (design for scalability)
- Consider partitioning by timestamp (monthly partitions)
- Plan for data retention cleanup (cron job or Rails task)

---

### For Test Workers (PWA-027-032)

**Testing Tools**:
- RSpec for backend tests (request specs, model specs)
- Jest for JavaScript tests (service worker modules)
- Capybara + Selenium/Cuprite for system tests (offline functionality)
- Lighthouse CLI for PWA audit

**Test Environment**:
- JavaScript tests require Node.js and npm
- System tests require Chrome/Chromium browser
- Lighthouse requires HTTPS or localhost
- Mock `navigator.serviceWorker` API in unit tests

**Coverage Requirements**:
- Backend code: ≥ 90%
- Frontend code: ≥ 80%
- Service worker: ≥ 80% (critical code paths)

---

## 10. Definition of Done (Overall)

**Phase 1 Complete**:
- All foundation tasks (PWA-001 to PWA-005) completed
- Manifest accessible and valid
- Icons exist and load correctly
- Meta tags present in HTML

**Phase 2 Complete**:
- All service worker tasks (PWA-006 to PWA-014) completed
- Service worker compiles and registers
- All cache strategies implemented
- Config API functional

**Phase 3 Complete**:
- All observability tasks (PWA-015 to PWA-025) completed
- Logging and metrics collection working
- Service worker registration integrated
- Install prompt manager functional

**Phase 4 Complete**:
- All testing tasks (PWA-026 to PWA-032) completed
- Offline page created and tested
- All tests passing (backend, frontend, system)
- Lighthouse score ≥ 90/100

**Feature Complete (Ready for Deployment)**:
- All 32 tasks completed
- All quality gates passed
- All acceptance criteria met
- Documentation updated
- No critical bugs
- Lighthouse PWA audit ≥ 90/100
- Cross-browser testing complete (Chrome, Safari, Firefox)
- Production deployment checklist complete

---

**This task plan is ready for evaluation by planner-evaluators.**
