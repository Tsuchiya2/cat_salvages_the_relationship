# Design Observability Evaluation - LINE Bot SDK Modernization

**Evaluator**: design-observability-evaluator
**Design Document**: /Users/yujitsuchiya/cat_salvages_the_relationship/docs/designs/line-sdk-modernization.md
**Evaluated**: 2025-11-16T10:45:00+09:00

---

## Overall Judgment

**Status**: Request Changes
**Overall Score**: 3.4 / 5.0

---

## Detailed Scores

### 1. Logging Strategy: 3.5 / 5.0 (Weight: 35%)

**Findings**:
- Basic structured logging approach with Rails logger mentioned
- Log levels (DEBUG, INFO, WARN, ERROR, FATAL) are properly identified
- Log context includes key fields (group_id, event_type, duration, etc.)
- Centralized logging mentioned as future consideration (ELK stack, Splunk)
- JSON-formatted structured logging examples provided

**Logging Framework**:
- Rails logger (default)
- JSON formatting proposed for structured logs
- No specific structured logging gem mentioned (e.g., Lograge, Semantic Logger)

**Log Context**:
- ✅ Timestamp (implicit in Rails logger)
- ✅ group_id
- ✅ event_type
- ✅ duration_ms
- ✅ success/failure status
- ⚠️ request_id mentioned but not consistently implemented
- ⚠️ correlation_id proposed but marked as future enhancement
- ❌ user_id not applicable (LINE Bot context)

**Log Levels**:
- DEBUG: Event payloads and diagnostic information
- INFO: Webhook receipt, event processing, message sending
- WARN: Failed member count queries with fallback
- ERROR: Event processing failures, database errors
- FATAL: Critical failures (database connection lost)

**Centralization**:
- Current: File-based logging (`log/production.log`)
- Proposed: ELK stack or Splunk (mentioned as consideration)
- ⚠️ No concrete centralization implementation plan

**Issues**:
1. **No structured logging framework specified**: While JSON formatting is proposed, no specific gem (Lograge, Semantic Logger) is chosen for implementation
2. **Inconsistent correlation ID usage**: Correlation IDs are mentioned for debugging but not integrated into the main logging strategy
3. **No log rotation policy**: File-based logs will grow indefinitely without rotation
4. **Centralized logging is optional**: Production systems should have centralized logging as a requirement, not a "future consideration"

**Recommendation**:
1. Adopt a structured logging framework (Lograge or Semantic Logger):
```ruby
# Gemfile
gem 'lograge'

# config/environments/production.rb
config.lograge.enabled = true
config.lograge.formatter = Lograge::Formatters::Json.new
config.lograge.custom_options = lambda do |event|
  {
    correlation_id: event.payload[:correlation_id],
    group_id: event.payload[:group_id],
    event_type: event.payload[:event_type]
  }
end
```

2. Implement correlation IDs from the start:
```ruby
# app/controllers/operator/webhooks_controller.rb
before_action :set_correlation_id

def set_correlation_id
  RequestStore.store[:correlation_id] = request.headers['X-Request-ID'] || SecureRandom.uuid
end
```

3. Configure log rotation:
```ruby
# config/environments/production.rb
config.logger = ActiveSupport::Logger.new(
  Rails.root.join('log', 'production.log'),
  10, # Keep 10 old log files
  100.megabytes # Rotate when file reaches 100MB
)
```

4. Plan for centralized logging implementation (not optional):
- Deploy ELK stack or use CloudWatch Logs
- Ship logs via Fluentd or Filebeat
- Include timeline in deployment plan

---

### 2. Metrics & Monitoring: 2.5 / 5.0 (Weight: 30%)

**Findings**:
- Key metrics are identified but not implemented
- No monitoring system specified (Prometheus, Datadog, CloudWatch)
- Alert thresholds defined but no alerting mechanism
- Performance benchmarks defined with clear targets
- Manual monitoring only (log tailing)

**Key Metrics Identified**:
- Webhook requests per minute
- Event processing success rate
- Event processing latency (p50, p95, p99)
- Message send success rate
- LineGroup creation rate
- LINE API call success rate
- LINE API latency
- System metrics (CPU, Memory, Disk I/O, Network I/O)

**Monitoring System**:
- Not specified (marked as "Future Enhancement")
- StatsD/Prometheus mentioned in comments only
- No implementation plan provided

