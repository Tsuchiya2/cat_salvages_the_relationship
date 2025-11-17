# Design Reliability Evaluation - LINE Bot SDK Modernization

**Evaluator**: design-reliability-evaluator
**Design Document**: /Users/yujitsuchiya/cat_salvages_the_relationship/docs/designs/line-sdk-modernization.md
**Evaluated**: 2025-11-16T14:30:00+09:00

---

## Overall Judgment

**Status**: Request Changes
**Overall Score**: 3.65 / 5.0

---

## Detailed Scores

### 1. Error Handling Strategy: 3.5 / 5.0 (Weight: 35%)

**Findings**:
The design demonstrates a solid foundation for error handling with comprehensive error categorization and recovery strategies. However, several critical gaps exist in the implementation details that could lead to unhandled failure scenarios.

**Failure Scenarios Checked**:
- Database unavailable: Partially Handled (retry strategy mentioned but not fully implemented)
- S3 upload fails: Not Applicable (this system doesn't use S3)
- LINE API errors (401, 429, 404, 400, 500): Handled (documented in Section 12)
- Network timeouts: Handled (retry strategy with exponential backoff)
- Validation errors: Handled (input validation for group IDs)
- Invalid webhook signature: Handled (returns 400 Bad Request)
- Member count API failures: Handled (graceful degradation with fallback to count=2)

**Strengths**:
1. **Comprehensive Error Categorization**: Section 12 identifies 4 distinct error categories (LINE API, Network, Application, Business Logic)
2. **Multiple Recovery Strategies**: Implements retry with exponential backoff, graceful degradation, and email notifications
3. **Error Sanitization**: Includes security-conscious error message sanitization (SC-3) to prevent credential leakage
4. **Per-Event Error Isolation**: Design ensures one failing event doesn't crash entire webhook batch

**Issues**:

1. **Missing Circuit Breaker Implementation**: While circuit breaker pattern is mentioned (Section 12, Strategy 3), it's marked as "Future Enhancement" rather than core implementation. This leaves the system vulnerable to cascading failures if LINE API experiences sustained outages.

2. **Incomplete Retry Logic Details**: The `with_retry` method (Section 12) is provided but critical questions remain unanswered:
   - Which specific operations use retry logic?
   - Are database writes retried (they shouldn't be to avoid duplicate records)?
   - Are message sends retried (idempotency concerns)?
   - What happens after max retry attempts are exhausted?

3. **Inconsistent Error Response Strategy**: For webhook processing failures, the design returns 200 OK to LINE platform even when processing fails (Section 3, Data Flow). This prevents LINE's automatic retry mechanism from working, potentially causing message loss.

4. **Database Transaction Rollback Missing**: The design updates LineGroup records during webhook processing but doesn't specify transaction boundaries. If member count retrieval succeeds but database update fails, the system state becomes inconsistent.

5. **No Dead Letter Queue**: Failed events that exhaust retries have no recovery path except manual intervention via email notifications. This makes recovery difficult at scale.

**Recommendation**:

**Critical (Must Fix Before Approval):**

1. **Implement Transaction Management**:
```ruby
def parse_event(event, client)
  ActiveRecord::Base.transaction do
    # Query member count
    # Create/update LineGroup
    # Route to action handlers
  end
rescue ActiveRecord::RecordInvalid => e
  # Log validation error, don't retry
  Rails.logger.error "Validation failed: #{e.message}"
rescue StandardError => e
  # Rollback transaction, send notification
  raise
end
```

2. **Define Clear Retry Policies**:
- **Member count queries**: Retry up to 3 times with exponential backoff
- **Message sends**: Retry up to 3 times (LINE API is idempotent)
- **Database writes**: No retry (use transactions instead)
- **Leave operations**: Retry up to 3 times

3. **Fix Webhook Response Pattern**:
```ruby
def callback
  begin
    # Process webhook
    head :ok
  rescue StandardError => e
    # Log error
    head :bad_request # Let LINE retry
  end
end
```

**Recommended (Should Consider):**

4. Implement basic circuit breaker for LINE API calls (not future enhancement)
5. Add dead letter queue for failed events (could use database table or Redis)
6. Add idempotency keys to prevent duplicate processing on LINE's retry

---

### 2. Fault Tolerance: 3.5 / 5.0 (Weight: 30%)

**Findings**:
The design demonstrates good awareness of fault tolerance principles with graceful degradation and zero-downtime deployment strategy. However, single points of failure and lack of fallback mechanisms limit overall resilience.

**Fallback Mechanisms**:
- Member count API failure → Fallback to default count=2 (Section 12, Strategy 2)
- Client memoization → Reduces initialization failures (Section 5)
- No fallback for message sending failures
- No fallback for database unavailability

**Retry Policies**:
- Network errors: Retry with exponential backoff (max 3 attempts, backoff=2)
- LINE API 500 errors: Retry with exponential backoff
- No retry policy for 4xx errors (correct behavior)

**Circuit Breakers**:
- Mentioned in Section 12 but marked as "Future Enhancement"
- Not implemented in core design

**Strengths**:

1. **Zero-Downtime Deployment Strategy**: Rolling restart with Puma workers (Section 8) ensures continuous availability during deployment
2. **Graceful Degradation for Member Counts**: Falls back to count=2 if API fails, allowing core functionality to continue
3. **Per-Event Error Isolation**: Design processes events independently, so one failure doesn't cascade
4. **Health Check Endpoint**: Defined in Appendix D for deployment verification

**Issues**:

1. **Single Point of Failure - Database**: No strategy for database unavailability. If MySQL/PostgreSQL is down, the entire system fails. No read replicas, no caching layer mentioned.

2. **Single Point of Failure - LINE API**: If LINE Messaging API is completely unavailable, scheduled messages fail with no queuing or retry mechanism beyond immediate retries.

3. **No Message Queue for Scheduled Messages**: Scheduler directly calls LINE API (Section 3, Scheduled Message Flow). If scheduler fails mid-batch, partial messages are sent with no recovery.

4. **Missing Fallback for Welcome Messages**: Join events send welcome messages synchronously. If message send fails, LineGroup is still created but welcome message is lost forever.

5. **No Rate Limit Handling**: Design acknowledges LINE API rate limits (1000 req/sec) but doesn't define behavior when limits are approached. Current traffic is low, but design should handle future scale.

6. **Webhook Processing Timeout**: No timeout defined for webhook processing. A slow database query or LINE API call could cause webhook timeout (LINE expects response within ~10 seconds).

**Recommendation**:

**Critical (Must Fix Before Approval):**

1. **Add Database Connection Resilience**:
```ruby
# Use Rails connection pool with retry
config.active_record.connection_pool_size = 10
config.active_record.checkout_timeout = 5

# Add connection retry in webhook processing
def callback
  ActiveRecord::Base.connection_pool.with_connection do
    # Process webhook
  end
rescue ActiveRecord::ConnectionTimeoutError => e
  Rails.logger.error "Database connection timeout"
  head :service_unavailable # Let LINE retry
end
```

2. **Add Webhook Processing Timeout**:
```ruby
require 'timeout'

def callback
  Timeout.timeout(8) do # Leave 2s buffer for LINE's 10s timeout
    # Process webhook
  end
rescue Timeout::Error
  Rails.logger.error "Webhook processing timeout"
  head :request_timeout
end
```

3. **Implement Asynchronous Message Sending for Non-Critical Messages**:
```ruby
# Welcome messages can be sent async
def join_events(event, client, group_id)
  WelcomeMessageJob.perform_later(group_id, client)
end
```

**Recommended (Should Consider):**

4. Add Redis cache for member counts (TTL: 1 hour) to reduce LINE API dependency
5. Implement message queue (Sidekiq + Redis) for scheduled messages
6. Add exponential backoff for rate limit errors (429)
7. Consider read replicas for database if scale increases

---

### 3. Transaction Management: 3.5 / 5.0 (Weight: 20%)

**Findings**:
The design identifies multi-step operations but lacks explicit transaction boundaries and rollback strategies. Database consistency could be compromised during partial failures.

**Multi-Step Operations**:
- Member count query + LineGroup creation: Atomicity **NOT Guaranteed**
- LineGroup update + Message send: Atomicity **NOT Guaranteed**
- Multiple message sends in scheduler: Atomicity **NOT Guaranteed**
- Leave operation + LineGroup deletion: Atomicity **NOT Guaranteed**

**Rollback Strategy**:
- No explicit rollback strategy defined in design
- Rails automatic transaction rollback on exception (implicit, not documented)
- No compensation transactions for distributed operations

**Strengths**:

1. **No Database Schema Changes**: Design constraint (C-2) prevents migration-related transaction issues
2. **Idempotent LineGroup Creation**: Uses `find_or_create_by` pattern implicitly (though not documented)
3. **No Cross-Database Transactions**: All data in single database simplifies transaction management

**Issues**:

1. **Missing Transaction Boundaries**: Webhook processing performs multiple database operations without explicit transaction wrapping:
   - Query LineGroup
   - Update post_count
   - Update remind_at
   - Update status

   If any step fails, database is left in inconsistent state.

2. **No Saga Pattern for Distributed Operations**: Operations that span database + LINE API (e.g., send message + update LineGroup) lack coordination:
   - If message send succeeds but database update fails → LineGroup state is stale
   - If database update succeeds but message send fails → No retry mechanism

3. **Scheduler Partial Batch Failure**: Scheduler processes multiple LineGroups in loop (Section 3). If processing fails mid-batch, some groups get messages while others don't, with no tracking of progress.

4. **Leave Event Race Condition**: Leave event checks member count, then deletes LineGroup. If another leave event arrives simultaneously, both might try to delete the same record, causing error.

5. **No Idempotency Guarantees**: LINE platform may retry webhook delivery if they don't receive 200 OK promptly. Design doesn't prevent duplicate message processing:
   - Same message could increment post_count twice
   - Same join event could send welcome message twice

**Recommendation**:

**Critical (Must Fix Before Approval):**

1. **Wrap Webhook Processing in Transaction**:
```ruby
def parse_event(event, client)
  ActiveRecord::Base.transaction do
    group_id = current_group_id(event)

    # Only database operations inside transaction
    count_members_response = count_members(event, client) # API call outside transaction
    member_count = count_members_response['count'].to_i

    # All DB operations atomic
    line_group = LineGroup.find_or_create_by(line_group_id: group_id) do |lg|
      lg.member_count = member_count
      lg.remind_at = 3.days.from_now
    end

    line_group.update!(
      post_count: line_group.post_count + 1,
      member_count: member_count
    )

    action_by_event_type(event, client, group_id, member_count)
  end
end
```

2. **Implement Two-Phase Commit for Message Sends**:
```ruby
def send_scheduled_message(line_group, messages, client)
  # Phase 1: Mark as processing
  line_group.update!(status: :processing)

  # Phase 2: Send messages
  messages.each { |msg| client.push_message(line_group.line_group_id, msg) }

  # Phase 3: Mark as complete
  line_group.update!(
    status: :wait,
    remind_at: calculate_next_remind_at(line_group)
  )
rescue StandardError => e
  # Rollback: Mark as failed for manual retry
  line_group.update!(status: :failed)
  raise
end
```

3. **Add Idempotency Tracking**:
```ruby
# Add webhook_event_id tracking to prevent duplicate processing
class LineGroup < ApplicationRecord
  has_many :processed_webhook_events
end

def parse_event(event, client)
  webhook_event_id = event.webhook_event_id # LINE provides this

  # Skip if already processed
  return if ProcessedWebhookEvent.exists?(webhook_event_id: webhook_event_id)

  ActiveRecord::Base.transaction do
    # Process event
    ProcessedWebhookEvent.create!(
      webhook_event_id: webhook_event_id,
      processed_at: Time.current
    )
  end
end
```

**Recommended (Should Consider):**

4. Add database-level unique constraints to prevent race conditions
5. Implement optimistic locking for concurrent LineGroup updates
6. Add event sourcing pattern for audit trail

---

### 4. Logging & Observability: 4.0 / 5.0 (Weight: 15%)

**Findings**:
The design demonstrates strong awareness of observability needs with comprehensive logging strategy, structured logging, and multiple monitoring approaches. This is the strongest reliability aspect of the design.

**Logging Strategy**:
- Structured logging: Yes (Section 12, uses JSON format)
- Log context: Yes (includes group_id, event_type, duration_ms, success)
- Distributed tracing: Partially (correlation IDs mentioned in Section 13)

**Strengths**:

1. **Comprehensive Log Coverage**: Section 13 defines 4 key event types to log:
   - Webhook receipt (timestamp, source IP, event count, signature validation)
   - Event processing (event type, group ID, duration, status)
   - Message sending (type, recipient, response code, latency)
   - Errors (class, sanitized message, truncated backtrace, context)

2. **Structured Logging Format**:
```ruby
Rails.logger.info({
  event: 'webhook.processed',
  group_id: group_id,
  event_type: event.class.name,
  duration_ms: elapsed,
  success: true
}.to_json)
```
This enables easy parsing and querying.

3. **Log Level Discipline**: Section 12 defines clear log level usage (DEBUG, INFO, WARN, ERROR, FATAL)

4. **Error Sanitization**: SC-3 (Section 10) sanitizes credentials from error messages to prevent leakage

5. **Correlation IDs**: Section 13 includes correlation ID pattern for request tracing

6. **Centralized Error Notifications**: LineMailer integration ensures critical errors reach humans

7. **Monitoring Metrics Defined**: Section 11 and 13 define comprehensive metrics:
   - Application: webhook requests/min, success rate, latency (p50, p95, p99)
   - LINE API: call success rate, API latency, rate limit usage
   - System: CPU, memory, disk I/O, network I/O

**Issues**:

1. **No Centralized Logging Solution**: Design mentions "Consider centralized logging (Splunk, ELK stack)" but doesn't require it. For production reliability, centralized logging should be mandatory, not optional.

2. **Missing Performance Instrumentation**: While ActiveSupport::Notifications pattern is shown (Section 11), it's not integrated into the main implementation. No guarantee that latency metrics will actually be collected.

3. **No Log Retention Policy**: Design doesn't specify log rotation, retention period, or archive strategy. Logs could fill disk in production.

4. **Insufficient Error Context**: While errors include group_id and event type, they lack:
   - User ID (if available)
   - Request ID from LINE platform
   - Environment information (Rails version, SDK version)
   - Timestamp of original webhook delivery (for debugging delays)

5. **No Alerting Thresholds Implementation**: Section 13 defines alert thresholds (error rate > 5%, response time > 5s) but doesn't specify how alerts are generated or where they're sent.

6. **Metrics Collection Not Implemented**: Section 13 shows StatsD/Prometheus example but marks it "Future Enhancement". Without actual metrics collection, observability is limited to logs only.

**Recommendation**:

**Critical (Must Fix Before Approval):**

1. **Add Log Rotation Configuration**:
```ruby
# config/environments/production.rb
config.logger = ActiveSupport::Logger.new(
  Rails.root.join('log', 'production.log'),
  5,           # Keep 5 archived log files
  10.megabytes # Rotate when file reaches 10MB
)
```

2. **Enhance Error Context**:
```ruby
def log_error(exception, context = {})
  Rails.logger.error({
    error_class: exception.class.name,
    error_message: sanitize_error_message(exception.message),
    backtrace: exception.backtrace.first(10),
    group_id: context[:group_id],
    event_type: context[:event_type],
    correlation_id: context[:correlation_id],
    rails_version: Rails.version,
    sdk_version: Line::Bot::VERSION,
    timestamp: Time.current.iso8601,
    environment: Rails.env
  }.to_json)
end
```

**Recommended (Should Consider):**

3. Implement centralized logging (mandatory for production, not optional)
4. Add performance instrumentation to all critical paths
5. Implement actual alerting system (not just thresholds)
6. Add log sampling for high-volume events (prevent log flooding)
7. Implement metrics collection (Prometheus recommended)

---

## Reliability Risk Assessment

### High Risk Areas

1. **Database Unavailability**
   - **Description**: No fallback or caching if database connection is lost. All webhook processing fails immediately.
   - **Impact**: Complete service outage, no message processing, no scheduled messages
   - **Probability**: Medium (database is critical dependency)
   - **Mitigation**: Add connection pooling retry, implement Redis cache for read-heavy operations, add health check monitoring

2. **Transaction Consistency**
   - **Description**: Multi-step operations (member count query + LineGroup creation/update + message send) lack atomic transaction boundaries.
   - **Impact**: Inconsistent database state, duplicate message processing on retry, lost updates
   - **Probability**: High (webhook retries from LINE platform are common)
   - **Mitigation**: Implement proper transaction wrapping, add idempotency tracking, use two-phase commit for distributed operations

3. **Webhook Processing Timeout**
   - **Description**: No timeout defined for webhook processing. Slow operations could exceed LINE's webhook timeout (~10 seconds).
   - **Impact**: LINE platform marks webhook as failed, retries delivery, causing duplicate processing
   - **Probability**: Medium (database slow queries or LINE API latency)
   - **Mitigation**: Add 8-second timeout with proper error handling, optimize database queries, add async processing for non-critical operations

### Medium Risk Areas

1. **LINE API Extended Outage**
   - **Description**: If LINE Messaging API is down for extended period, scheduled messages accumulate with no queuing mechanism.
   - **Impact**: Backlog of unsent messages, potential message storm when API recovers
   - **Probability**: Low (LINE has high SLA)
   - **Mitigation**: Implement message queue (Sidekiq), add circuit breaker, add rate limiting on recovery

2. **Error Notification Overflow**
   - **Description**: If errors spike, LineMailer could send hundreds of emails, overwhelming recipients and potentially hitting email rate limits.
   - **Impact**: Important errors missed, email delivery failures, alert fatigue
   - **Probability**: Medium (error spikes during incidents)
   - **Mitigation**: Implement error aggregation, add rate limiting to error emails, use alerting platform instead of email

3. **Partial Scheduler Batch Failure**
   - **Description**: Scheduler processes LineGroups in loop. If processing fails mid-batch, some groups receive messages while others don't.
   - **Impact**: Inconsistent user experience, difficult to recover (no tracking of which groups were processed)
   - **Probability**: Medium (any error in scheduler loop)
   - **Mitigation**: Add batch processing with checkpoints, mark groups as "processing" before sending, add recovery job

### Mitigation Strategies

1. **Implement Comprehensive Transaction Management**
   - Wrap all multi-step database operations in explicit transactions
   - Add optimistic locking for concurrent updates
   - Implement two-phase commit for operations spanning database + LINE API
   - Add idempotency tracking to prevent duplicate processing

2. **Add Resilience Patterns**
   - Implement circuit breaker for LINE API calls (not future enhancement, core requirement)
   - Add timeout protection for webhook processing (8 seconds max)
   - Implement retry with exponential backoff for transient failures
   - Add dead letter queue for permanently failed events

3. **Enhance Database Resilience**
   - Add connection pool with retry logic
   - Implement Redis cache for member counts (reduce API dependency)
   - Add read replicas for high-availability
   - Monitor connection pool exhaustion

4. **Improve Observability**
   - Mandate centralized logging (not optional)
   - Implement metrics collection (Prometheus/StatsD)
   - Add distributed tracing for request flow visibility
   - Implement proper alerting system (not just email)

5. **Add Asynchronous Processing**
   - Move non-critical operations (welcome messages) to background jobs
   - Implement message queue for scheduled messages
   - Add job retry and dead letter queue
   - Monitor job queue depth

---

## Action Items for Designer

**Status**: Request Changes

The design demonstrates good awareness of reliability concerns but lacks critical implementation details for production readiness. Please address the following issues:

### Critical (Must Fix for Approval)

1. **Add Explicit Transaction Management**
   - Define transaction boundaries for all multi-step database operations
   - Specify rollback behavior for failures
   - Add idempotency tracking to prevent duplicate processing from LINE webhook retries

2. **Implement Webhook Processing Timeout**
   - Add 8-second timeout for webhook processing
   - Define behavior when timeout is exceeded
   - Add proper error response to trigger LINE's retry mechanism

3. **Add Database Resilience**
   - Implement connection pool retry logic
   - Define behavior when database is unavailable
   - Add health check for database connection

4. **Fix Error Response Pattern**
   - Return appropriate HTTP status codes (400/503) for failures instead of always 200 OK
   - Allow LINE platform's retry mechanism to work correctly
   - Add idempotency to handle retries safely

5. **Define Retry Policies Explicitly**
   - Specify which operations retry and which don't
   - Document retry limits and backoff strategy for each operation type
   - Clarify handling after max retries exhausted

6. **Add Log Rotation Configuration**
   - Specify log retention policy
   - Configure log rotation to prevent disk space exhaustion
   - Define log archive strategy

### Recommended (Strongly Suggested)

7. **Implement Circuit Breaker** (move from "Future Enhancement" to core)
   - Prevent cascading failures when LINE API is degraded
   - Define circuit breaker thresholds and timeout
   - Add circuit breaker status monitoring

8. **Add Asynchronous Processing for Non-Critical Operations**
   - Move welcome messages to background jobs
   - Implement message queue for scheduled messages
   - Add job monitoring and dead letter queue

9. **Enhance Error Context in Logs**
   - Add Rails version, SDK version, environment to error logs
   - Include LINE platform request IDs if available
   - Add user context where applicable

10. **Mandate Centralized Logging**
    - Make centralized logging (ELK/Splunk) required, not optional
    - Specify log aggregation strategy
    - Define log query and search requirements

### After Addressing Changes

Please revise the design document to include:

1. **Section 6 (Implementation Plan)**: Add tasks for transaction management, timeout implementation, circuit breaker
2. **Section 12 (Error Handling)**: Specify which operations use which recovery strategies
3. **Section 8 (Deployment Plan)**: Add rollback criteria for transaction consistency issues
4. **Section 13 (Observability)**: Make centralized logging mandatory
5. **New Section**: Add "Transaction Boundaries" subsection to Section 4 (Data Model)

Once these critical issues are addressed, the design will be suitable for Phase 2 (Planning).

---

## Structured Data

```yaml
evaluation_result:
  evaluator: "design-reliability-evaluator"
  design_document: "/Users/yujitsuchiya/cat_salvages_the_relationship/docs/designs/line-sdk-modernization.md"
  timestamp: "2025-11-16T14:30:00+09:00"
  overall_judgment:
    status: "Request Changes"
    overall_score: 3.65
  detailed_scores:
    error_handling:
      score: 3.5
      weight: 0.35
      weighted_contribution: 1.225
    fault_tolerance:
      score: 3.5
      weight: 0.30
      weighted_contribution: 1.05
    transaction_management:
      score: 3.5
      weight: 0.20
      weighted_contribution: 0.70
    logging_observability:
      score: 4.0
      weight: 0.15
      weighted_contribution: 0.60
  failure_scenarios:
    - scenario: "Database unavailable"
      handled: true
      strategy: "Connection pool retry (not fully specified)"
      risk_level: "high"
    - scenario: "LINE API unavailable (500)"
      handled: true
      strategy: "Retry with exponential backoff"
      risk_level: "medium"
    - scenario: "LINE API authentication failure (401)"
      handled: true
      strategy: "Email notification, no retry"
      risk_level: "low"
    - scenario: "Invalid webhook signature"
      handled: true
      strategy: "Return 400 Bad Request"
      risk_level: "low"
    - scenario: "Network timeout"
      handled: true
      strategy: "Retry with exponential backoff"
      risk_level: "medium"
    - scenario: "Member count API failure"
      handled: true
      strategy: "Graceful degradation (fallback to count=2)"
      risk_level: "low"
    - scenario: "Webhook processing timeout"
      handled: false
      strategy: "Not specified"
      risk_level: "high"
    - scenario: "Transaction partial failure"
      handled: false
      strategy: "Not specified"
      risk_level: "high"
    - scenario: "Duplicate webhook delivery (LINE retry)"
      handled: false
      strategy: "Not specified"
      risk_level: "high"
  reliability_risks:
    - severity: "high"
      area: "Database unavailability"
      description: "No fallback or caching if database connection is lost"
      mitigation: "Add connection pooling retry, implement Redis cache, add health check monitoring"
    - severity: "high"
      area: "Transaction consistency"
      description: "Multi-step operations lack atomic transaction boundaries"
      mitigation: "Implement proper transaction wrapping, add idempotency tracking, use two-phase commit"
    - severity: "high"
      area: "Webhook processing timeout"
      description: "No timeout defined for webhook processing, could exceed LINE's webhook timeout"
      mitigation: "Add 8-second timeout with proper error handling, optimize database queries, add async processing"
    - severity: "medium"
      area: "LINE API extended outage"
      description: "Scheduled messages accumulate with no queuing mechanism"
      mitigation: "Implement message queue (Sidekiq), add circuit breaker, add rate limiting on recovery"
    - severity: "medium"
      area: "Error notification overflow"
      description: "Error spikes could send hundreds of emails"
      mitigation: "Implement error aggregation, add rate limiting to error emails, use alerting platform"
    - severity: "medium"
      area: "Partial scheduler batch failure"
      description: "Scheduler could fail mid-batch with no recovery tracking"
      mitigation: "Add batch processing with checkpoints, mark groups as processing, add recovery job"
  error_handling_coverage: 65
  transaction_management_coverage: 40
  fault_tolerance_coverage: 55
  observability_coverage: 80
  critical_issues_count: 6
  recommended_issues_count: 4
```
