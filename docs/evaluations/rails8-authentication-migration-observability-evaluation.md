# Design Observability Evaluation - Rails 8 Authentication Migration

**Evaluator**: design-observability-evaluator
**Design Document**: /Users/yujitsuchiya/cat_salvages_the_relationship/docs/designs/rails8-authentication-migration.md
**Evaluated**: 2025-11-24T00:00:00Z

---

## Overall Judgment

**Status**: Request Changes
**Overall Score**: 3.2 / 5.0

---

## Detailed Scores

### 1. Logging Strategy: 3.0 / 5.0 (Weight: 35%)

**Findings**:
The design includes basic logging for authentication events using Rails.logger, but lacks a comprehensive structured logging strategy. Logs are mentioned for specific scenarios but without a consistent framework, centralization strategy, or correlation IDs for request tracing.

**Logging Framework**:
- Rails.logger (standard Rails logging)
- No structured logging framework specified (e.g., Lograge, Semantic Logger)

**Log Context**:
The design includes some context fields:
- ✅ Email (operator email)
- ✅ IP address (request.remote_ip)
- ✅ Operator ID
- ✅ Timestamps (implicit)
- ✅ Failed login count
- ✅ Lock expiry times
- ❌ Request ID (not mentioned)
- ❌ Session ID (not mentioned)
- ❌ User agent (not mentioned)
- ❌ Authentication method (sorcery vs rails8 - only in one example)

**Log Levels**:
Properly differentiated:
- `Rails.logger.warn` - Authentication failures
- `Rails.logger.info` - Account locks, session creation
- `Rails.logger.error` - Migration issues, system errors

**Centralization**:
- Not specified
- No mention of log aggregation (ELK, Splunk, CloudWatch, etc.)
- No log retention policy

**Issues**:
1. **No structured logging**: Logs are string concatenation, not JSON/structured format. This makes them hard to parse and search programmatically.
2. **Missing request correlation**: No request ID or trace ID to correlate logs across multiple requests/components.
3. **No centralization strategy**: Logs stay on local server, difficult to aggregate and analyze across multiple instances.
4. **Inconsistent context**: Some logs include IP address, some don't. No standardized format.
5. **No log sampling/rate limiting**: Could be overwhelmed during attack scenarios.

**Recommendation**:
Implement structured logging with a consistent framework:

```ruby
# Use Lograge or similar for structured JSON logs
# config/initializers/lograge.rb
Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new

  config.lograge.custom_options = lambda do |event|
    {
      request_id: event.payload[:request_id],
      user_agent: event.payload[:user_agent],
      remote_ip: event.payload[:remote_ip]
    }
  end
end

# In Authentication concern
def authenticate_operator(email, password)
  context = {
    event: 'authentication_attempt',
    email: email,
    ip: request.remote_ip,
    request_id: request.request_id,
    user_agent: request.user_agent,
    timestamp: Time.current.iso8601
  }

  operator = Operator.find_by(email: email)

  if operator&.authenticate(password)
    Rails.logger.info(context.merge(
      result: 'success',
      operator_id: operator.id,
      auth_duration_ms: ((Time.current - start_time) * 1000).round(2)
    ))
  else
    Rails.logger.warn(context.merge(
      result: 'failure',
      reason: operator ? 'invalid_password' : 'email_not_found',
      failed_count: operator&.failed_logins_count
    ))
  end
end
```

**Add centralized logging:**
- Use CloudWatch Logs (if on AWS), Papertrail, or similar
- Configure log rotation and retention (e.g., 30 days)
- Enable log search and alerting

---

### 2. Metrics & Monitoring: 3.5 / 5.0 (Weight: 30%)

**Findings**:
The design includes good metrics tracking via SQL queries and mentions monitoring dashboards, but lacks a proper metrics collection system (e.g., Prometheus, StatsD). Metrics are calculated via database queries rather than emitted as events, which is inefficient and not real-time.

**Key Metrics**:
Metrics are well-defined:
- ✅ Authentication success rate (M-1)
- ✅ Account lock rate (M-2)
- ✅ Session creation rate (M-3)
- ✅ Error rate (M-4)
- ✅ Authentication latency/performance (M-5, PM-1)
- ✅ Password verification time (PM-2)
- ✅ Database query count (PM-3)
- ✅ Email notification delivery (SM-3)

