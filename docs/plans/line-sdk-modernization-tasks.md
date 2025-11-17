# Task Plan - LINE Bot SDK Modernization

**Feature ID**: FEAT-LINE-SDK-001
**Design Document**: docs/designs/line-sdk-modernization.md
**Created**: 2025-11-17
**Planner**: planner agent

---

## Metadata

```yaml
task_plan_metadata:
  feature_id: "FEAT-LINE-SDK-001"
  feature_name: "LINE Bot SDK Modernization"
  total_tasks: 38
  estimated_duration: "8-10 hours"
  critical_path: ["TASK-1.1", "TASK-1.2", "TASK-2.1", "TASK-3.1", "TASK-4.1", "TASK-6.1", "TASK-7.1", "TASK-8.4"]
  parallel_opportunities: 15
```

---

## 1. Overview

**Feature Summary**: Modernize ReLINE application's LINE Bot implementation from deprecated `line-bot-api` gem to modern `line-bot-sdk` gem (v2.x) while improving code quality, observability, and reliability through modern design patterns.

**Total Tasks**: 38
**Execution Phases**: 8 (Preparation → Utilities → Core Services → Message Handling → Observability → Integration → Testing → Documentation)
**Parallel Opportunities**: 15 tasks can run in parallel across phases

**Critical Path Highlights**:
- Gemfile update → Bundle install (Phase 1)
- Reusable utilities creation (Phase 2)
- Client adapter implementation (Phase 3)
- Event processor service (Phase 4)
- Controller updates (Phase 6)
- Integration testing (Phase 7)

---

## 2. Task Breakdown

### Phase 1: Preparation (45 minutes)

#### TASK-1.1: Update Gemfile and Install Dependencies
**Worker**: backend-worker-v1-self-adapting
**Duration**: 15 minutes
**Dependencies**: None

**Description**: Update Gemfile to replace deprecated `line-bot-api` with modern `line-bot-sdk` and add observability gems.

**Files to Modify**:
- `Gemfile`

**Changes Required**:
```ruby
# Remove:
gem 'line-bot-api'

# Add:
gem 'line-bot-sdk', '~> 2.0'
gem 'prometheus-client', '~> 4.0'
gem 'lograge', '~> 0.14'
gem 'request_store', '~> 1.5' # For correlation IDs
```

**Acceptance Criteria**:
- [ ] `line-bot-api` removed from Gemfile
- [ ] `line-bot-sdk` version 2.x added
- [ ] `prometheus-client` added
- [ ] `lograge` added
- [ ] `request_store` added
- [ ] Gemfile.lock updated with correct versions

**Risks**:
- **Risk**: Version conflicts with existing gems
- **Mitigation**: Test bundle install in clean environment first

---

#### TASK-1.2: Bundle Install and Verify
**Worker**: backend-worker-v1-self-adapting
**Duration**: 10 minutes
**Dependencies**: [TASK-1.1]

**Description**: Run bundle install and verify all dependencies resolve correctly.

**Files to Modify**: None (Gemfile.lock auto-generated)

**Commands**:
```bash
bundle install
bundle list | grep line-bot-sdk
bundle list | grep prometheus
bundle list | grep lograge
```

**Acceptance Criteria**:
- [ ] `bundle install` completes without errors
- [ ] `line-bot-sdk` version 2.x installed
- [ ] All new gems installed successfully
- [ ] No dependency conflicts reported
- [ ] Application starts without gem loading errors

**Risks**:
- **Risk**: Dependency resolution failures
- **Mitigation**: Document exact gem versions in Gemfile

---

#### TASK-1.3: Configure Structured Logging (Lograge)
**Worker**: backend-worker-v1-self-adapting
**Duration**: 15 minutes
**Dependencies**: [TASK-1.2]

**Description**: Configure Lograge for structured JSON logging with correlation IDs.

**Files to Create/Modify**:
- `config/initializers/lograge.rb`
- `config/environments/production.rb`
- `config/environments/development.rb` (optional, for testing)

**Implementation**:
```ruby
# config/initializers/lograge.rb
Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new

  config.lograge.custom_options = lambda do |event|
    {
      correlation_id: RequestStore.store[:correlation_id],
      group_id: event.payload[:group_id],
      event_type: event.payload[:event_type],
      rails_version: Rails.version,
      sdk_version: '2.0.0'
    }
  end
end

# config/environments/production.rb
config.logger = ActiveSupport::Logger.new(
  Rails.root.join('log', 'production.log'),
  10,           # Keep 10 old log files
  100.megabytes # Rotate when file reaches 100MB
)
```

**Acceptance Criteria**:
- [ ] Lograge initializer created
- [ ] JSON formatter configured
- [ ] Custom options include correlation_id, group_id, event_type
- [ ] Log rotation configured (10 files, 100MB each)
- [ ] Logs output in JSON format
- [ ] Test log entry confirms JSON structure

**Risks**:
- **Risk**: Performance overhead from structured logging
- **Mitigation**: Test in development, monitor production metrics

---

#### TASK-1.4: Configure Prometheus Metrics
**Worker**: backend-worker-v1-self-adapting
**Duration**: 15 minutes
**Dependencies**: [TASK-1.2]

**Description**: Set up Prometheus client and define application metrics.

**Files to Create**:
- `config/initializers/prometheus.rb`

**Implementation**:
```ruby
require 'prometheus/client'

prometheus = Prometheus::Client.registry

# Webhook metrics
WEBHOOK_DURATION = prometheus.histogram(
  :webhook_duration_seconds,
  docstring: 'Webhook processing duration in seconds',
  labels: [:event_type],
  buckets: [0.1, 0.5, 1, 2, 3, 5, 8, 10]
)

WEBHOOK_REQUESTS_TOTAL = prometheus.counter(
  :webhook_requests_total,
  docstring: 'Total webhook requests received',
  labels: [:status]
)

EVENT_PROCESSED_TOTAL = prometheus.counter(
  :event_processed_total,
  docstring: 'Total events processed',
  labels: [:event_type, :status]
)

LINE_API_CALLS_TOTAL = prometheus.counter(
  :line_api_calls_total,
  docstring: 'Total LINE API calls',
  labels: [:method, :status]
)

LINE_API_DURATION = prometheus.histogram(
  :line_api_duration_seconds,
  docstring: 'LINE API call duration',
  labels: [:method],
  buckets: [0.1, 0.5, 1, 2, 5]
)

LINE_GROUPS_TOTAL = prometheus.gauge(
  :line_groups_total,
  docstring: 'Total number of LINE groups'
)

MESSAGE_SEND_TOTAL = prometheus.counter(
  :message_send_total,
  docstring: 'Total messages sent',
  labels: [:status]
)
```

**Acceptance Criteria**:
- [ ] Prometheus initializer created
- [ ] All 7 metrics defined (histogram, counter, gauge)
- [ ] Metric labels configured correctly
- [ ] Histogram buckets appropriate for expected values
- [ ] Application starts without Prometheus errors
- [ ] `Prometheus::Client.registry` accessible

**Risks**:
- **Risk**: Metrics overhead impacts performance
- **Mitigation**: Use efficient metric collection, limit cardinality

---

### Phase 2: Reusable Utilities (90 minutes)

#### TASK-2.1: Create Signature Validator Utility
**Worker**: backend-worker-v1-self-adapting
**Duration**: 30 minutes
**Dependencies**: [TASK-1.2]

**Description**: Create reusable HMAC signature validator for webhook security with constant-time comparison.

**Files to Create**:
- `app/services/webhooks/signature_validator.rb`
- `spec/services/webhooks/signature_validator_spec.rb`

**Implementation**:
```ruby
# app/services/webhooks/signature_validator.rb
module Webhooks
  class SignatureValidator
    def initialize(secret)
      @secret = secret
    end

    def valid?(body, signature)
      return false if signature.blank?

      expected = compute_signature(body)
      secure_compare(expected, signature)
    end

    private

    def compute_signature(body)
      Base64.strict_encode64(
        OpenSSL::HMAC.digest(OpenSSL::Digest.new('SHA256'), @secret, body)
      )
    end

    def secure_compare(a, b)
      ActiveSupport::SecurityUtils.secure_compare(a, b)
    end
  end
end
```

**Test Cases**:
- [ ] Validates correct HMAC signature
- [ ] Rejects invalid signature
- [ ] Rejects blank signature
- [ ] Uses constant-time comparison (verify via ActiveSupport::SecurityUtils)

