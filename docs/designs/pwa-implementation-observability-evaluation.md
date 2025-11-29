# Design Observability Evaluation - PWA Implementation

**Evaluator**: design-observability-evaluator
**Design Document**: /Users/yujitsuchiya/cat_salvages_the_relationship/docs/designs/pwa-implementation.md
**Evaluated**: 2025-11-29T00:00:00Z

---

## Overall Judgment

**Status**: Request Changes
**Overall Score**: 3.3 / 5.0

The design document provides comprehensive PWA implementation details but has **critical gaps in observability, monitoring, and debugging capabilities**. While console logging is mentioned sporadically, there is no structured logging framework, no metrics collection strategy, no distributed tracing plan, and minimal health check definitions. For a client-side PWA feature that operates offline and manages service workers, robust observability is essential to diagnose issues in production.

---

## Detailed Scores

### 1. Logging Strategy: 2.5 / 5.0 (Weight: 35%)

**Findings**:
- Logging is mentioned only in the context of console.log statements for debugging
- No structured logging framework specified for browser or server-side logging
- No log aggregation or centralization strategy defined
- No contextual information (userId, sessionId, requestId) in logs
- No log levels specified (INFO, WARN, ERROR, DEBUG)
- Service worker errors would be logged to browser console only, not persisted

**Logging Framework**:
- Not specified (only browser console.log mentioned)

**Log Context**:
- None specified
- Missing critical fields: userId, sessionId, requestId, timestamp, userAgent, browserVersion, serviceWorkerVersion

**Log Levels**:
- Not defined
- Only generic `console.log()`, `console.warn()`, and `console.error()` mentioned

**Centralization**:
- Not specified
- No strategy for collecting client-side logs from users' browsers
- No mention of error tracking service (Sentry, Rollbar, etc.)

**Issues**:
1. **No Client-Side Log Aggregation**: Console logs in user browsers are not accessible to developers - critical PWA errors will be invisible
2. **No Service Worker Error Tracking**: Service worker failures (registration, caching, fetch) won't be reported to developers
3. **No Structured Logging**: Logs lack context (which user? which page? which service worker version?)
4. **No Log Retention**: Browser console logs are ephemeral and disappear on page reload
5. **No Searchability**: Cannot query "all service worker registration failures in last 24 hours"

**Recommendation**:

Implement client-side error tracking and structured logging:

```javascript
// app/javascript/lib/logger.js
class PWALogger {
  constructor() {
    this.userId = this.getUserId();
    this.sessionId = this.getSessionId();
    this.serviceWorkerVersion = 'v1'; // From cache version
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
    if (process.env.NODE_ENV === 'production') {
      this.sendToServer(logEntry);
    }
  }

  info(message, context) { this.log('INFO', message, context); }
  warn(message, context) { this.log('WARN', message, context); }
  error(message, context) { this.log('ERROR', message, context); }

  sendToServer(logEntry) {
    // Non-blocking log transmission
    navigator.sendBeacon('/api/client_logs', JSON.stringify(logEntry));
  }

  getUserId() {
    // Extract from session or cookie
    return document.cookie.match(/user_id=([^;]+)/)?.[1] || 'anonymous';
  }

  getSessionId() {
    // Generate or retrieve session ID
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

**Usage in Service Worker**:
```javascript
// serviceworker.js
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
```

**Backend Endpoint for Log Collection**:
```ruby
# app/controllers/api/client_logs_controller.rb
class Api::ClientLogsController < ApplicationController
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
      context: params.except(:level, :message, :userId, :sessionId, :serviceWorkerVersion, :userAgent, :url)
    )
    head :created
  rescue => e
    Rails.logger.error("Failed to save client log: #{e.message}")
    head :no_content # Don't block client even if logging fails
  end
end
```

**Alternative: Use Third-Party Error Tracking**:
```javascript
// app/javascript/application.js
import * as Sentry from "@sentry/browser";