**Monitoring System**:
- Not specified (only mentions "Dashboard queries" and "APM")
- SQL queries run every 5 minutes (inefficient, high DB load)
- No real-time metrics collection

**Alerts**:
Well-defined alert thresholds:
- ✅ Authentication failure rate > 5% for 10 minutes → Page on-call
- ✅ Account lock rate > 10% → Alert ops team
- ✅ Error rate > 2% → Alert ops team
- ✅ p95 latency > 1000ms → Alert ops team

**Dashboards**:
- Mentioned but not detailed
- "Authentication failure metrics dashboard" (PD-4)
- No visualization examples or dashboard design

**Issues**:
1. **No metrics instrumentation framework**: Relies on database queries instead of metrics emission (StatsD, Prometheus, etc.)
2. **Inefficient polling**: SQL queries every 5 minutes adds DB load
3. **Not real-time**: 5-minute intervals miss short-duration spikes
4. **No business metrics**: Missing metrics like "daily active operators", "new operator registrations", etc.
5. **No distributed metrics**: No mention of request tracing metrics (if multiple services involved)
6. **Alert implementation unclear**: How are alerts triggered? Email? PagerDuty? Slack?

**Recommendation**:
Implement a proper metrics instrumentation system:

```ruby
# Use StatsD, Prometheus, or Rails ActiveSupport::Notifications
# config/initializers/metrics.rb
require 'statsd'
STATSD = Statsd.new('localhost', 8125)

# In Authentication concern
def authenticate_operator(email, password)
  start_time = Time.current

  result = operator&.authenticate(password)

  # Emit metrics
  STATSD.increment('auth.attempts',
    tags: ["result:#{result ? 'success' : 'failure'}"])

  if result
    STATSD.timing('auth.duration',
      ((Time.current - start_time) * 1000).round(2))
  else
    STATSD.increment('auth.failures',
      tags: ["reason:#{operator ? 'invalid_password' : 'no_account'}"])
  end
end

# In BruteForceProtection concern
def lock_account!
  STATSD.increment('auth.account_locked')
  # ... existing code
end
```

**Set up monitoring dashboard:**
- Use Grafana, Datadog, or CloudWatch dashboards
- Real-time graphs for authentication success/failure rates
- Heatmaps for authentication latency distribution
- Alert notification via PagerDuty or Slack

---

### 3. Distributed Tracing: 2.0 / 5.0 (Weight: 20%)

**Findings**:
The design mentions request IDs in one logging example but has no comprehensive distributed tracing strategy. Since this is a Rails monolith migration (not microservices), distributed tracing is less critical, but request correlation is still important for debugging.

**Tracing Framework**:
- Not specified
- No OpenTelemetry, Jaeger, or Zipkin mentioned
- Rails provides `request.request_id` but not leveraged consistently

**Trace ID Propagation**:
- Not mentioned in design
- No trace context propagation across background jobs or external API calls

**Span Instrumentation**:
- Not mentioned
- No detailed timing breakdown of authentication flow (DB query time, password verification time, etc.)

**Issues**:
1. **No trace ID in logs**: Cannot correlate logs for a single request
2. **No background job tracing**: Email notifications are sent asynchronously, but no trace correlation
3. **No external service tracing**: If calling external services (future OAuth, etc.), no tracing strategy
4. **No detailed span data**: Cannot identify which step in auth flow is slow

**Recommendation**:
While full distributed tracing may be overkill for a monolith, implement basic request correlation:

```ruby
# In Authentication concern
def authenticate_operator(email, password)
  request_id = request.request_id

  Rails.logger.tagged(request_id) do
    Rails.logger.info("Auth attempt for email=#{email}")

    # ... authentication logic

    # If sending email notification
    SessionMailer.notice(operator, request.remote_ip).deliver_later(
      headers: { 'X-Request-ID' => request_id }
    )
  end
end

# In SessionMailer
class SessionMailer < ApplicationMailer
  def notice(operator, access_ip, request_id: nil)
    @request_id = request_id
    Rails.logger.info("Sending lock notification for operator=#{operator.id} request_id=#{request_id}")
    # ... mail logic
  end
end
```