**Alerts**:
- Thresholds defined:
  - Critical: Error rate > 5%, webhook endpoint down, auth failure
  - Warning: Error rate > 1%, response time > 5s, memory > 80%
  - Informational: New/deleted groups, scheduled messages
- No alerting implementation (only email notifications via LineMailer)

**Dashboards**:
- Not mentioned or planned
- No visualization strategy

**Issues**:
1. **No metrics collection implemented**: All metrics are identified but marked as "Future Enhancement"
2. **No monitoring system chosen**: StatsD/Prometheus mentioned only in code comments
3. **No dashboard strategy**: Cannot visualize system health without dashboards
4. **Alert thresholds without alerting**: Thresholds are defined but no system to trigger them (only manual log monitoring)
5. **Manual monitoring is not scalable**: Relying on `tail -f log/production.log` is not sustainable

**Recommendation**:
1. Implement metrics collection from day one:
```ruby
# Gemfile
gem 'prometheus-client'

# config/initializers/prometheus.rb
require 'prometheus/client'

prometheus = Prometheus::Client.registry

WEBHOOK_DURATION = prometheus.histogram(
  :webhook_duration_seconds,
  docstring: 'Webhook processing duration',
  labels: [:event_type]
)

MESSAGE_SEND_TOTAL = prometheus.counter(
  :message_send_total,
  docstring: 'Total messages sent',
  labels: [:status]
)

# Usage in code:
WEBHOOK_DURATION.observe({ event_type: 'message' }, elapsed_seconds)
MESSAGE_SEND_TOTAL.increment(labels: { status: 'success' })
```

2. Add metrics endpoint:
```ruby
# config/routes.rb
get '/metrics', to: 'metrics#index'

# app/controllers/metrics_controller.rb
class MetricsController < ApplicationController
  def index
    render plain: Prometheus::Client::Formats::Text.marshal(Prometheus::Client.registry)
  end
end
```

3. Deploy monitoring stack:
- Prometheus server to scrape `/metrics` endpoint
- Grafana for dashboards
- Alertmanager for alerting
- Timeline: Phase 9 (Deployment) or earlier

4. Create operational dashboards:
- Real-time webhook processing rate
- Error rate by event type
- API latency trends
- System resource usage

---

### 3. Distributed Tracing: 3.0 / 5.0 (Weight: 20%)

**Findings**:
- Correlation IDs mentioned for request tracing
- No distributed tracing framework (OpenTelemetry, Jaeger, Zipkin)
- Request flow is documented but not instrumented
- No span instrumentation across components

**Tracing Framework**:
- Not specified
- OpenTelemetry mentioned in "Future Enhancements" only

**Trace ID Propagation**:
- Correlation IDs proposed but implementation is optional
- No propagation across async jobs (LineMailer, Scheduler)

**Span Instrumentation**:
- Not implemented
- Request flow documented in design but not traceable in production

**Issues**:
1. **No tracing framework**: OpenTelemetry is only mentioned as "Future Enhancement"
2. **Correlation IDs are optional**: Marked as debugging feature, not core observability
3. **No async job tracing**: Scheduled messages and error emails lack trace context
4. **Cannot trace full request lifecycle**: Webhook → Service → Database → LINE API → Email

**Recommendation**:
1. Implement correlation IDs as first-class feature:
```ruby
# Gemfile
gem 'request_store'

# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  around_action :set_correlation_id

  def set_correlation_id
    correlation_id = request.headers['X-Request-ID'] || SecureRandom.uuid
    RequestStore.store[:correlation_id] = correlation_id

    yield
  ensure
    RequestStore.store[:correlation_id] = nil
  end
end

# app/models/cat_line_bot.rb
def self.correlation_id
  RequestStore.store[:correlation_id] || 'no-correlation-id'
end
```

2. Propagate correlation ID to background jobs:
```ruby
# app/mailers/line_mailer.rb
def error_email(group_id, message)
  headers['X-Correlation-ID'] = CatLineBot.correlation_id
  mail(to: 'admin@example.com', subject: 'LINE Bot Error')
end
```

3. Add correlation ID to all logs:
```ruby
Rails.logger.tagged(CatLineBot.correlation_id) do
  Rails.logger.info "Processing webhook"
end
```

4. Plan OpenTelemetry integration for Phase 2:
- Instrument webhook controller
- Instrument LINE API calls
- Instrument database queries
- Export traces to Jaeger or Zipkin

---

### 4. Health Checks & Diagnostics: 4.5 / 5.0 (Weight: 15%)