Sentry.init({
  dsn: "YOUR_SENTRY_DSN",
  environment: process.env.NODE_ENV,
  release: "pwa-v1.0.0",
  beforeSend(event, hint) {
    // Add custom context
    event.user = {
      id: getUserId(),
      session_id: getSessionId()
    };
    return event;
  }
});
```

**Observability Benefit**:
- Search logs: "Show all service worker registration failures for user 123"
- Alert on patterns: "Service worker install failure rate increased 10x in last hour"
- Debug issues: "User reported offline page not working - check their logs for cache errors"

---

### 2. Metrics & Monitoring: 2.0 / 5.0 (Weight: 30%)

**Findings**:
- Success metrics are defined (Section 10) but NO implementation strategy provided
- Metrics are listed as tracking targets but no collection mechanism specified
- No monitoring system mentioned (Prometheus, Datadog, CloudWatch, Google Analytics)
- No real-time dashboards planned
- No alerting strategy for critical failures
- Metrics are passive (await post-launch review) rather than active (real-time monitoring)

**Key Metrics**:
Defined but not implemented:
- Service worker registration rate
- Cache hit rate
- Install conversion rate
- Offline page views
- Time to first paint (FP)
- Time to interactive (TTI)
- Cache storage usage
- Error rates

**Monitoring System**:
- Not specified
- Google Analytics mentioned for tracking custom events but no implementation details
- No server-side monitoring for client logs

**Alerts**:
- Not specified
- No alert thresholds defined
- No notification channels (Slack, email, PagerDuty)

**Dashboards**:
- Not mentioned
- No visualization of PWA health metrics

**Issues**:
1. **No Metrics Collection Implementation**: Success metrics defined but no code to actually track them
2. **No Real-Time Monitoring**: Cannot detect service worker registration failures as they happen
3. **No Alerting**: Critical issues (e.g., 50% registration failure rate) won't trigger alerts
4. **No Operational Visibility**: Cannot answer "How many users have service workers active right now?"
5. **No Performance Tracking**: FP/TTI metrics mentioned but no measurement implementation

**Recommendation**:

Implement comprehensive metrics tracking:

**Client-Side Metrics Collection**:
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
        userId: getUserId(),
        sessionId: getSessionId(),
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

  trackInstallPrompt(shown, accepted) {
    this.recordMetric('install_prompt', shown ? 1 : 0, {
      shown: shown,
      accepted: accepted
    });
  }

  trackPerformance() {
    const perfData = performance.getEntriesByType('navigation')[0];

    this.recordMetric('time_to_first_paint', perfData.domContentLoadedEventEnd - perfData.fetchStart);
    this.recordMetric('time_to_interactive', perfData.loadEventEnd - perfData.fetchStart);

    // Track service worker impact
    const serviceWorkerStart = perfData.workerStart || 0;
    if (serviceWorkerStart > 0) {
      this.recordMetric('service_worker_overhead', serviceWorkerStart - perfData.fetchStart);
    }
  }

  trackCacheStorageUsage() {
    if (navigator.storage && navigator.storage.estimate) {
      navigator.storage.estimate().then(estimate => {
        this.recordMetric('cache_storage_usage_bytes', estimate.usage);
        this.recordMetric('cache_storage_quota_bytes', estimate.quota);
        this.recordMetric('cache_storage_usage_percent', (estimate.usage / estimate.quota) * 100);
      });
    }
  }
}

export const metrics = new PWAMetrics();
```

**Backend Metrics Endpoint**:
```ruby
# app/controllers/api/metrics_controller.rb
class Api::MetricsController < ApplicationController
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
```

**Alerting Configuration** (Example with Prometheus/Grafana):
```yaml
# prometheus/alerts.yml
groups:
  - name: pwa_alerts
    interval: 1m
    rules:
      - alert: HighServiceWorkerRegistrationFailureRate
        expr: |
          (
            sum(rate(service_worker_registration{success="false"}[5m]))
            /
            sum(rate(service_worker_registration[5m]))
          ) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High service worker registration failure rate"
          description: "{{ $value | humanizePercentage }} of service worker registrations are failing"

      - alert: CacheStorageQuotaExceeded
        expr: cache_storage_usage_percent > 90
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Cache storage quota nearly exceeded"
          description: "Cache storage is at {{ $value }}% of quota"

      - alert: LowInstallConversionRate
        expr: |
          (
            sum(rate(install_prompt{accepted="true"}[1h]))
            /
            sum(rate(install_prompt{shown="true"}[1h]))
          ) < 0.01
        for: 1h
        labels:
          severity: info
        annotations:
          summary: "Low PWA install conversion rate"
          description: "Only {{ $value | humanizePercentage }} of users are installing the PWA"
```