**Acceptance Criteria**:
- [ ] SignatureValidator class created in correct namespace
- [ ] Uses Base64 strict encoding
- [ ] Uses OpenSSL::HMAC with SHA256
- [ ] Uses ActiveSupport::SecurityUtils.secure_compare
- [ ] All RSpec tests pass (≥4 tests)
- [ ] RuboCop violations: 0

**Risks**:
- **Risk**: Timing attack vulnerability if not using secure_compare
- **Mitigation**: Enforce ActiveSupport::SecurityUtils usage, add security test

---

#### TASK-2.2: Create Error Message Sanitizer Utility
**Worker**: backend-worker-v1-self-adapting
**Duration**: 20 minutes
**Dependencies**: [TASK-1.2]

**Description**: Create utility to sanitize sensitive data from error messages and logs.

**Files to Create**:
- `app/services/error_handling/message_sanitizer.rb`
- `spec/services/error_handling/message_sanitizer_spec.rb`

**Implementation**:
```ruby
# app/services/error_handling/message_sanitizer.rb
module ErrorHandling
  class MessageSanitizer
    SENSITIVE_PATTERNS = [
      /channel_(?:id|secret|token)[=:]\s*\S+/i,
      /authorization[=:]\s*\S+/i,
      /bearer\s+\S+/i
    ].freeze

    def sanitize(message)
      sanitized = message.dup
      SENSITIVE_PATTERNS.each do |pattern|
        sanitized.gsub!(pattern, '[REDACTED]')
      end
      sanitized
    end

    def format_error(exception, context, max_backtrace_lines: 5)
      <<~ERROR
        <#{context}>
        Exception: #{exception.class}
        Message: #{sanitize(exception.message)}
        Backtrace (first #{max_backtrace_lines} lines):
        #{exception.backtrace.first(max_backtrace_lines).join("\n")}
      ERROR
    end
  end
end
```

**Test Cases**:
- [ ] Removes channel_secret from error messages
- [ ] Removes authorization tokens
- [ ] Preserves other error content
- [ ] format_error includes exception class, sanitized message, truncated backtrace

**Acceptance Criteria**:
- [ ] MessageSanitizer class created
- [ ] All sensitive patterns defined (≥3 patterns)
- [ ] sanitize method works correctly
- [ ] format_error method truncates backtrace
- [ ] All RSpec tests pass (≥4 tests)
- [ ] RuboCop violations: 0

**Risks**:
- **Risk**: Pattern doesn't catch all credential formats
- **Mitigation**: Comprehensive regex patterns, regular review

---

#### TASK-2.3: Create Member Counter Utility
**Worker**: backend-worker-v1-self-adapting
**Duration**: 25 minutes
**Dependencies**: [TASK-1.2]

**Description**: Extract member counting logic into reusable utility with fallback handling.

**Files to Create**:
- `app/services/line/member_counter.rb`
- `spec/services/line/member_counter_spec.rb`

**Implementation**:
```ruby
# app/services/line/member_counter.rb
module Line
  class MemberCounter
    def initialize(adapter)
      @adapter = adapter
    end

    def count(event)
      return fallback_count unless event.source

      if event.source.group_id
        count_for_group(event.source.group_id)
      elsif event.source.room_id
        count_for_room(event.source.room_id)
      else
        fallback_count
      end
    rescue StandardError => e
      Rails.logger.warn "Failed to get member count: #{e.message}"
      fallback_count
    end

    private

    def count_for_group(group_id)
      @adapter.get_group_member_count(group_id)
    end

    def count_for_room(room_id)
      @adapter.get_room_member_count(room_id)
    end

    def fallback_count
      2
    end
  end
end
```

**Test Cases**:
- [ ] Queries group member count via adapter
- [ ] Queries room member count via adapter
- [ ] Returns fallback (2) when no source
- [ ] Returns fallback on API failure
- [ ] Logs warning on API failure

**Acceptance Criteria**:
- [ ] MemberCounter class created
- [ ] Accepts adapter in initializer
- [ ] Handles group_id and room_id
- [ ] Returns fallback value (2) on error
- [ ] Logs warnings for failures
- [ ] All RSpec tests pass (≥5 tests)
- [ ] RuboCop violations: 0

**Risks**:
- **Risk**: Fallback value (2) may be incorrect for some scenarios
- **Mitigation**: Document assumption, consider making fallback configurable

---

#### TASK-2.4: Create Retry Handler Utility
**Worker**: backend-worker-v1-self-adapting
**Duration**: 30 minutes
**Dependencies**: [TASK-1.2]

**Description**: Implement resilience utility with exponential backoff for transient failures.

**Files to Create**:
- `app/services/resilience/retry_handler.rb`
- `spec/services/resilience/retry_handler_spec.rb`

**Implementation**:
```ruby
# app/services/resilience/retry_handler.rb
module Resilience
  class RetryHandler
    DEFAULT_RETRYABLE_ERRORS = [
      Net::OpenTimeout,
      Net::ReadTimeout,
      Errno::ECONNREFUSED
    ].freeze

    def initialize(max_attempts: 3, backoff_factor: 2, retryable_errors: DEFAULT_RETRYABLE_ERRORS)
      @max_attempts = max_attempts
      @backoff_factor = backoff_factor
      @retryable_errors = retryable_errors
    end

    def call
      attempts = 0

      begin
        attempts += 1
        yield
      rescue => e
        if attempts < @max_attempts && retryable?(e)
          sleep(@backoff_factor ** attempts)
          retry
        else
          raise
        end
      end
    end

    private

    def retryable?(error)
      @retryable_errors.any? { |klass| error.is_a?(klass) } ||
        (error.respond_to?(:response) && error.response&.code == '500')
    end
  end
end
```

**Test Cases**:
- [ ] Retries transient errors (Net::OpenTimeout)
- [ ] Applies exponential backoff (2^attempts seconds)
- [ ] Stops after max attempts (3)
- [ ] Does not retry non-retryable errors
- [ ] Retries LINE API 500 errors
- [ ] Re-raises error after max attempts

**Acceptance Criteria**:
- [ ] RetryHandler class created
- [ ] Supports configurable max_attempts and backoff_factor
- [ ] Implements exponential backoff correctly
- [ ] Handles DEFAULT_RETRYABLE_ERRORS
- [ ] Detects HTTP 500 responses
- [ ] All RSpec tests pass (≥6 tests)
- [ ] RuboCop violations: 0

**Risks**:
- **Risk**: Exponential backoff may delay too long
- **Mitigation**: Configurable backoff_factor, test with realistic values

---

#### TASK-2.5: Create Metrics Collection Module
**Worker**: backend-worker-v1-self-adapting
**Duration**: 15 minutes
**Dependencies**: [TASK-1.4]

**Description**: Create helper module for easy metrics collection throughout application.

**Files to Create**:
- `app/services/prometheus_metrics.rb`
- `spec/services/prometheus_metrics_spec.rb`

**Implementation**:
```ruby
# app/services/prometheus_metrics.rb
module PrometheusMetrics
  class << self
    def track_webhook_duration(event_type, duration)
      WEBHOOK_DURATION.observe({ event_type: event_type }, duration)
    end

    def track_webhook_request(status)
      WEBHOOK_REQUESTS_TOTAL.increment(labels: { status: status })
    end

    def track_event_success(event)
      EVENT_PROCESSED_TOTAL.increment(
        labels: { event_type: event.class.name, status: 'success' }
      )
    end

    def track_event_failure(event, exception)
      EVENT_PROCESSED_TOTAL.increment(
        labels: { event_type: event.class.name, status: 'error' }
      )
    end

    def track_line_api_call(method, status, duration)
      LINE_API_CALLS_TOTAL.increment(labels: { method: method, status: status })
      LINE_API_DURATION.observe({ method: method }, duration)
    end

    def track_message_send(status)
      MESSAGE_SEND_TOTAL.increment(labels: { status: status })
    end

    def update_group_count(count)
      LINE_GROUPS_TOTAL.set({}, count)
    end
  end
end
```

**Test Cases**:
- [ ] track_webhook_duration records histogram value
- [ ] track_event_success increments counter
- [ ] track_event_failure increments counter with error status
- [ ] track_line_api_call records both counter and histogram

**Acceptance Criteria**:
- [ ] PrometheusMetrics module created
- [ ] All tracking methods defined (≥7 methods)
- [ ] Methods delegate to global Prometheus constants
- [ ] All RSpec tests pass (≥4 tests)
- [ ] RuboCop violations: 0

**Risks**: None (low-risk utility)

---

### Phase 3: Core Client Adapter (60 minutes)

#### TASK-3.1: Create Client Adapter Interface
**Worker**: backend-worker-v1-self-adapting
**Duration**: 20 minutes
**Dependencies**: [TASK-1.2]

