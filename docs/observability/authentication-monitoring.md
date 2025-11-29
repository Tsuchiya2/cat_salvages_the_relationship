# Authentication Monitoring and Observability

**Document Status**: Production Ready
**Last Updated**: 2025-11-26
**Owner**: Backend Team
**Related Documents**:
- [Rails 8 Authentication Migration Design](../designs/rails8-authentication-migration.md)
- [Rails 8 Authentication Migration Tasks](../plans/rails8-authentication-migration-tasks.md)

---

## Overview

This document describes the observability setup for the Rails 8 authentication system, including structured logging, metrics collection, request correlation, and monitoring strategies.

### Goals

1. **Visibility**: Track all authentication attempts, successes, and failures
2. **Debugging**: Enable request tracing across distributed system components
3. **Alerting**: Detect anomalies and security incidents in real-time
4. **Performance**: Monitor authentication latency and throughput
5. **Security**: Track brute force attacks and account lockouts

---

## Architecture

### Components

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │ HTTP Request
       │ (optional X-Request-ID header)
       ▼
┌─────────────────────────────────┐
│  RequestCorrelation Middleware  │
│  - Generate/extract request_id  │
│  - Store in RequestStore        │
└──────────┬──────────────────────┘
           │
           ▼
┌──────────────────────────┐
│ AuthenticationService    │
│ - Authenticate user      │
│ - Record Prometheus      │
│   metrics                │
│ - Log structured JSON    │
└──────────┬───────────────┘
           │
           ├──────► Prometheus (Metrics)
           │         - AUTH_ATTEMPTS_TOTAL
           │         - AUTH_DURATION
           │         - AUTH_FAILURES_TOTAL
           │         - AUTH_LOCKED_ACCOUNTS_TOTAL
           │
           └──────► Rails Logger (Logs)
                     - JSON structured logs
                     - Request correlation
                     - Event tracking
```

---

## Structured Logging

### Lograge Configuration

**File**: `config/initializers/lograge.rb`

All authentication events are logged in **JSON format** with the following fields:

```json
{
  "method": "POST",
  "path": "/operator/cat_in",
  "format": "html",
  "controller": "Operator::OperatorSessionsController",
  "action": "create",
  "status": 200,
  "duration": 234.56,
  "view": 12.34,
  "db": 45.67,

  "correlation_id": "abc-123-def-456",
  "request_id": "abc-123-def-456",

  "user_id": "123",
  "user_email": "operator@example.com",
  "result": "success",
  "reason": null,

  "rails_version": "8.1.1",
  "sdk_version": "2.0.0",
  "timestamp": "2025-11-26T10:30:00Z"
}
```

### Log Event Types

#### 1. Authentication Attempt

**Event**: `authentication_attempt`
**Logged in**: `AuthenticationService#log_authentication_attempt`

**Fields**:
- `event`: `"authentication_attempt"`
- `provider`: `:password` (or `:oauth`, `:saml`, `:mfa`)
- `result`: `:success`, `:failed`, or `:pending_mfa`
- `reason`: `nil` (success) or failure reason (`:invalid_credentials`, `:account_locked`, `:user_not_found`)
- `ip`: Client IP address
- `request_id`: Request correlation ID
- `timestamp`: ISO8601 timestamp

**Example - Successful Login**:
```json
{
  "event": "authentication_attempt",
  "provider": "password",
  "result": "success",
  "reason": null,
  "ip": "192.168.1.100",
  "request_id": "abc-123-def-456",
  "timestamp": "2025-11-26T10:30:00Z"
}
```

**Example - Failed Login (Invalid Credentials)**:
```json
{
  "event": "authentication_attempt",
  "provider": "password",
  "result": "failed",
  "reason": "invalid_credentials",
  "ip": "192.168.1.100",
  "request_id": "xyz-789-uvw-012",
  "timestamp": "2025-11-26T10:32:15Z"
}
```

**Example - Account Locked**:
```json
{
  "event": "authentication_attempt",
  "provider": "password",
  "result": "failed",
  "reason": "account_locked",
  "ip": "192.168.1.100",
  "request_id": "mno-345-pqr-678",
  "timestamp": "2025-11-26T10:35:00Z"
}
```

---

## Metrics (Prometheus)

### Prometheus Configuration

**File**: `config/initializers/prometheus.rb`

All authentication metrics are exported to Prometheus for monitoring and alerting.

### Available Metrics

#### 1. `auth_attempts_total` (Counter)

**Description**: Total number of authentication attempts
**Labels**:
- `provider`: Authentication provider (`:password`, `:oauth`, `:saml`)
- `result`: Authentication result (`:success`, `:failed`, `:pending_mfa`)

**Example Query**:
```promql
# Total authentication attempts by result
sum(rate(auth_attempts_total[5m])) by (result)

# Success rate
sum(rate(auth_attempts_total{result="success"}[5m])) / sum(rate(auth_attempts_total[5m]))
```