**Dashboard Example** (Grafana):
```json
{
  "dashboard": {
    "title": "PWA Health Dashboard",
    "panels": [
      {
        "title": "Service Worker Registration Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(service_worker_registration{success=\"true\"}[5m])"
          }
        ]
      },
      {
        "title": "Cache Hit Rate",
        "type": "gauge",
        "targets": [
          {
            "expr": "sum(rate(cache_hit{hit=\"true\"}[5m])) / sum(rate(cache_hit[5m]))"
          }
        ]
      },
      {
        "title": "Install Conversion Rate",
        "type": "stat",
        "targets": [
          {
            "expr": "sum(rate(install_prompt{accepted=\"true\"}[1h])) / sum(rate(install_prompt{shown=\"true\"}[1h]))"
          }
        ]
      }
    ]
  }
}
```

**Recommended Monitoring Stack**:
- **Metrics Collection**: Custom endpoint + Google Analytics
- **Visualization**: Grafana or Google Analytics dashboards
- **Alerting**: Prometheus Alertmanager or Google Analytics alerts
- **Error Tracking**: Sentry for JavaScript errors

---

### 3. Distributed Tracing: 3.0 / 5.0 (Weight: 20%)

**Findings**:
- Service worker lifecycle is documented (install → activate → fetch)
- Cache flow diagrams show request paths
- However, no trace ID propagation mentioned
- No correlation between client-side events and server-side logs
- Cannot trace a user's journey from page load → service worker registration → cache hit → offline fallback

**Tracing Framework**:
- Not specified
- No OpenTelemetry, Jaeger, or similar tracing library mentioned

**Trace ID Propagation**:
- Not mentioned
- No requestId or traceId in logs

**Span Instrumentation**:
- Not mentioned
- Cannot see timing breakdown of service worker operations

**Issues**:
1. **No Request Correlation**: Cannot link client-side service worker events to server-side Rails logs
2. **No User Journey Tracking**: Cannot trace "User visited / → SW registered → Cache populated → User went offline → Offline page shown"
3. **No Performance Attribution**: Cannot determine if slowness is due to network, service worker, or cache

**Recommendation**:

Implement basic distributed tracing:

**Generate and Propagate Trace IDs**:
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

**Instrument Service Worker Registration**:
```javascript
// app/javascript/application.js
if ('serviceWorker' in navigator) {
  window.addEventListener('load', async () => {
    const { span, end } = tracing.startSpan('service_worker_registration');

    try {
      const registration = await navigator.serviceWorker.register('/serviceworker.js');
      const traceId = end({
        success: true,
        scope: registration.scope
      });

      logger.info('SW registered', { traceId, scope: registration.scope });
    } catch (error) {
      const traceId = end({
        success: false,
        error: error.message
      });

      logger.error('SW registration failed', { traceId, error: error.message });
    }
  });
}
```

**Instrument Service Worker Fetch Events**:
```javascript
// serviceworker.js
self.addEventListener('fetch', (event) => {
  const traceId = event.request.headers.get('X-Trace-ID') || generateTraceId();
  const startTime = performance.now();

  event.respondWith(
    handleFetch(event.request, traceId)
      .then(response => {
        const duration = performance.now() - startTime;
        recordFetchSpan(traceId, event.request.url, duration, response.status, 'success');
        return response;
      })
      .catch(error => {
        const duration = performance.now() - startTime;
        recordFetchSpan(traceId, event.request.url, duration, null, 'error');
        throw error;
      })
  );
});

function recordFetchSpan(traceId, url, duration, status, outcome) {
  // Send to tracing backend
  self.clients.matchAll().then(clients => {
    clients.forEach(client => {
      client.postMessage({
        type: 'trace',
        traceId: traceId,
        url: url,
        duration: duration,
        status: status,
        outcome: outcome
      });
    });
  });
}
```

**Observability Benefit**:
- Trace user journey: "User ABC visited page → SW registered in 45ms → First fetch served from cache in 2ms"
- Debug issues: "User reported offline error - trace shows cache miss for critical asset"
- Performance analysis: "90% of requests served from cache in <10ms, 10% require network with 500ms average"

---

### 4. Health Checks & Diagnostics: 5.0 / 5.0 (Weight: 15%)