**Description**: Define abstract interface for LINE SDK operations to enable future SDK upgrades.

**Files to Create**:
- `app/services/line/client_adapter.rb`

**Implementation**:
```ruby
# app/services/line/client_adapter.rb
module Line
  class ClientAdapter
    # Abstract interface for LINE client operations
    def validate_signature(body, signature)
      raise NotImplementedError, "#{self.class} must implement #validate_signature"
    end

    def parse_events(body)
      raise NotImplementedError, "#{self.class} must implement #parse_events"
    end

    def push_message(target, message)
      raise NotImplementedError, "#{self.class} must implement #push_message"
    end

    def reply_message(reply_token, message)
      raise NotImplementedError, "#{self.class} must implement #reply_message"
    end

    def get_group_member_count(group_id)
      raise NotImplementedError, "#{self.class} must implement #get_group_member_count"
    end

    def get_room_member_count(room_id)
      raise NotImplementedError, "#{self.class} must implement #get_room_member_count"
    end

    def leave_group(group_id)
      raise NotImplementedError, "#{self.class} must implement #leave_group"
    end

    def leave_room(room_id)
      raise NotImplementedError, "#{self.class} must implement #leave_room"
    end
  end
end
```

**Acceptance Criteria**:
- [ ] ClientAdapter class created with 8 abstract methods
- [ ] All methods raise NotImplementedError
- [ ] Documentation comments added
- [ ] RuboCop violations: 0

**Risks**: None (interface definition)

---

#### TASK-3.2: Implement SdkV2Adapter
**Worker**: backend-worker-v1-self-adapting
**Duration**: 35 minutes
**Dependencies**: [TASK-3.1]

**Description**: Implement concrete adapter for line-bot-sdk v2.x.

**Files to Modify**:
- `app/services/line/client_adapter.rb`
- `spec/services/line/client_adapter_spec.rb`

**Implementation**:
```ruby
# Add to app/services/line/client_adapter.rb
module Line
  class SdkV2Adapter < ClientAdapter
    def initialize(credentials)
      @client = Line::Bot::Client.new do |config|
        config.channel_id = credentials[:channel_id]
        config.channel_secret = credentials[:channel_secret]
        config.channel_token = credentials[:channel_token]
      end

      validate_credentials(credentials)
    end

    def validate_signature(body, signature)
      @client.validate_signature(body, signature)
    end

    def parse_events(body)
      @client.parse_events_from(body)
    end

    def push_message(target, message)
      start_time = Time.current
      response = @client.push_message(target, message)
      duration = Time.current - start_time

      PrometheusMetrics.track_line_api_call('push_message', response.code, duration)
      response
    end

    def reply_message(reply_token, message)
      start_time = Time.current
      response = @client.reply_message(reply_token, message)
      duration = Time.current - start_time

      PrometheusMetrics.track_line_api_call('reply_message', response.code, duration)
      response
    end

    def get_group_member_count(group_id)
      start_time = Time.current
      response = @client.get_group_members_count(group_id)
      duration = Time.current - start_time

      PrometheusMetrics.track_line_api_call('get_group_members_count', '200', duration)
      response['count'].to_i
    end

    def get_room_member_count(room_id)
      start_time = Time.current
      response = @client.get_room_members_count(room_id)
      duration = Time.current - start_time

      PrometheusMetrics.track_line_api_call('get_room_members_count', '200', duration)
      response['count'].to_i
    end

    def leave_group(group_id)
      @client.leave_group(group_id)
    end

    def leave_room(room_id)
      @client.leave_room(room_id)
    end

    private

    def validate_credentials(credentials)
      required = [:channel_id, :channel_secret, :channel_token]
      missing = required.select { |key| credentials[key].blank? }

      raise ArgumentError, "Missing LINE credentials: #{missing.join(', ')}" if missing.any?
    end
  end
end
```

**Test Cases**:
- [ ] Initializes Line::Bot::Client with credentials
- [ ] Validates missing credentials raise ArgumentError
- [ ] validate_signature delegates to SDK client
- [ ] parse_events delegates to SDK client
- [ ] push_message tracks metrics
- [ ] get_group_member_count returns integer
- [ ] get_room_member_count returns integer

**Acceptance Criteria**:
- [ ] SdkV2Adapter class inherits from ClientAdapter
- [ ] All 8 interface methods implemented
- [ ] Metrics tracking added for API calls
- [ ] Credential validation in initializer
- [ ] All RSpec tests pass (≥7 tests)
- [ ] RuboCop violations: 0

**Risks**:
- **Risk**: LINE SDK API changes in future versions
- **Mitigation**: Adapter pattern allows easy replacement

---

#### TASK-3.3: Create Client Provider
**Worker**: backend-worker-v1-self-adapting
**Duration**: 15 minutes
**Dependencies**: [TASK-3.2]

**Description**: Create singleton provider for client adapter instance.

**Files to Create**:
- `app/services/line/client_provider.rb`
- `spec/services/line/client_provider_spec.rb`

**Implementation**:
```ruby
# app/services/line/client_provider.rb
module Line
  class ClientProvider
    class << self
      def client
        @client ||= SdkV2Adapter.new(
          channel_id: Rails.application.credentials.channel_id,
          channel_secret: Rails.application.credentials.channel_secret,
          channel_token: Rails.application.credentials.channel_token
        )
      end

      def reset!
        @client = nil
      end
    end
  end
end
```

**Test Cases**:
- [ ] Returns SdkV2Adapter instance
- [ ] Memoizes client (same instance on multiple calls)
- [ ] reset! clears memoized client
- [ ] Loads credentials from Rails.application.credentials

**Acceptance Criteria**:
- [ ] ClientProvider module created
- [ ] client method with memoization
- [ ] reset! method for testing
- [ ] Loads credentials securely
- [ ] All RSpec tests pass (≥4 tests)
- [ ] RuboCop violations: 0

**Risks**: None (simple singleton)

---

### Phase 4: Event Processing Service (75 minutes)

#### TASK-4.1: Create Event Processor Service
**Worker**: backend-worker-v1-self-adapting
**Duration**: 35 minutes
**Dependencies**: [TASK-2.3, TASK-3.3]

**Description**: Implement core event processing orchestration with timeout, transactions, and idempotency.

**Files to Create**:
- `app/services/line/event_processor.rb`
- `spec/services/line/event_processor_spec.rb`

**Implementation**:
```ruby
# app/services/line/event_processor.rb
module Line
  class EventProcessor
    PROCESSING_TIMEOUT = 8 # seconds

    def initialize(adapter:, member_counter:)
      @adapter = adapter
      @member_counter = member_counter
      @processed_events = Set.new
    end

    def process(events)
      Timeout.timeout(PROCESSING_TIMEOUT) do
        events.each do |event|
          process_single_event(event)
        rescue StandardError => e
          handle_error(e, event)
        end
      end
    rescue Timeout::Error
      Rails.logger.error "Webhook processing timeout after #{PROCESSING_TIMEOUT}s"
      raise
    end

    private

    def process_single_event(event)
      return if already_processed?(event)

      start_time = Time.current

      ActiveRecord::Base.transaction do
        group_id = extract_group_id(event)
        member_count = @member_counter.count(event)

        # Process event by type
        case event
        when Line::Bot::Event::Message
          process_message_event(event, group_id, member_count)
        when Line::Bot::Event::Join, Line::Bot::Event::MemberJoined
          process_join_event(event, group_id, member_count)
        when Line::Bot::Event::Leave, Line::Bot::Event::MemberLeft
          process_leave_event(event, group_id, member_count)
        end

        mark_processed(event)
      end

      duration = Time.current - start_time
      PrometheusMetrics.track_webhook_duration(event.class.name, duration)
      PrometheusMetrics.track_event_success(event)
    end

    def extract_group_id(event)
      event.source&.group_id || event.source&.room_id
    end

    def already_processed?(event)
      event_id = generate_event_id(event)
      return true if @processed_events.include?(event_id)

      @processed_events.add(event_id)

      # Memory management: limit set size
      @processed_events.delete(@processed_events.first) if @processed_events.size > 10000

      false
    end

    def generate_event_id(event)
      "#{event.timestamp}-#{event.source&.group_id}-#{event.message&.id}"
    end

    def mark_processed(event)
      # Already in memory set
    end

    def handle_error(exception, event)
      sanitizer = ErrorHandling::MessageSanitizer.new
      error_message = sanitizer.format_error(exception, 'Event Processing')

      Rails.logger.error(error_message)

      group_id = extract_group_id(event)
      LineMailer.error_email(group_id, error_message).deliver_later

      PrometheusMetrics.track_event_failure(event, exception)
    end

    # Placeholder methods - will be extracted to handlers
    def process_message_event(event, group_id, member_count)
      # Will be implemented in Phase 5
    end

    def process_join_event(event, group_id, member_count)
      # Will be implemented in Phase 5
    end

    def process_leave_event(event, group_id, member_count)
      # Will be implemented in Phase 5
    end
  end
end
```