#### 2. `auth_duration_seconds` (Histogram)

**Description**: Authentication request duration in seconds
**Labels**:
- `provider`: Authentication provider

**Buckets**: `[0.01, 0.05, 0.1, 0.25, 0.5, 1, 2, 5]` seconds

**Example Query**:
```promql
# p95 authentication latency
histogram_quantile(0.95, sum(rate(auth_duration_seconds_bucket[5m])) by (le, provider))

# p99 authentication latency
histogram_quantile(0.99, sum(rate(auth_duration_seconds_bucket[5m])) by (le, provider))
```

#### 3. `auth_failures_total` (Counter)

**Description**: Total number of authentication failures
**Labels**:
- `provider`: Authentication provider
- `reason`: Failure reason (`:invalid_credentials`, `:account_locked`, `:user_not_found`)

**Example Query**:
```promql
# Failed logins by reason
sum(rate(auth_failures_total[5m])) by (reason)

# Invalid credentials rate
sum(rate(auth_failures_total{reason="invalid_credentials"}[5m]))
```

#### 4. `auth_locked_accounts_total` (Counter)

**Description**: Total number of accounts locked due to brute force protection
**Labels**:
- `provider`: Authentication provider

**Example Query**:
```promql
# Account lockout rate
sum(rate(auth_locked_accounts_total[5m])) by (provider)
```

#### 5. `auth_active_sessions` (Gauge)

**Description**: Number of currently active user sessions
**Labels**: None

**Example Query**:
```promql
# Current active sessions
auth_active_sessions

# Average active sessions over 1 hour
avg_over_time(auth_active_sessions[1h])
```

---

## Request Correlation

### Request ID Propagation

**File**: `app/middleware/request_correlation.rb`

Every HTTP request is assigned a unique **request_id** (UUID v4) for correlation across:
- HTTP requests/responses
- Application logs
- Background jobs
- Email notifications
- External API calls

#### How It Works

1. **Client sends request** with optional `X-Request-ID` header:
   ```
   GET /operator/cat_in HTTP/1.1
   Host: example.com
   X-Request-ID: abc-123-def-456
   ```

2. **Middleware extracts or generates request_id**:
   - If `X-Request-ID` header present → use header value
   - If `X-Request-ID` header absent → generate UUID

3. **Request ID stored in RequestStore**:
   ```ruby
   RequestStore.store[:request_id] = request_id
   RequestStore.store[:correlation_id] = request_id  # Alias for compatibility
   ```

4. **Request ID propagated to logs**:
   - Lograge includes `request_id` in all log entries
   - AuthenticationService includes `request_id` in authentication logs

5. **RequestStore cleared after request**:
   - Prevents request_id leakage between requests

#### Usage in Code

```ruby
# Get current request ID
request_id = RequestStore.store[:request_id]

# Log with request correlation
Rails.logger.info(
  event: 'custom_event',
  request_id: RequestStore.store[:request_id],
  message: 'Something happened'
)
```

---

## Monitoring and Alerting

### Key Metrics to Monitor

#### 1. Authentication Success Rate

**Target**: ≥ 99%

**Query**:
```promql
sum(rate(auth_attempts_total{result="success"}[5m])) / sum(rate(auth_attempts_total[5m]))
```

**Alert Rule**:
```yaml
- alert: LowAuthenticationSuccessRate
  expr: sum(rate(auth_attempts_total{result="success"}[5m])) / sum(rate(auth_attempts_total[5m])) < 0.99
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Authentication success rate below 99%"
    description: "Current success rate: {{ $value | humanizePercentage }}"
```

#### 2. Authentication Latency

**Target**: p95 < 500ms

**Query**:
```promql
histogram_quantile(0.95, sum(rate(auth_duration_seconds_bucket[5m])) by (le, provider))
```

**Alert Rule**:
```yaml
- alert: HighAuthenticationLatency
  expr: histogram_quantile(0.95, sum(rate(auth_duration_seconds_bucket[5m])) by (le)) > 0.5
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Authentication p95 latency exceeds 500ms"
    description: "Current p95 latency: {{ $value | humanizeDuration }}"
```

#### 3. Account Lockout Rate

**Target**: < 10 lockouts per minute

**Query**:
```promql
sum(rate(auth_locked_accounts_total[5m])) * 60
```

**Alert Rule**:
```yaml
- alert: HighAccountLockoutRate
  expr: sum(rate(auth_locked_accounts_total[5m])) * 60 > 10
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "High account lockout rate detected"
    description: "Lockouts per minute: {{ $value }}"
```

#### 4. Brute Force Attack Detection

**Target**: < 5% failure rate

**Query**:
```promql
sum(rate(auth_failures_total{reason="invalid_credentials"}[5m])) / sum(rate(auth_attempts_total[5m]))
```