**For future enhancements:**
- Consider OpenTelemetry for detailed request tracing
- Add instrumentation to measure DB query time, password hashing time separately
- Trace background jobs with request ID correlation

---

### 4. Health Checks & Diagnostics: 4.5 / 5.0 (Weight: 15%)

**Findings**:
The design includes excellent health check and validation strategies. Multiple verification steps are defined for deployment, and there are clear diagnostic procedures.

**Health Check Endpoints**:
- ✅ `/health` endpoint mentioned (Step 2.1: "curl -I https://your-domain.com/health")
- Unclear if this checks authentication system health specifically

**Dependency Checks**:
- ✅ Database connectivity verified ("Operator.find_by...")
- ✅ Email delivery monitoring (SM-3: ActionMailer delivery logs)
- Implicit checks for Rails app health

**Diagnostic Endpoints**:
- Not explicitly mentioned
- No `/metrics` endpoint for Prometheus scraping
- No debug endpoints for troubleshooting

**Deployment Verification**:
Excellent verification procedures:
- ✅ Password digest column verification
- ✅ Password migration verification (count missing passwords)
- ✅ Test authentication with known credentials
- ✅ Monitor authentication metrics post-deployment
- ✅ Rollback procedures well-documented

**Issues**:
1. **No authentication-specific health check**: `/health` endpoint should verify authentication system is functional
2. **No metrics endpoint**: No Prometheus-compatible `/metrics` endpoint
3. **No diagnostic mode**: Cannot enable verbose logging for debugging without code change

**Recommendation**:
Add authentication-specific health checks:

```ruby
# config/routes.rb
get '/health', to: 'health#index'
get '/health/auth', to: 'health#auth'

# app/controllers/health_controller.rb
class HealthController < ApplicationController
  skip_before_action :require_authentication

  def index
    render json: {
      status: 'ok',
      timestamp: Time.current.iso8601,
      version: Rails.application.config.version
    }
  end

  def auth
    # Test authentication system health
    checks = {
      database: check_database,
      password_digest_column: check_password_digest_column,
      mailer: check_mailer
    }

    status = checks.values.all? { |v| v[:status] == 'ok' } ? 'ok' : 'degraded'

    render json: {
      status: status,
      checks: checks,
      timestamp: Time.current.iso8601
    }
  end

  private

  def check_database
    Operator.connection.active?
    { status: 'ok', message: 'Database connected' }
  rescue => e
    { status: 'error', message: e.message }
  end

  def check_password_digest_column
    missing = Operator.where(password_digest: nil).count
    if missing.zero?
      { status: 'ok', message: 'All operators have password_digest' }
    else
      { status: 'warning', message: "#{missing} operators missing password_digest" }
    end
  end

  def check_mailer
    # Check if mailer can deliver
    { status: 'ok', message: 'Mailer configured' }
  rescue => e
    { status: 'error', message: e.message }
  end
end
```

---

## Observability Gaps

### Critical Gaps
1. **No structured logging framework**: String concatenation logs are difficult to parse and search. Cannot efficiently query "show me all failed logins for user X in the last 24 hours".
   - **Impact**: Difficult to debug authentication issues, slow incident response, cannot correlate events across requests.

2. **No metrics instrumentation system**: Relies on inefficient database queries instead of event-driven metrics collection. Not real-time, adds database load.
   - **Impact**: Cannot detect authentication failures in real-time, delayed alerting, potential database performance issues during monitoring.

3. **No request correlation strategy**: Missing request IDs in logs, no trace context propagation.
   - **Impact**: Cannot trace a user's authentication journey, difficult to debug issues that span multiple requests (login → session creation → protected page access).

### Minor Gaps
1. **No log centralization strategy**: Logs remain on individual servers.
   - **Impact**: Difficult to search logs across multiple instances, manual SSH required for investigation.

2. **No authentication-specific health checks**: Generic health endpoint doesn't verify auth system.
   - **Impact**: Load balancers cannot detect authentication system degradation.

3. **No metrics endpoint**: No Prometheus-compatible endpoint for scraping.
   - **Impact**: Manual integration required for monitoring tools.

---

## Recommended Observability Stack