**Test Cases**:
- [ ] Processes all events in array
- [ ] Handles errors per event without stopping batch
- [ ] Prevents duplicate processing (idempotency)
- [ ] Enforces 8-second timeout
- [ ] Wraps operations in transaction
- [ ] Tracks metrics for success/failure
- [ ] Sends error email on failure
- [ ] Manages processed_events set size (max 10000)

**Acceptance Criteria**:
- [ ] EventProcessor class created
- [ ] Timeout protection implemented (8 seconds)
- [ ] Transaction management per event
- [ ] Idempotency tracking with Set
- [ ] Memory management for processed_events
- [ ] Error handling with sanitizer
- [ ] Metrics tracking integrated
- [ ] All RSpec tests pass (≥8 tests)
- [ ] RuboCop violations: 0

**Risks**:
- **Risk**: 8-second timeout may be too short for complex events
- **Mitigation**: Monitor timeout metrics, adjust if needed

---

#### TASK-4.2: Create Group Service
**Worker**: backend-worker-v1-self-adapting
**Duration**: 30 minutes
**Dependencies**: [TASK-1.2]

**Description**: Extract group lifecycle business logic into dedicated service.

**Files to Create**:
- `app/services/line/group_service.rb`
- `spec/services/line/group_service_spec.rb`

**Implementation**:
```ruby
# app/services/line/group_service.rb
module Line
  class GroupService
    def initialize(adapter)
      @adapter = adapter
    end

    def find_or_create(group_id, member_count)
      return nil if group_id.blank? || member_count < 2

      existing_group = LineGroup.find_by(line_group_id: group_id)
      return existing_group if existing_group

      create_group(group_id, member_count)
    end

    def update_record(group_id, member_count)
      return if member_count < 2

      line_group = LineGroup.find_by(line_group_id: group_id)
      return unless line_group

      line_group.update!(
        member_count: member_count,
        post_count: line_group.post_count + 1
      )
    end

    def delete_if_empty(group_id, member_count)
      return if member_count > 1

      line_group = LineGroup.find_by(line_group_id: group_id)
      line_group&.destroy!
    end

    def send_welcome_message(group_id, message_type: :join)
      message = case message_type
                when :join
                  { type: 'text',
                    text: '加えてくれてありがとうニャ🌟！！最後のLINEから3週間〜2ヶ月後にwake upのLINEするニャ！！（反応が無いとすぐかも知れニャンよ⏰）末永くよろしくニャ🐱🐾' }
                when :member_joined
                  { type: 'text',
                    text: '初めまして🌟ReLINE(https://www.cat-reline.com/)の"猫さん"っていうニャ🐱よろしくニャ🐾！！' }
                end

      @adapter.push_message(group_id, message)
    end

    private

    def create_group(group_id, member_count)
      LineGroup.create!(
        line_group_id: group_id,
        remind_at: Date.current.tomorrow,
        status: :wait,
        member_count: member_count
      )
    end
  end
end
```

**Test Cases**:
- [ ] find_or_create creates group when member_count >= 2
- [ ] find_or_create skips creation for 1-on-1 chats (member_count < 2)
- [ ] find_or_create returns existing group
- [ ] update_record increments post_count
- [ ] delete_if_empty deletes when member_count <= 1
- [ ] send_welcome_message sends correct message for :join
- [ ] send_welcome_message sends correct message for :member_joined

**Acceptance Criteria**:
- [ ] GroupService class created
- [ ] find_or_create method with member_count check
- [ ] update_record method increments post_count
- [ ] delete_if_empty method with guard clause
- [ ] send_welcome_message supports :join and :member_joined
- [ ] All RSpec tests pass (≥7 tests)
- [ ] RuboCop violations: 0

**Risks**: None (extracted from existing logic)

---

#### TASK-4.3: Create Command Handler Service
**Worker**: backend-worker-v1-self-adapting
**Duration**: 20 minutes
**Dependencies**: [TASK-1.2]

**Description**: Extract command processing logic for span settings and bot removal.

**Files to Create**:
- `app/services/line/command_handler.rb`
- `spec/services/line/command_handler_spec.rb`

**Implementation**:
```ruby
# app/services/line/command_handler.rb
module Line
  class CommandHandler
    REMOVAL_COMMAND = 'Cat sleeping on our Memory.'
    SPAN_FASTER = 'Would you set to faster.'
    SPAN_LATTER = 'Would you set to latter.'
    SPAN_DEFAULT = 'Would you set to default.'

    def initialize(adapter)
      @adapter = adapter
    end

    def handle_removal(event, group_id)
      return unless event.message&.text == REMOVAL_COMMAND

      if event.source&.group_id
        @adapter.leave_group(group_id)
      elsif event.source&.room_id
        @adapter.leave_room(group_id)
      end
    end

    def handle_span_setting(event, group_id)
      text = event.message&.text
      return unless span_command?(text)

      line_group = LineGroup.find_by(line_group_id: group_id)
      return unless line_group

      case text
      when SPAN_FASTER
        line_group.faster!
      when SPAN_LATTER
        line_group.latter!
      when SPAN_DEFAULT
        line_group.random!
      end

      send_confirmation(group_id)
    end

    def span_command?(text)
      text.in?([SPAN_FASTER, SPAN_LATTER, SPAN_DEFAULT])
    end

    private

    def send_confirmation(group_id)
      message = { type: 'text', text: '了解ニャ！次の投稿から設定を適応するニャ🐾！！' }
      @adapter.push_message(group_id, message)
    end
  end
end
```

**Test Cases**:
- [ ] handle_removal leaves group when command matches
- [ ] handle_removal leaves room when command matches
- [ ] handle_span_setting updates to faster
- [ ] handle_span_setting updates to latter
- [ ] handle_span_setting updates to default (random)
- [ ] send_confirmation sends correct message
- [ ] span_command? returns true for valid commands

**Acceptance Criteria**:
- [ ] CommandHandler class created
- [ ] Constants defined for all commands
- [ ] handle_removal method with group/room detection
- [ ] handle_span_setting updates LineGroup enum
- [ ] send_confirmation method
- [ ] All RSpec tests pass (≥7 tests)
- [ ] RuboCop violations: 0

**Risks**: None (extracted from existing logic)

---

### Phase 5: Message Handling (40 minutes)

#### TASK-5.1: Create One-on-One Message Handler
**Worker**: backend-worker-v1-self-adapting
**Duration**: 20 minutes
**Dependencies**: [TASK-3.3]

**Description**: Handle direct messages (non-group context) with usage instructions.

**Files to Create**:
- `app/services/line/one_on_one_handler.rb`
- `spec/services/line/one_on_one_handler_spec.rb`

**Implementation**:
```ruby
# app/services/line/one_on_one_handler.rb
module Line
  class OneOnOneHandler
    HOW_TO_USE = 'https://www.cat-reline.com/'

    def initialize(adapter)
      @adapter = adapter
    end

    def handle(event)
      message = build_message(event)
      @adapter.reply_message(event.reply_token, message)
    end

    private

    def build_message(event)
      case event.type
      when Line::Bot::Event::MessageType::Text
        { type: 'text', text: "【ReLINE】の使い方はこちらで確認してほしいにゃ！🐱🐾#{HOW_TO_USE}" }
      when Line::Bot::Event::MessageType::Sticker
        { type: 'text', text: "スタンプありがとうニャ！✨\nお礼にこちらをお送りするニャ🐾🐾\n#{Content.free.sample.body}" }
      else
        { type: 'text', text: 'ごめんニャ😿分からないニャ。。。' }
      end
    end
  end
end
```

**Test Cases**:
- [ ] Text message returns usage instructions
- [ ] Sticker message returns sample content
- [ ] Unknown message type returns default response
- [ ] Uses reply_message (not push_message)

**Acceptance Criteria**:
- [ ] OneOnOneHandler class created
- [ ] build_message handles text, sticker, unknown types
- [ ] Uses adapter.reply_message
- [ ] All RSpec tests pass (≥4 tests)
- [ ] RuboCop violations: 0

**Risks**: None (extracted from existing logic)

---