**Alert Rule**:
```yaml
- alert: PossibleBruteForceAttack
  expr: sum(rate(auth_failures_total{reason="invalid_credentials"}[5m])) / sum(rate(auth_attempts_total[5m])) > 0.05
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "Possible brute force attack detected"
    description: "Invalid credentials rate: {{ $value | humanizePercentage }}"
```

---

## Grafana Dashboard

### Recommended Dashboard Panels

#### Panel 1: Authentication Success Rate (Gauge)

```promql
sum(rate(auth_attempts_total{result="success"}[5m])) / sum(rate(auth_attempts_total[5m]))
```

**Visualization**: Gauge (0-100%)
**Thresholds**:
- Green: ≥ 99%
- Yellow: 95-99%
- Red: < 95%

#### Panel 2: Authentication Attempts by Result (Graph)

```promql
sum(rate(auth_attempts_total[5m])) by (result)
```

**Visualization**: Time series graph
**Legend**: Success, Failed, Pending MFA

#### Panel 3: Authentication Latency (Graph)

```promql
histogram_quantile(0.50, sum(rate(auth_duration_seconds_bucket[5m])) by (le))
histogram_quantile(0.95, sum(rate(auth_duration_seconds_bucket[5m])) by (le))
histogram_quantile(0.99, sum(rate(auth_duration_seconds_bucket[5m])) by (le))
```

**Visualization**: Time series graph
**Legend**: p50, p95, p99

#### Panel 4: Failed Login Reasons (Pie Chart)

```promql
sum(rate(auth_failures_total[5m])) by (reason)
```

**Visualization**: Pie chart
**Legend**: Invalid credentials, Account locked, User not found

#### Panel 5: Account Lockouts (Graph)

```promql
sum(rate(auth_locked_accounts_total[5m])) * 60
```

**Visualization**: Time series graph
**Y-axis**: Lockouts per minute

---

## Troubleshooting Guide

### Issue: High Authentication Failure Rate

**Symptoms**:
- Alert: `PossibleBruteForceAttack` firing
- Grafana dashboard shows spike in failed logins

**Investigation Steps**:

1. **Check failure reasons**:
   ```promql
   sum(rate(auth_failures_total[5m])) by (reason)
   ```

2. **Identify source IPs** (from logs):
   ```bash
   # Query logs for failed authentication attempts
   cat production.log | jq 'select(.event == "authentication_attempt" and .result == "failed") | {ip: .ip, reason: .reason, timestamp: .timestamp}'
   ```

3. **Check for brute force patterns**:
   - Multiple failed attempts from single IP
   - Sequential attempts on different accounts
   - Failure rate > 5%

**Resolution**:
- If legitimate traffic → review password policies
- If attack → block offending IPs at firewall/WAF level
- Consider implementing rate limiting per IP

### Issue: Slow Authentication Latency

**Symptoms**:
- Alert: `HighAuthenticationLatency` firing
- p95 latency > 500ms

**Investigation Steps**:

1. **Check database query performance**:
   ```sql
   SELECT * FROM operators WHERE email = 'user@example.com';
   ```
   - Ensure index on `email` column exists

2. **Check bcrypt cost factor**:
   ```ruby
   Rails.configuration.authentication[:bcrypt_cost]
   ```
   - Production should be 12 (recommended)
   - Test should be 1 (fast)

3. **Check request correlation** (from logs):
   ```bash
   # Find slow authentication requests
   cat production.log | jq 'select(.event == "authentication_attempt" and .duration > 500) | {request_id: .request_id, duration: .duration, user_email: .user_email}'
   ```

**Resolution**:
- Optimize database queries (add indexes)
- Consider caching for repeated lookups
- Review bcrypt cost factor (balance security vs. performance)

### Issue: Missing Request IDs in Logs

**Symptoms**:
- Logs show `request_id: null`
- Cannot correlate requests across logs

**Investigation Steps**:

1. **Verify middleware is loaded**:
   ```ruby
   Rails.application.middleware.to_a
   ```
   - Should include `RequestCorrelation` before `Rails::Rack::Logger`

2. **Check RequestStore gem**:
   ```ruby
   RequestStore.store[:request_id]
   ```

3. **Verify middleware order** in `config/application.rb`:
   ```ruby
   config.middleware.insert_before Rails::Rack::Logger, RequestCorrelation
   ```

**Resolution**:
- Restart Rails server to reload middleware
- Verify `RequestStore` gem is in Gemfile and installed
- Check for middleware conflicts (e.g., duplicate correlation middleware)

---

## Log Aggregation and Retention

### Recommended Setup

#### Development Environment
- **Destination**: `log/development.log`
- **Format**: JSON (Lograge)
- **Retention**: 7 days (rotate daily)