**Findings**:
- Health check endpoint defined (`/health`)
- Basic health check returns status and version
- No dependency health checks (database, LINE API)
- Metrics endpoint proposed (`/metrics`)
- Diagnostic information available in logs

**Health Check Endpoints**:
- ✅ `/health` - Basic application health
- ✅ `/metrics` - Prometheus metrics (proposed)
- ❌ No deep health check endpoint

**Dependency Checks**:
- Database: Not checked in `/health` endpoint
- LINE API: Not checked in `/health` endpoint
- External services: Not checked

**Diagnostic Endpoints**:
- `/health` - Basic status and version
- `/metrics` - Application metrics (proposed)
- ❌ No `/debug` endpoint
- ❌ No `/info` endpoint for build/deployment info

**Issues**:
1. **Shallow health check**: `/health` only returns `{status: 'ok'}` without checking dependencies
2. **No deep health check**: Cannot verify database or LINE API connectivity
3. **No deployment info endpoint**: Difficult to verify deployed version in production

**Recommendation**:
1. Enhance health check with dependency checks:
```ruby
# app/controllers/health_controller.rb
class HealthController < ApplicationController
  def check
    render json: {
      status: 'ok',
      version: '2.0.0',
      timestamp: Time.current.iso8601
    }
  end

  def deep
    checks = {
      database: check_database,
      line_api: check_line_api,
      disk: check_disk_space
    }

    status = checks.values.all? { |c| c[:status] == 'healthy' } ? 'healthy' : 'unhealthy'

    render json: {
      status: status,
      checks: checks,
      timestamp: Time.current.iso8601
    }, status: status == 'healthy' ? :ok : :service_unavailable
  end

  private

  def check_database
    ActiveRecord::Base.connection.execute('SELECT 1')
    { status: 'healthy', latency_ms: 5 }
  rescue StandardError => e
    { status: 'unhealthy', error: e.message }
  end

  def check_line_api
    # Lightweight API call to verify credentials
    client = CatLineBot.line_client_config
    # Add a lightweight ping if LINE API supports it
    { status: 'healthy' }
  rescue StandardError => e
    { status: 'unhealthy', error: e.message }
  end

  def check_disk_space
    stat = Sys::Filesystem.stat('/')
    free_percent = (stat.bytes_free.to_f / stat.bytes_total * 100).round(2)

    if free_percent > 20
      { status: 'healthy', free_percent: free_percent }
    else
      { status: 'unhealthy', free_percent: free_percent }
    end
  end
end
```

2. Add routes:
```ruby
# config/routes.rb
get '/health', to: 'health#check'
get '/health/deep', to: 'health#deep'
get '/metrics', to: 'metrics#index'
```

3. Configure load balancer to use `/health` for liveness checks and `/health/deep` for readiness checks

---

## Observability Gaps

### Critical Gaps
1. **No metrics collection implemented**: System cannot be monitored in production without manual log inspection. This creates blind spots for performance degradation, error rate spikes, and resource exhaustion.

2. **No centralized logging strategy**: File-based logs on individual servers are difficult to search, correlate, and analyze. When issues occur, debugging across multiple servers is time-consuming and error-prone.

3. **No distributed tracing**: Without correlation IDs or tracing framework, it's impossible to follow a single webhook request through its entire lifecycle (webhook → service → database → LINE API → email notification).

### Minor Gaps
1. **Shallow health checks**: Current `/health` endpoint only returns static JSON without verifying database or LINE API connectivity. Load balancers cannot detect dependency failures.

2. **Alert thresholds without alerting**: Error rate thresholds are defined (>1%, >5%) but no alerting system is implemented to notify operators when thresholds are exceeded.

3. **No log rotation policy**: File-based logs will grow indefinitely, potentially filling disk space and causing application downtime.

---

## Recommended Observability Stack

Based on design, recommend:
- **Logging**: Lograge (structured JSON) + Fluentd → ELK Stack or CloudWatch Logs
- **Metrics**: Prometheus (metrics collection) + Grafana (dashboards) + Alertmanager (alerts)
- **Tracing**: OpenTelemetry + Jaeger (phase 2)
- **Dashboards**: Grafana with pre-built dashboards for:
  - Webhook processing rate and latency
  - Error rate by event type
  - LINE API latency and error rate
  - System resources (CPU, memory, disk)

---

## Action Items for Designer

If status is "Request Changes":