#### TASK-5.2: Integrate Handlers into Event Processor
**Worker**: backend-worker-v1-self-adapting
**Duration**: 30 minutes
**Dependencies**: [TASK-4.1, TASK-4.2, TASK-4.3, TASK-5.1]

**Description**: Complete event processor by integrating all handler services.

**Files to Modify**:
- `app/services/line/event_processor.rb`
- `spec/services/line/event_processor_spec.rb`

**Changes Required**:
Replace placeholder methods in EventProcessor with actual implementations:

```ruby
def initialize(adapter:, member_counter:, group_service:, command_handler:, one_on_one_handler:)
  @adapter = adapter
  @member_counter = member_counter
  @group_service = group_service
  @command_handler = command_handler
  @one_on_one_handler = one_on_one_handler
  @processed_events = Set.new
end

def process_message_event(event, group_id, member_count)
  # Handle 1-on-1 messages
  if group_id.blank?
    @one_on_one_handler.handle(event)
    return
  end

  # Handle commands
  @command_handler.handle_removal(event, group_id)
  @command_handler.handle_span_setting(event, group_id)

  # Update group record
  @group_service.update_record(group_id, member_count)
end

def process_join_event(event, group_id, member_count)
  @group_service.find_or_create(group_id, member_count)

  message_type = event.is_a?(Line::Bot::Event::Join) ? :join : :member_joined
  @group_service.send_welcome_message(group_id, message_type: message_type)
end

def process_leave_event(event, group_id, member_count)
  @group_service.delete_if_empty(group_id, member_count)
end
```

**Acceptance Criteria**:
- [ ] EventProcessor initializer accepts all dependencies
- [ ] process_message_event delegates to handlers
- [ ] process_join_event creates group and sends welcome
- [ ] process_leave_event deletes empty groups
- [ ] All integration tests pass
- [ ] RuboCop violations: 0

**Risks**: None (integration of tested components)

---

### Phase 6: Controller & Scheduler Updates (60 minutes)

#### TASK-6.1: Update Webhooks Controller
**Worker**: backend-worker-v1-self-adapting
**Duration**: 30 minutes
**Dependencies**: [TASK-2.1, TASK-4.1]

**Description**: Refactor controller to use SignatureValidator and EventProcessor.

**Files to Modify**:
- `app/controllers/operator/webhooks_controller.rb`
- `spec/controllers/operator/webhooks_controller_spec.rb`

**Implementation**:
```ruby
# app/controllers/operator/webhooks_controller.rb
class Operator::WebhooksController < Operator::BaseController
  skip_before_action :require_login, only: %i[callback]
  protect_from_forgery except: :callback

  def callback
    body = request.body.read
    signature = request.env['HTTP_X_LINE_SIGNATURE']

    # Validate signature
    validator = Webhooks::SignatureValidator.new(Rails.application.credentials.channel_secret)
    return head :bad_request if signature.blank? || !validator.valid?(body, signature)

    # Parse events
    adapter = Line::ClientProvider.client
    events = adapter.parse_events(body)

    # Process events
    processor = build_event_processor(adapter)
    processor.process(events)

    PrometheusMetrics.track_webhook_request('success')
    head :ok
  rescue Timeout::Error
    PrometheusMetrics.track_webhook_request('timeout')
    head :service_unavailable
  rescue StandardError => e
    Rails.logger.error "Webhook processing failed: #{e.message}"
    PrometheusMetrics.track_webhook_request('error')
    head :service_unavailable
  end

  private

  def build_event_processor(adapter)
    member_counter = Line::MemberCounter.new(adapter)
    group_service = Line::GroupService.new(adapter)
    command_handler = Line::CommandHandler.new(adapter)
    one_on_one_handler = Line::OneOnOneHandler.new(adapter)

    Line::EventProcessor.new(
      adapter: adapter,
      member_counter: member_counter,
      group_service: group_service,
      command_handler: command_handler,
      one_on_one_handler: one_on_one_handler
    )
  end
end
```

**Test Cases**:
- [ ] Returns 200 OK on successful processing
- [ ] Returns 400 Bad Request on invalid signature
- [ ] Returns 400 Bad Request on blank signature
- [ ] Returns 503 Service Unavailable on timeout
- [ ] Returns 503 Service Unavailable on other errors
- [ ] Tracks webhook request metrics
- [ ] Uses SignatureValidator utility

**Acceptance Criteria**:
- [ ] Controller uses SignatureValidator
- [ ] Controller builds EventProcessor with all dependencies
- [ ] Returns appropriate HTTP status codes
- [ ] Tracks metrics for all outcomes
- [ ] All RSpec tests pass (≥7 tests)
- [ ] RuboCop violations: 0

**Risks**:
- **Risk**: Dependency injection may be verbose
- **Mitigation**: Consider extracting to factory class if needed

---

#### TASK-6.2: Add Health Check Endpoints
**Worker**: backend-worker-v1-self-adapting
**Duration**: 25 minutes
**Dependencies**: [TASK-1.2]

**Description**: Implement shallow and deep health check endpoints.

**Files to Create**:
- `app/controllers/health_controller.rb`
- `config/routes.rb` (modify)
- `spec/controllers/health_controller_spec.rb`

**Implementation**:
```ruby
# app/controllers/health_controller.rb
class HealthController < ApplicationController
  skip_before_action :verify_authenticity_token

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
      line_credentials: check_line_credentials
    }

    all_healthy = checks.values.all? { |c| c[:status] == 'healthy' }
    status_code = all_healthy ? :ok : :service_unavailable

    render json: {
      status: all_healthy ? 'healthy' : 'unhealthy',
      checks: checks,
      timestamp: Time.current.iso8601
    }, status: status_code
  end

  private

  def check_database
    start_time = Time.current
    ActiveRecord::Base.connection.execute('SELECT 1')
    latency_ms = ((Time.current - start_time) * 1000).round(2)

    { status: 'healthy', latency_ms: latency_ms }
  rescue StandardError => e
    { status: 'unhealthy', error: e.message }
  end

  def check_line_credentials
    required = [:channel_id, :channel_secret, :channel_token]
    present = required.all? { |key| Rails.application.credentials.send(key).present? }

    if present
      { status: 'healthy' }
    else
      { status: 'unhealthy', error: 'Missing LINE credentials' }
    end
  rescue StandardError => e
    { status: 'unhealthy', error: e.message }
  end
end

# config/routes.rb
get '/health', to: 'health#check'
get '/health/deep', to: 'health#deep'
```

**Test Cases**:
- [ ] GET /health returns 200 OK with version
- [ ] GET /health/deep returns 200 OK when all checks pass
- [ ] GET /health/deep returns 503 when database fails
- [ ] GET /health/deep returns 503 when credentials missing
- [ ] Database check includes latency_ms

**Acceptance Criteria**:
- [ ] HealthController created
- [ ] Shallow check endpoint (/health)
- [ ] Deep check endpoint (/health/deep)
- [ ] Database connectivity check
- [ ] LINE credentials check
- [ ] Routes configured
- [ ] All RSpec tests pass (≥5 tests)
- [ ] RuboCop violations: 0

**Risks**: None (standard health checks)

---

#### TASK-6.3: Add Metrics Endpoint
**Worker**: backend-worker-v1-self-adapting
**Duration**: 15 minutes
**Dependencies**: [TASK-1.4]

**Description**: Create endpoint to expose Prometheus metrics.

**Files to Create**:
- `app/controllers/metrics_controller.rb`
- `config/routes.rb` (modify)
- `spec/controllers/metrics_controller_spec.rb`

**Implementation**:
```ruby
# app/controllers/metrics_controller.rb
class MetricsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def index
    # Update gauge metrics before exporting
    PrometheusMetrics.update_group_count(LineGroup.count)

    render plain: Prometheus::Client::Formats::Text.marshal(Prometheus::Client.registry),
           content_type: 'text/plain; version=0.0.4'
  end
end

# config/routes.rb
get '/metrics', to: 'metrics#index'
```

**Test Cases**:
- [ ] GET /metrics returns 200 OK
- [ ] Content-Type is text/plain
- [ ] Response includes prometheus format
- [ ] Updates group count gauge before export

**Acceptance Criteria**:
- [ ] MetricsController created
- [ ] Exports Prometheus::Client.registry
- [ ] Updates gauge metrics before export
- [ ] Route configured
- [ ] All RSpec tests pass (≥4 tests)
- [ ] RuboCop violations: 0

**Risks**: None (standard Prometheus endpoint)

---