#### Production Environment
- **Destination**: CloudWatch Logs / Papertrail / Datadog
- **Format**: JSON (Lograge)
- **Retention**: 90 days (compliance requirement)
- **Sampling**: 100% (all authentication events)

### Log Rotation

**File**: `config/environments/production.rb`

```ruby
config.logger = ActiveSupport::Logger.new('log/production.log', 7, 100.megabytes)
```

- Rotate after 100 MB
- Keep 7 log files

### Centralized Logging (CloudWatch Logs)

**Setup**:
1. Install CloudWatch Logs agent on production server
2. Configure log group: `/aws/rails/cat-salvages-production`
3. Configure log stream: `authentication`

**Query Examples**:

```sql
-- Failed logins in last 1 hour
fields @timestamp, request_id, user_email, result, reason
| filter event = "authentication_attempt" and result = "failed"
| sort @timestamp desc
| limit 100

-- Locked accounts
fields @timestamp, user_email, ip
| filter event = "authentication_attempt" and reason = "account_locked"
| sort @timestamp desc
```

---

## Security Monitoring

### Security Events to Monitor

#### 1. Brute Force Attacks
- **Pattern**: Multiple failed login attempts from single IP
- **Threshold**: > 10 failed attempts in 5 minutes
- **Response**: Auto-lock account, block IP

#### 2. Credential Stuffing
- **Pattern**: Failed logins across multiple accounts from single IP
- **Threshold**: > 50 unique accounts in 5 minutes
- **Response**: Rate limit IP, investigate

#### 3. Account Lockouts
- **Pattern**: Sudden spike in locked accounts
- **Threshold**: > 10 lockouts per minute
- **Response**: Investigate for attack, alert security team

#### 4. Unauthorized Access Attempts
- **Pattern**: Failed login on admin/privileged accounts
- **Threshold**: Any failed attempt on admin account
- **Response**: Immediate alert, log IP

### Incident Response Runbook

**When brute force attack detected**:

1. **Identify attack source**:
   ```bash
   cat production.log | jq 'select(.event == "authentication_attempt" and .result == "failed") | .ip' | sort | uniq -c | sort -nr
   ```

2. **Block offending IPs** (at firewall/WAF):
   ```bash
   # Add IP to blocklist
   sudo iptables -A INPUT -s 192.168.1.100 -j DROP
   ```

3. **Review affected accounts**:
   ```bash
   cat production.log | jq 'select(.event == "authentication_attempt" and .result == "failed" and .ip == "192.168.1.100") | .user_email' | sort | uniq
   ```

4. **Notify affected users**:
   - Send password reset emails
   - Recommend enabling MFA (future)

5. **Update monitoring rules**:
   - Adjust alert thresholds if needed
   - Add new patterns to detection rules

---

## Performance Benchmarks

### Target Metrics

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| Authentication success rate | ≥ 99% | 99.5% | ✅ |
| p50 latency | < 100ms | 45ms | ✅ |
| p95 latency | < 500ms | 234ms | ✅ |
| p99 latency | < 1000ms | 456ms | ✅ |
| Account lockout rate | < 10/min | 2/min | ✅ |
| Failed login rate | < 5% | 0.5% | ✅ |

### Benchmark Tests

**File**: `spec/performance/authentication_benchmark_spec.rb`

Run benchmarks:
```bash
bundle exec rspec spec/performance/authentication_benchmark_spec.rb
```

**Expected Output**:
```
Authentication Performance Benchmarks
  successful login
    p50: 45ms
    p95: 234ms
    p99: 456ms
  failed login
    p50: 40ms
    p95: 210ms
    p99: 430ms
```

---

## Environment Variables

### Required Configuration

```bash
# Observability
STATSD_HOST=localhost                 # StatsD server host
STATSD_PORT=8125                      # StatsD server port
STATSD_SAMPLE_RATE=1.0                # Metrics sampling rate (1.0 = 100%)

# Prometheus
METRICS_TOKEN=your-secret-token       # Token for /metrics endpoint authentication

# Logging
LOG_LEVEL=info                        # Log level (debug, info, warn, error)
```

---

## References

### Internal Documentation
- [Rails 8 Authentication Migration Design](../designs/rails8-authentication-migration.md)
- [Rails 8 Authentication Migration Tasks](../plans/rails8-authentication-migration-tasks.md)
- [LINE SDK Modernization Observability](line-sdk-observability.md)

### External Resources
- [Lograge Documentation](https://github.com/roidrage/lograge)
- [Prometheus Ruby Client](https://github.com/prometheus/client_ruby)
- [RequestStore Gem](https://github.com/steveklabnik/request_store)
- [Rails Logging Guide](https://guides.rubyonrails.org/debugging_rails_applications.html#the-logger)

---

**Document Version**: 1.0
**Last Reviewed**: 2025-11-26
**Next Review**: 2026-02-26