**Findings**:
- Health check strategy is well-defined in Section 7.3
- Service worker lifecycle monitoring included
- Cache storage diagnostics mentioned
- Manual cache clear functionality planned
- Offline detection and fallback mechanisms designed
- Error recovery strategies documented

**Health Check Endpoints**:
- Manifest.json accessible at /manifest.json
- Service worker status checkable via Chrome DevTools → Application → Service Workers
- Cache storage inspectable via Chrome DevTools → Application → Cache Storage

**Dependency Checks**:
- Service worker registration status
- Cache storage availability
- Browser API support (navigator.serviceWorker, caches, etc.)

**Diagnostic Endpoints**:
- Manual cache clear function planned: `clearAllCaches()`
- Service worker update check via browser API
- Cache storage quota estimation via `navigator.storage.estimate()`

**Issues**:
None critical - health check strategy is comprehensive

**Recommendation**:

Add programmatic health check endpoint:

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

**Expose Health Check in Console**:
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
    console.log(`Cleared ${cacheNames.length} caches`);
  },

  updateServiceWorker: async () => {
    const registration = await navigator.serviceWorker.getRegistration();
    if (registration) {
      await registration.update();
      console.log('Service worker update check triggered');
    }
  }
};
```

**Observability Benefit**:
- Debug user issues: "User reports offline not working - ask them to run `PWA.checkHealth()` in console"
- Proactive monitoring: "Alert if cache storage usage > 90%"
- Support diagnostics: "Is service worker active? Are caches populated?"

---

## Observability Gaps

### Critical Gaps

1. **No Client-Side Error Tracking**: PWA errors (service worker registration failures, cache errors) happen in user browsers and won't be visible to developers without error tracking service (Sentry, Rollbar) or custom log collection endpoint.
   - **Impact**: Cannot diagnose production issues, blind to user-facing errors

2. **No Metrics Collection Implementation**: Success metrics are defined but no code to actually track them - metrics will remain theoretical without implementation.
   - **Impact**: Cannot measure PWA adoption, performance improvements, or failure rates

3. **No Alerting Strategy**: Critical failures (e.g., 50% service worker registration failure rate, cache quota exceeded) won't trigger alerts.
   - **Impact**: Issues may go unnoticed for days/weeks until manual review

### Minor Gaps

1. **No Trace ID Propagation**: Cannot correlate client-side PWA events with server-side Rails logs.
   - **Impact**: Difficult to debug issues that span client and server (e.g., offline form submission)

2. **No Real-Time Dashboard**: Metrics collection is passive (await post-launch review) rather than active (real-time monitoring).
   - **Impact**: No operational visibility into PWA health

3. **No Log Retention Policy**: Browser console logs are ephemeral and disappear on page reload.
   - **Impact**: Cannot investigate historical issues

---

## Recommended Observability Stack

Based on design, recommend:

**Logging**:
- **Client-Side**: Sentry Browser SDK or custom log collection endpoint
- **Server-Side**: Rails.logger (existing)
- **Log Aggregation**: Elasticsearch + Kibana or Papertrail for client logs

**Metrics**:
- **Collection**: Custom metrics endpoint + Google Analytics events
- **Storage**: Prometheus or database (metrics table)
- **Visualization**: Grafana dashboards or Google Analytics reports

**Tracing**:
- **Framework**: Custom trace ID generation and propagation (lightweight)
- **Alternative**: OpenTelemetry Browser SDK (if full tracing needed)

**Dashboards**:
- **PWA Health Dashboard**: Grafana or Google Analytics
- **Key Metrics**: Service worker registration rate, cache hit rate, install conversion, error rate

**Alerting**:
- **Critical**: Service worker registration failures > 5%
- **Warning**: Cache storage usage > 90%
- **Info**: Install conversion rate < 1%

**Error Tracking**:
- **Tool**: Sentry (recommended for client-side JavaScript errors)
- **Configuration**: Browser SDK with custom context (userId, sessionId, serviceWorkerVersion)

---

## Action Items for Designer

**Required Changes for Approval (Score ≥ 7.0/10.0)**:

1. **Add Client-Side Error Tracking Section**:
   - Specify error tracking service (Sentry recommended) or custom log collection endpoint
   - Define what errors to track: service worker registration failures, cache errors, fetch failures, quota exceeded
   - Include implementation code in design document

2. **Add Metrics Collection Implementation Section**:
   - Provide code for tracking all 14 success metrics defined in Section 10
   - Define backend endpoint for receiving metrics (`POST /api/metrics`)
   - Specify metrics storage strategy (database table, Prometheus, Google Analytics)

3. **Add Monitoring & Alerting Section**:
   - Define alert thresholds for critical metrics (service worker registration failure rate > 5%, cache storage > 90%)
   - Specify notification channels (Slack, email, PagerDuty)
   - Include alert configuration examples (Prometheus Alertmanager or equivalent)

4. **Add Distributed Tracing Section**:
   - Define trace ID generation and propagation strategy
   - Show how to correlate client-side PWA events with server-side Rails logs
   - Include code for instrumenting service worker lifecycle and fetch events

5. **Add Operational Visibility Section**:
   - Define real-time dashboard requirements (Grafana or Google Analytics)
   - List dashboard panels: service worker status, cache hit rate, install conversion, error rate
   - Include dashboard screenshot or mockup

6. **Enhance Error Handling Section (Section 7)**:
   - Add error reporting code to all error scenarios (currently only shows console.log)
   - Ensure all errors are tracked via error tracking service or custom endpoint

**Optional Enhancements**:

7. **Add Logging Best Practices**:
   - Define log levels (DEBUG, INFO, WARN, ERROR)
   - Specify contextual fields to include in all logs (userId, sessionId, traceId, serviceWorkerVersion)

8. **Add Performance Monitoring**:
   - Implement Web Vitals tracking (LCP, FID, CLS)
   - Track service worker overhead impact on page load time

---

## Structured Data

```yaml
evaluation_result:
  evaluator: "design-observability-evaluator"
  design_document: "/Users/yujitsuchiya/cat_salvages_the_relationship/docs/designs/pwa-implementation.md"
  timestamp: "2025-11-29T00:00:00Z"
  overall_judgment:
    status: "Request Changes"
    overall_score: 3.3
  detailed_scores:
    logging_strategy:
      score: 2.5
      weight: 0.35
      issues:
        - "No structured logging framework"
        - "No client-side log aggregation"
        - "No service worker error tracking"
        - "Logs lack context (userId, sessionId, requestId)"
        - "No log retention or searchability"
    metrics_monitoring:
      score: 2.0
      weight: 0.30
      issues:
        - "Metrics defined but no implementation strategy"
        - "No monitoring system specified"
        - "No alerting strategy"
        - "No real-time dashboards"
        - "Cannot measure PWA health in production"
    distributed_tracing:
      score: 3.0
      weight: 0.20
      issues:
        - "No trace ID propagation"
        - "Cannot correlate client-side and server-side events"
        - "No user journey tracking"
      strengths:
        - "Service worker lifecycle documented"
        - "Cache flow diagrams provided"
    health_checks:
      score: 5.0
      weight: 0.15
      strengths:
        - "Health check strategy well-defined"
        - "Service worker diagnostics included"
        - "Cache storage monitoring planned"
        - "Error recovery strategies documented"
  observability_gaps:
    - severity: "critical"
      gap: "No client-side error tracking"
      impact: "Cannot diagnose PWA errors in production - developers are blind to user-facing issues"
    - severity: "critical"
      gap: "No metrics collection implementation"
      impact: "Success metrics remain theoretical - cannot measure PWA adoption or performance"
    - severity: "critical"
      gap: "No alerting strategy"
      impact: "Critical failures may go unnoticed for extended periods"
    - severity: "minor"
      gap: "No trace ID propagation"
      impact: "Difficult to debug issues spanning client and server"
    - severity: "minor"
      gap: "No real-time dashboard"
      impact: "No operational visibility into PWA health"
  observability_coverage: 45%
  recommended_stack:
    logging: "Sentry Browser SDK + Custom log collection endpoint"
    metrics: "Custom metrics endpoint + Google Analytics + Prometheus"
    tracing: "Custom trace ID generation (lightweight approach)"
    dashboards: "Grafana for real-time metrics + Google Analytics for user analytics"
    error_tracking: "Sentry"
  action_items_count: 6
  required_changes:
    - "Add client-side error tracking section"
    - "Add metrics collection implementation section"
    - "Add monitoring & alerting section"
    - "Add distributed tracing section"
    - "Add operational visibility section"
    - "Enhance error handling with error reporting"
```