Based on design, recommend:
- **Logging**: Lograge (structured JSON logs) + Papertrail/CloudWatch (centralization)
- **Metrics**: StatsD + Graphite OR Prometheus + Grafana
- **Tracing**: Rails request_id in all logs + OpenTelemetry (future enhancement)
- **Dashboards**: Grafana (metrics) + Papertrail (log search)
- **Alerting**: PagerDuty (critical) + Slack (warnings)

---

## Action Items for Designer

Since status is "Request Changes", please address the following:

### High Priority (Required for Approval)

1. **Add structured logging framework**:
   - Choose logging framework (Lograge, Semantic Logger, or custom)
   - Define standard log format with required fields (request_id, operator_id, email, ip, user_agent, timestamp)
   - Update all log examples in design to use structured format
   - Specify log levels and use cases

2. **Define metrics instrumentation strategy**:
   - Choose metrics system (StatsD, Prometheus, or Rails ActiveSupport::Notifications)
   - Replace database query-based metrics with event emission
   - Define metrics naming convention (e.g., `auth.attempts`, `auth.duration`, `auth.account_locked`)
   - Specify how metrics are collected and stored

3. **Add request correlation**:
   - Use Rails `request.request_id` consistently in all logs
   - Propagate request ID to background jobs (email notifications)
   - Include request ID in error responses for debugging

### Medium Priority (Recommended)

4. **Add log centralization strategy**:
   - Choose log aggregation service (CloudWatch, Papertrail, Splunk, ELK)
   - Define log retention policy (30 days, 90 days, etc.)
   - Specify log rotation and archival strategy

5. **Create authentication-specific health check**:
   - Add `/health/auth` endpoint that verifies:
     - Database connectivity
     - Password digest column integrity
     - Mailer functionality
   - Define health check response format

6. **Add metrics endpoint**:
   - If using Prometheus, add `/metrics` endpoint
   - Define metrics exposure strategy (internal-only, authentication required, etc.)

### Low Priority (Nice to Have)

7. **Add observability testing**:
   - Test that logs are emitted correctly (log assertions in tests)
   - Test that metrics are incremented (metrics assertions in tests)
   - Test health check endpoints return correct status

8. **Document debugging playbook**:
   - How to search logs for authentication failures
   - How to identify locked accounts
   - How to trace a user's authentication journey
   - Common error scenarios and their log patterns

---

## Structured Data

```yaml
evaluation_result:
  evaluator: "design-observability-evaluator"
  design_document: "/Users/yujitsuchiya/cat_salvages_the_relationship/docs/designs/rails8-authentication-migration.md"
  timestamp: "2025-11-24T00:00:00Z"
  overall_judgment:
    status: "Request Changes"
    overall_score: 3.2
  detailed_scores:
    logging_strategy:
      score: 3.0
      weight: 0.35
      weighted_score: 1.05
    metrics_monitoring:
      score: 3.5
      weight: 0.30
      weighted_score: 1.05
    distributed_tracing:
      score: 2.0
      weight: 0.20
      weighted_score: 0.40
    health_checks:
      score: 4.5
      weight: 0.15
      weighted_score: 0.675
  observability_gaps:
    - severity: "critical"
      gap: "No structured logging framework"
      impact: "Difficult to debug authentication issues, slow incident response, cannot correlate events"
    - severity: "critical"
      gap: "No metrics instrumentation system"
      impact: "Cannot detect failures in real-time, delayed alerting, database load"
    - severity: "critical"
      gap: "No request correlation strategy"
      impact: "Cannot trace user authentication journey, difficult to debug multi-request issues"
    - severity: "minor"
      gap: "No log centralization strategy"
      impact: "Difficult to search logs across instances"
    - severity: "minor"
      gap: "No authentication-specific health checks"
      impact: "Cannot detect auth system degradation"
    - severity: "minor"
      gap: "No metrics endpoint"
      impact: "Manual integration required for monitoring tools"
  observability_coverage: 64%
  recommended_stack:
    logging: "Lograge + Papertrail/CloudWatch"
    metrics: "StatsD + Graphite OR Prometheus + Grafana"
    tracing: "Rails request_id + OpenTelemetry (future)"
    dashboards: "Grafana + Papertrail"
    alerting: "PagerDuty + Slack"
```