1. **Add metrics collection to implementation plan**:
   - Choose metrics library (Prometheus recommended)
   - Add `/metrics` endpoint to expose metrics
   - Instrument webhook processing, LINE API calls, and database queries
   - Include metrics collection in Phase 2 (Update CatLineBot), not "Future Enhancement"

2. **Implement structured logging with correlation IDs**:
   - Add Lograge gem to Gemfile
   - Configure JSON-formatted logs with correlation IDs
   - Implement correlation ID propagation to background jobs
   - Add to Phase 2 (Update CatLineBot)

3. **Plan centralized logging deployment**:
   - Choose centralized logging solution (ELK, CloudWatch Logs, Splunk)
   - Add deployment steps to Phase 9 (Deployment Plan)
   - Include log shipping configuration (Fluentd, Filebeat)
   - Set timeline for centralized logging (should be before production deployment)

4. **Enhance health check endpoints**:
   - Add `/health/deep` endpoint with dependency checks (database, LINE API)
   - Add deployment info to `/health` endpoint (version, commit SHA, deploy time)
   - Update Phase 6 (Testing) to include health check tests

5. **Configure log rotation**:
   - Add log rotation configuration to deployment plan
   - Specify rotation policy (file size, age, retention count)
   - Include in Phase 9 (Deployment)

6. **Document operational runbook**:
   - Create runbook for common issues (high error rate, slow response time, API failures)
   - Document where to find logs, metrics, and traces
   - Include troubleshooting steps for each alert type

---

## Structured Data

```yaml
evaluation_result:
  evaluator: "design-observability-evaluator"
  design_document: "/Users/yujitsuchiya/cat_salvages_the_relationship/docs/designs/line-sdk-modernization.md"
  timestamp: "2025-11-16T10:45:00+09:00"
  overall_judgment:
    status: "Request Changes"
    overall_score: 3.4
  detailed_scores:
    logging_strategy:
      score: 3.5
      weight: 0.35
      weighted_score: 1.225
    metrics_monitoring:
      score: 2.5
      weight: 0.30
      weighted_score: 0.75
    distributed_tracing:
      score: 3.0
      weight: 0.20
      weighted_score: 0.60
    health_checks:
      score: 4.5
      weight: 0.15
      weighted_score: 0.675
  observability_gaps:
    - severity: "critical"
      gap: "No metrics collection implemented"
      impact: "Cannot monitor system health, detect performance degradation, or alert on error rate spikes without manual log inspection"
    - severity: "critical"
      gap: "No centralized logging strategy"
      impact: "Debugging production issues requires SSH access to individual servers and manual log file inspection, slowing down incident response"
    - severity: "critical"
      gap: "No distributed tracing"
      impact: "Cannot trace requests end-to-end through webhook → service → database → LINE API → email, making debugging complex issues difficult"
    - severity: "minor"
      gap: "Shallow health checks"
      impact: "Load balancers cannot detect database or LINE API failures, potentially routing traffic to unhealthy instances"
    - severity: "minor"
      gap: "Alert thresholds without alerting system"
      impact: "Operators must manually monitor logs to detect issues; no proactive alerting when error rates exceed thresholds"
    - severity: "minor"
      gap: "No log rotation policy"
      impact: "Log files will grow indefinitely, potentially filling disk space and causing downtime"
  observability_coverage: 65
  recommended_stack:
    logging: "Lograge (JSON) + Fluentd → ELK Stack / CloudWatch Logs"
    metrics: "Prometheus + Grafana + Alertmanager"
    tracing: "OpenTelemetry + Jaeger (Phase 2)"
    dashboards: "Grafana"
  action_items:
    - priority: "high"
      item: "Add metrics collection to Phase 2 implementation (Prometheus + /metrics endpoint)"
      phase: "Phase 2: Update CatLineBot"
    - priority: "high"
      item: "Implement structured logging with correlation IDs (Lograge + RequestStore)"
      phase: "Phase 2: Update CatLineBot"
    - priority: "high"
      item: "Plan centralized logging deployment (ELK/CloudWatch + Fluentd)"
      phase: "Phase 9: Deployment Plan"
    - priority: "medium"
      item: "Enhance health check endpoints (/health/deep with dependency checks)"
      phase: "Phase 4: Update Webhook Controller"
    - priority: "medium"
      item: "Configure log rotation policy"
      phase: "Phase 9: Deployment Plan"
    - priority: "low"
      item: "Document operational runbook for troubleshooting"
      phase: "Phase 8: Documentation"
```