#### TASK-6.4: Add Correlation ID Middleware
**Worker**: backend-worker-v1-self-adapting
**Duration**: 15 minutes
**Dependencies**: [TASK-1.3]

**Description**: Add correlation ID tracking for distributed tracing.

**Files to Modify**:
- `app/controllers/application_controller.rb`
- `spec/controllers/application_controller_spec.rb`

**Implementation**:
```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  around_action :set_correlation_id

  private

  def set_correlation_id
    correlation_id = request.headers['X-Request-ID'] || SecureRandom.uuid
    RequestStore.store[:correlation_id] = correlation_id
    response.set_header('X-Request-ID', correlation_id)

    yield
  ensure
    RequestStore.store[:correlation_id] = nil
  end
end
```

**Test Cases**:
- [ ] Sets correlation_id from X-Request-ID header
- [ ] Generates correlation_id when header missing
- [ ] Stores correlation_id in RequestStore
- [ ] Sets X-Request-ID response header
- [ ] Clears RequestStore after request

**Acceptance Criteria**:
- [ ] around_action added to ApplicationController
- [ ] Uses RequestStore for correlation_id
- [ ] Returns correlation_id in response header
- [ ] All RSpec tests pass (≥5 tests)
- [ ] RuboCop violations: 0

**Risks**: None (standard middleware)

---

#### TASK-6.5: Update Scheduler to Use Adapter
**Worker**: backend-worker-v1-self-adapting
**Duration**: 35 minutes
**Dependencies**: [TASK-2.4, TASK-3.3]

**Description**: Refactor Scheduler to use ClientAdapter and RetryHandler.

**Files to Modify**:
- `app/models/scheduler.rb`
- `spec/models/scheduler_spec.rb`

**Implementation**:
```ruby
# app/models/scheduler.rb
class Scheduler
  include ActiveModel::Model

  class << self
    def call_notice
      remind_groups = LineGroup.remind_call
      messages = call_messages
      adapter = Line::ClientProvider.client

      scheduler(remind_groups, messages, adapter)
    end

    def wait_notice
      remind_groups = LineGroup.remind_wait
      messages = wait_messages
      adapter = Line::ClientProvider.client

      scheduler(remind_groups, messages, adapter)
    end

    def call_messages
      [{ type: 'text', text: AlarmContent.contact.sample.body },
       { type: 'text', text: AlarmContent.text.sample.body }]
    end

    def wait_messages
      [{ type: 'text', text: Content.contact.sample.body },
       { type: 'text', text: Content.free.sample.body },
       { type: 'text', text: Content.text.sample.body }]
    end

    def scheduler(remind_groups, messages, adapter)
      retry_handler = Resilience::RetryHandler.new(max_attempts: 3)

      remind_groups.find_each do |group|
        ActiveRecord::Base.transaction do
          messages.each_with_index do |message, index|
            retry_handler.call do
              response = adapter.push_message(group.line_group_id, message)
              raise "Message #{index + 1} failed: #{message}" if response.code == '400'

              PrometheusMetrics.track_message_send('success')
            end
          end

          group.remind_at = Date.current.since((1..3).to_a.sample.days)
          group.call!
        end
      rescue StandardError => e
        report_scheduler_errors(e, group)
        PrometheusMetrics.track_message_send('error')
      end
    end

    def report_scheduler_errors(exception, group)
      sanitizer = ErrorHandling::MessageSanitizer.new
      error_message = sanitizer.format_error(exception, 'Scheduler')
      LineMailer.error_email(group.line_group_id, error_message).deliver_later
    end
  end
end
```

**Test Cases**:
- [ ] Uses Line::ClientProvider.client
- [ ] Uses RetryHandler for message sending
- [ ] Wraps operations in transaction
- [ ] Updates remind_at and status on success
- [ ] Tracks metrics for success/error
- [ ] Uses MessageSanitizer for errors
- [ ] Sends error email on failure

**Acceptance Criteria**:
- [ ] Scheduler uses ClientAdapter
- [ ] RetryHandler integrated
- [ ] Transaction management added
- [ ] MessageSanitizer used for errors
- [ ] Metrics tracking added
- [ ] All RSpec tests pass
- [ ] RuboCop violations: 0

**Risks**:
- **Risk**: Retry logic may delay scheduled messages
- **Mitigation**: Monitor retry metrics, adjust max_attempts if needed

---

### Phase 7: Testing (120 minutes)

#### TASK-7.1: Create Test Helpers and Fixtures
**Worker**: test-worker-v1-self-adapting
**Duration**: 20 minutes
**Dependencies**: [TASK-3.3]

**Description**: Create reusable test helpers and mock LINE webhook payloads.

**Files to Create**:
- `spec/support/line_webhook_helpers.rb`
- `spec/support/line_client_stub.rb`
- `spec/fixtures/line_webhooks.yml`

**Implementation**:
```ruby
# spec/support/line_webhook_helpers.rb
module LineWebhookHelpers
  def valid_signature(body, secret)
    Base64.strict_encode64(
      OpenSSL::HMAC.digest(OpenSSL::Digest.new('SHA256'), secret, body)
    )
  end

  def mock_line_message_event(text: 'Hello', group_id: 'GROUP123')
    double(
      'Line::Bot::Event::Message',
      class: Line::Bot::Event::Message,
      type: Line::Bot::Event::MessageType::Text,
      timestamp: Time.current.to_i * 1000,
      source: double(group_id: group_id, room_id: nil),
      message: double(id: 'MSG123', text: text),
      reply_token: 'REPLY123'
    )
  end

  def mock_line_join_event(group_id: 'GROUP123')
    double(
      'Line::Bot::Event::Join',
      class: Line::Bot::Event::Join,
      timestamp: Time.current.to_i * 1000,
      source: double(group_id: group_id, room_id: nil),
      reply_token: 'REPLY123'
    )
  end
end

# spec/support/line_client_stub.rb
class LineClientStub
  attr_reader :sent_messages, :left_groups

  def initialize
    @sent_messages = []
    @left_groups = []
  end

  def push_message(target, message)
    @sent_messages << { target: target, message: message }
    double(code: '200')
  end

  def reply_message(reply_token, message)
    @sent_messages << { reply_token: reply_token, message: message }
    double(code: '200')
  end

  def get_group_member_count(group_id)
    5
  end

  def leave_group(group_id)
    @left_groups << group_id
  end
end

RSpec.configure do |config|
  config.include LineWebhookHelpers
end
```

**Acceptance Criteria**:
- [ ] LineWebhookHelpers module created
- [ ] valid_signature helper
- [ ] mock_line_message_event helper
- [ ] mock_line_join_event helper
- [ ] LineClientStub class for testing
- [ ] Helpers included in RSpec config

**Risks**: None (test utilities)

---

#### TASK-7.2: Unit Tests - Utilities
**Worker**: test-worker-v1-self-adapting
**Duration**: 30 minutes
**Dependencies**: [TASK-2.1, TASK-2.2, TASK-2.3, TASK-2.4, TASK-7.1]

**Description**: Write comprehensive unit tests for all utility classes.

**Files Created in Previous Tasks**:
- `spec/services/webhooks/signature_validator_spec.rb`
- `spec/services/error_handling/message_sanitizer_spec.rb`
- `spec/services/line/member_counter_spec.rb`
- `spec/services/resilience/retry_handler_spec.rb`

**Test Coverage Goals**:
- SignatureValidator: ≥95% coverage, ≥4 tests
- MessageSanitizer: ≥95% coverage, ≥4 tests
- MemberCounter: ≥95% coverage, ≥5 tests
- RetryHandler: ≥95% coverage, ≥6 tests

**Acceptance Criteria**:
- [ ] All utility specs pass
- [ ] Code coverage ≥95% for each utility
- [ ] Edge cases tested (nil, blank, errors)
- [ ] RuboCop violations: 0

**Risks**: None (already created with classes)

---

#### TASK-7.3: Unit Tests - Services
**Worker**: test-worker-v1-self-adapting
**Duration**: 35 minutes
**Dependencies**: [TASK-3.2, TASK-4.1, TASK-4.2, TASK-4.3, TASK-7.1]

**Description**: Write comprehensive unit tests for service classes.

**Files Created in Previous Tasks**:
- `spec/services/line/client_adapter_spec.rb`
- `spec/services/line/event_processor_spec.rb`
- `spec/services/line/group_service_spec.rb`
- `spec/services/line/command_handler_spec.rb`

**Test Coverage Goals**:
- SdkV2Adapter: ≥90% coverage, ≥8 tests
- EventProcessor: ≥90% coverage, ≥10 tests
- GroupService: ≥95% coverage, ≥7 tests
- CommandHandler: ≥95% coverage, ≥7 tests

**Acceptance Criteria**:
- [ ] All service specs pass
- [ ] Code coverage ≥90% for each service
- [ ] Transaction rollback tested
- [ ] Error handling tested
- [ ] RuboCop violations: 0

**Risks**: None (already created with classes)

---

#### TASK-7.4: Integration Tests - Webhook Flow
**Worker**: test-worker-v1-self-adapting
**Duration**: 35 minutes
**Dependencies**: [TASK-6.1, TASK-7.1]

**Description**: Write end-to-end integration tests for complete webhook processing.

**Files to Create**:
- `spec/requests/operator/webhooks_spec.rb`

**Test Cases**:
```ruby
RSpec.describe 'LINE Webhook Integration', type: :request do
  let(:secret) { Rails.application.credentials.channel_secret }
  let(:valid_payload) do
    {
      events: [
        {
          type: 'message',
          message: { type: 'text', text: 'Hello' },
          source: { groupId: 'GROUP123' },
          replyToken: 'TOKEN123',
          timestamp: Time.current.to_i * 1000
        }
      ]
    }.to_json
  end

  describe 'POST /operator/callback' do
    it 'processes complete webhook flow successfully' do
      # Setup
      allow(Line::ClientProvider).to receive(:client).and_return(mock_adapter)
      allow(mock_adapter).to receive(:get_group_member_count).and_return(5)

      # Execute
      post operator_callback_path,
           params: valid_payload,
           headers: {
             'X-Line-Signature' => valid_signature(valid_payload, secret),
             'Content-Type' => 'application/json'
           }

      # Verify
      expect(response).to have_http_status(:ok)
      expect(LineGroup.find_by(line_group_id: 'GROUP123')).to be_present
    end

    it 'returns 400 for invalid signature'
    it 'returns 400 for blank signature'
    it 'returns 503 on timeout'
    it 'returns 503 on database error'
    it 'creates LineGroup on first message'
    it 'updates post_count on subsequent messages'
    it 'handles removal command'
    it 'handles span setting command'
  end
end
```

**Acceptance Criteria**:
- [ ] Integration spec file created
- [ ] Complete webhook flow tested
- [ ] All HTTP status codes tested
- [ ] Database side effects verified
- [ ] All tests pass (≥9 tests)
- [ ] RuboCop violations: 0

**Risks**: None (integration of tested components)

---

#### TASK-7.5: Update Existing Specs
**Worker**: test-worker-v1-self-adapting
**Duration**: 30 minutes
**Dependencies**: [TASK-6.5]

**Description**: Update existing specs for modified models and classes.

**Files to Update**:
- `spec/models/line_group_spec.rb` (if needed)
- `spec/models/scheduler_spec.rb`
- `spec/models/cat_line_bot_spec.rb` (mark as deprecated)

**Changes Required**:
- Update Scheduler specs to use mocked ClientProvider
- Add tests for RetryHandler integration
- Add tests for metrics tracking
- Mark CatLineBot specs as deprecated (will be removed after migration)

**Acceptance Criteria**:
- [ ] All existing specs updated
- [ ] Scheduler specs use ClientProvider mock
- [ ] All specs pass
- [ ] Code coverage maintained or improved
- [ ] RuboCop violations: 0

**Risks**:
- **Risk**: Breaking existing tests
- **Mitigation**: Run full test suite after each update

---

### Phase 8: Documentation & Cleanup (60 minutes)

#### TASK-8.1: RuboCop Cleanup
**Worker**: backend-worker-v1-self-adapting
**Duration**: 20 minutes
**Dependencies**: [All code tasks]

**Description**: Run RuboCop and fix all violations.

**Commands**:
```bash
bundle exec rubocop app/services/
bundle exec rubocop app/controllers/operator/webhooks_controller.rb
bundle exec rubocop app/controllers/health_controller.rb
bundle exec rubocop app/controllers/metrics_controller.rb
bundle exec rubocop app/models/scheduler.rb
bundle exec rubocop --auto-correct
```

**Acceptance Criteria**:
- [ ] RuboCop runs without errors
- [ ] All auto-correctable violations fixed
- [ ] Manual violations addressed
- [ ] Final rubocop output: 0 offenses

**Risks**: None (code quality check)

---

#### TASK-8.2: Add Code Documentation
**Worker**: backend-worker-v1-self-adapting
**Duration**: 25 minutes
**Dependencies**: [All code tasks]

**Description**: Add comprehensive inline documentation to all new classes.

**Documentation Requirements**:
- Class-level YARD comments for all services
- Method-level comments for public methods
- Parameter documentation (@param)
- Return value documentation (@return)
- Example usage (@example)

**Files to Document**:
- All files in `app/services/line/`
- All files in `app/services/webhooks/`
- All files in `app/services/error_handling/`
- All files in `app/services/resilience/`

**Example**:
```ruby
module Line
  # Client adapter for LINE Bot SDK v2.x
  #
  # Provides abstraction layer over LINE Bot SDK to enable
  # future SDK upgrades without modifying application code.
  #
  # @example
  #   adapter = Line::SdkV2Adapter.new(
  #     channel_id: 'YOUR_CHANNEL_ID',
  #     channel_secret: 'YOUR_SECRET',
  #     channel_token: 'YOUR_TOKEN'
  #   )
  #   adapter.push_message('GROUP123', { type: 'text', text: 'Hello' })
  class SdkV2Adapter < ClientAdapter
    # Initialize adapter with LINE credentials
    #
    # @param credentials [Hash] LINE Bot credentials
    # @option credentials [String] :channel_id Channel ID
    # @option credentials [String] :channel_secret Channel Secret
    # @option credentials [String] :channel_token Channel Token
    # @raise [ArgumentError] if any credential is missing
    def initialize(credentials)
      # ...
    end
  end
end
```

**Acceptance Criteria**:
- [ ] All service classes have YARD comments
- [ ] All public methods documented
- [ ] Examples provided for complex classes
- [ ] YARD documentation generates without warnings

**Risks**: None (documentation task)

---

#### TASK-8.3: Create Migration Guide
**Worker**: backend-worker-v1-self-adapting
**Duration**: 20 minutes
**Dependencies**: [All tasks]

**Description**: Document migration from old implementation to new implementation.

**Files to Create**:
- `docs/migration/line-sdk-v2-migration.md`

**Content Outline**:
1. Overview of changes
2. Breaking changes (if any)
3. New features and improvements
4. Step-by-step migration instructions
5. Rollback instructions
6. Testing recommendations
7. Common issues and solutions

**Acceptance Criteria**:
- [ ] Migration guide created
- [ ] All breaking changes documented
- [ ] Rollback procedure documented
- [ ] Examples provided

**Risks**: None (documentation task)

---

#### TASK-8.4: Final Integration Test & Verification
**Worker**: test-worker-v1-self-adapting
**Duration**: 25 minutes
**Dependencies**: [All tasks]

**Description**: Run complete test suite and verify all functionality.

**Commands**:
```bash
bundle exec rspec
bundle exec rubocop
rails server -e development
curl http://localhost:3000/health/deep
curl http://localhost:3000/metrics
```

**Verification Checklist**:
- [ ] All RSpec tests pass (100%)
- [ ] Code coverage ≥90%
- [ ] RuboCop violations: 0
- [ ] Application starts without errors
- [ ] /health endpoint returns 200
- [ ] /health/deep endpoint returns 200
- [ ] /metrics endpoint returns prometheus format
- [ ] Manual webhook test passes (staging/development)

**Acceptance Criteria**:
- [ ] All automated tests pass
- [ ] Manual verification complete
- [ ] No errors in logs
- [ ] Ready for deployment

**Risks**: None (final verification)

---

## 3. Execution Sequence

### Phase 1: Preparation (45 min)
**Critical Path**: Yes
- TASK-1.1: Update Gemfile (15 min)
- TASK-1.2: Bundle install ← [1.1] (10 min)
- TASK-1.3: Configure Lograge ← [1.2] (15 min) **||**
- TASK-1.4: Configure Prometheus ← [1.2] (15 min) **||**

**Parallel**: TASK-1.3 and TASK-1.4 can run in parallel

---

### Phase 2: Reusable Utilities (90 min)
**Critical Path**: Partial (TASK-2.3 is critical)
- TASK-2.1: SignatureValidator ← [1.2] (30 min) **||**
- TASK-2.2: MessageSanitizer ← [1.2] (20 min) **||**
- TASK-2.3: MemberCounter ← [1.2] (25 min) **||**
- TASK-2.4: RetryHandler ← [1.2] (30 min) **||**
- TASK-2.5: PrometheusMetrics ← [1.4] (15 min) **||**

**Parallel**: All 5 tasks can run in parallel (no dependencies between them)

---

### Phase 3: Core Client Adapter (60 min)
**Critical Path**: Yes
- TASK-3.1: ClientAdapter interface ← [1.2] (20 min)
- TASK-3.2: SdkV2Adapter ← [3.1] (35 min)
- TASK-3.3: ClientProvider ← [3.2] (15 min)

**Sequential**: Must run in order

---

### Phase 4: Event Processing Service (75 min)
**Critical Path**: Yes (TASK-4.1)
- TASK-4.1: EventProcessor ← [2.3, 3.3] (35 min)
- TASK-4.2: GroupService ← [1.2] (30 min) **||**
- TASK-4.3: CommandHandler ← [1.2] (20 min) **||**

**Parallel**: TASK-4.2 and TASK-4.3 can run in parallel with TASK-4.1

---

### Phase 5: Message Handling (40 min)
**Critical Path**: No
- TASK-5.1: OneOnOneHandler ← [3.3] (20 min)
- TASK-5.2: Integrate handlers ← [4.1, 4.2, 4.3, 5.1] (30 min)

**Sequential**: Must run in order

---

### Phase 6: Controller & Scheduler Updates (60 min)
**Critical Path**: Yes (TASK-6.1)
- TASK-6.1: WebhooksController ← [2.1, 4.1] (30 min)
- TASK-6.2: Health checks ← [1.2] (25 min) **||**
- TASK-6.3: Metrics endpoint ← [1.4] (15 min) **||**
- TASK-6.4: Correlation ID ← [1.3] (15 min) **||**
- TASK-6.5: Scheduler ← [2.4, 3.3] (35 min) **||**

**Parallel**: TASK-6.2, 6.3, 6.4, 6.5 can run in parallel with TASK-6.1

---

### Phase 7: Testing (120 min)
**Critical Path**: Yes (TASK-7.4)
- TASK-7.1: Test helpers ← [3.3] (20 min)
- TASK-7.2: Unit tests - Utilities ← [2.1-2.4, 7.1] (30 min) **||**
- TASK-7.3: Unit tests - Services ← [3.2, 4.1-4.3, 7.1] (35 min) **||**
- TASK-7.4: Integration tests ← [6.1, 7.1] (35 min)
- TASK-7.5: Update existing specs ← [6.5] (30 min) **||**

**Parallel**: TASK-7.2, 7.3, 7.5 can run in parallel

---

### Phase 8: Documentation & Cleanup (60 min)
**Critical Path**: No
- TASK-8.1: RuboCop cleanup ← [All code] (20 min)
- TASK-8.2: Documentation ← [All code] (25 min) **||**
- TASK-8.3: Migration guide ← [All] (20 min) **||**
- TASK-8.4: Final verification ← [All] (25 min)

**Parallel**: TASK-8.2 and TASK-8.3 can run in parallel

---

## 4. Dependency Graph

```
Critical Path (8.5 hours):
TASK-1.1 (15m)
  ↓
TASK-1.2 (10m)
  ↓
TASK-2.3 (25m) [MemberCounter - Critical for EventProcessor]
  ↓
TASK-3.1 (20m)
  ↓
TASK-3.2 (35m)
  ↓
TASK-3.3 (15m)
  ↓
TASK-4.1 (35m)
  ↓
TASK-5.2 (30m)
  ↓
TASK-6.1 (30m)
  ↓
TASK-7.4 (35m)
  ↓
TASK-8.4 (25m)

Total Critical Path: ~4.5 hours (with perfect execution)
```

**Parallel Execution Opportunities**:
- Phase 1: 2 tasks (TASK-1.3, 1.4)
- Phase 2: 5 tasks (TASK-2.1, 2.2, 2.3, 2.4, 2.5)
- Phase 4: 2 tasks (TASK-4.2, 4.3 parallel with 4.1)
- Phase 6: 4 tasks (TASK-6.2, 6.3, 6.4, 6.5)
- Phase 7: 3 tasks (TASK-7.2, 7.3, 7.5)
- Phase 8: 2 tasks (TASK-8.2, 8.3)

**Total Parallel Opportunities**: 18 tasks

---

## 5. Risk Assessment

### High-Risk Tasks

**TASK-4.1: Event Processor Service**
- **Risk**: Complex transaction management and timeout logic
- **Likelihood**: Medium
- **Impact**: High (core functionality)
- **Mitigation**:
  - Comprehensive unit tests
  - Integration tests with realistic scenarios
  - Monitor timeout metrics in production

**TASK-6.1: Webhooks Controller**
- **Risk**: Incorrect HTTP status codes could break LINE webhook retries
- **Likelihood**: Low
- **Impact**: High
- **Mitigation**:
  - Follow LINE API documentation exactly
  - Test all error scenarios
  - Monitor webhook delivery success rate

**TASK-7.4: Integration Tests**
- **Risk**: Missing edge cases in integration tests
- **Likelihood**: Medium
- **Impact**: Medium
- **Mitigation**:
  - Test matrix: all event types × all scenarios
  - Include error cases, timeouts, retries

### Medium-Risk Tasks

**TASK-1.2: Bundle Install**
- **Risk**: Dependency conflicts
- **Likelihood**: Low
- **Impact**: Medium
- **Mitigation**: Test in clean environment first

**TASK-2.4: Retry Handler**
- **Risk**: Exponential backoff too aggressive
- **Likelihood**: Medium
- **Impact**: Low
- **Mitigation**: Configurable parameters, test with realistic delays

**TASK-6.5: Scheduler**
- **Risk**: Transaction rollback affects message delivery
- **Likelihood**: Low
- **Impact**: Medium
- **Mitigation**: Test rollback scenarios, add compensation logic

### Low-Risk Tasks

All utility tasks (TASK-2.1, 2.2, 2.3, 2.5), documentation tasks (TASK-8.1, 8.2, 8.3), and health check tasks (TASK-6.2, 6.3) are low-risk.

---

## 6. Definition of Done (Overall)

### Code Quality
- [ ] All 38 tasks completed
- [ ] All RSpec tests passing (100%)
- [ ] Code coverage ≥90%
- [ ] RuboCop violations: 0
- [ ] All YARD documentation complete

### Functionality
- [ ] All LINE Bot features working identically to old implementation
- [ ] Webhook signature validation working
- [ ] All message types handled (text, sticker, etc.)
- [ ] All commands working (removal, span settings)
- [ ] Scheduled messages sending successfully
- [ ] Error notifications working

### Observability
- [ ] Structured logging operational (JSON format)
- [ ] Prometheus metrics collecting data
- [ ] /health endpoint working
- [ ] /health/deep endpoint working
- [ ] /metrics endpoint working
- [ ] Correlation IDs in all logs

### Performance
- [ ] Webhook processing < 8 seconds
- [ ] No memory leaks detected
- [ ] Database query performance maintained or improved

### Documentation
- [ ] All classes documented with YARD
- [ ] Migration guide complete
- [ ] README updated
- [ ] Operational runbook ready

### Deployment Readiness
- [ ] Staging deployment successful
- [ ] Manual testing complete
- [ ] Rollback plan tested
- [ ] Team notified

---

## 7. Resource Allocation

### Worker Assignment Summary

**backend-worker-v1-self-adapting**: 27 tasks
- Phase 1: All 4 tasks
- Phase 2: All 5 tasks
- Phase 3: All 3 tasks
- Phase 4: All 3 tasks
- Phase 5: All 2 tasks
- Phase 6: All 5 tasks
- Phase 8: 5 tasks

**test-worker-v1-self-adapting**: 11 tasks
- Phase 7: All 5 tasks
- Phase 8: 1 task (TASK-8.4)

**Total**: 38 tasks

---

## 8. Estimated Timeline

### Sequential Execution (One Worker)
**Total**: 8-10 hours

### Parallel Execution (Multiple Workers)
With 3 workers running in parallel where possible:

- **Phase 1**: 25 min (parallelized)
- **Phase 2**: 30 min (5 tasks in parallel)
- **Phase 3**: 70 min (sequential)
- **Phase 4**: 35 min (partial parallel)
- **Phase 5**: 50 min (sequential)
- **Phase 6**: 40 min (partial parallel)
- **Phase 7**: 55 min (partial parallel)
- **Phase 8**: 45 min (partial parallel)

**Optimized Total**: ~5-6 hours with perfect parallelization

---

**This task plan is ready for evaluation by planner-evaluators.**
