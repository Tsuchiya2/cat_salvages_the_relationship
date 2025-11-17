# Design Document - LINE Bot SDK Modernization

**Feature ID**: FEAT-LINE-SDK-001
**Created**: 2025-11-16
**Last Updated**: 2025-11-16 (Iteration 2)
**Designer**: designer agent

---

## Metadata

```yaml
design_metadata:
  feature_id: "FEAT-LINE-SDK-001"
  feature_name: "LINE Bot SDK Modernization"
  created: "2025-11-16"
  updated: "2025-11-16"
  iteration: 2
  priority: "high"
  complexity: "medium"
  estimated_effort: "4-6 hours"
```

---

## 1. Overview

### Summary

This design document outlines the modernization of the ReLINE application's LINE Bot implementation from the deprecated `line-bot-api` gem to the modern `line-bot-sdk` gem. The current implementation uses outdated patterns and APIs that are no longer maintained, posing risks for future LINE API updates and security patches.

**Revision Note (Iteration 2)**: This design has been enhanced based on evaluator feedback to improve extensibility, observability, reliability, and reusability. Key additions include:
- Client adapter pattern for SDK abstraction
- Message handler registry for extensible message processing
- Comprehensive metrics collection strategy
- Transaction management for data consistency
- Reusable utility extraction

### Goals and Objectives

1. **Update to Modern SDK**: Replace `line-bot-api` with `line-bot-sdk` (v2.x)
2. **Improve Code Quality**: Adopt modern Ruby patterns and Rails 8.1 best practices
3. **Enhance Extensibility**: Create abstraction layers for future platform support
4. **Improve Observability**: Implement metrics collection and structured logging
5. **Ensure Reliability**: Add transaction management and resilience patterns
6. **Enable Reusability**: Extract common utilities for application-wide use
7. **Zero Downtime**: Deploy updates without service interruption

### Success Criteria

- ✅ All LINE Bot features continue working identically
- ✅ All existing RSpec tests pass with updated SDK
- ✅ No database schema changes required
- ✅ Code quality metrics improve (RuboCop compliance)
- ✅ Deployment completes without downtime
- ✅ Error handling and logging remain functional
- ✅ Metrics collection operational from day one
- ✅ Transaction consistency guaranteed for multi-step operations
- ✅ Webhook processing completes within 8 seconds

---

## 2. Requirements Analysis

### Functional Requirements

**FR-1: Webhook Event Processing**
- Handle incoming webhook callbacks from LINE platform
- Validate webhook signatures
- Parse event payloads
- Route events to appropriate handlers
- **NEW**: Process events within 8-second timeout
- **NEW**: Prevent duplicate event processing (idempotency)

**FR-2: Message Event Handling**
- Process text messages in groups/rooms
- Respond to "Cat sleeping on our Memory." command (bot removal)
- Handle span setting commands:
  - "Would you set to faster."
  - "Would you set to latter."
  - "Would you set to default."
- Update LineGroup records on message receipt
- **NEW**: Support extensible command registration

**FR-3: Join/Leave Event Handling**
- Detect bot additions to groups/rooms (Join event)
- Detect member additions to groups/rooms (MemberJoined event)
- Send welcome messages
- Handle bot removals (Leave event)
- Handle member removals (MemberLeft event)
- Clean up LineGroup records when appropriate
- **NEW**: Atomic transaction for group lifecycle operations

**FR-4: 1-on-1 Chat Handling**
- Detect direct messages (non-group/room context)
- Respond to text messages with usage instructions
- Respond to stickers with sample content
- Handle unknown message types gracefully

**FR-5: Member Counting**
- Query group member counts via LINE API
- Query room member counts via LINE API
- Use counts for business logic decisions
- **NEW**: Cache member counts to reduce API dependency

**FR-6: Message Sending (Scheduler Integration)**
- Push scheduled reminder messages to groups
- Handle multi-message sequences
- Support different message content based on status (wait vs call)
- **NEW**: Implement retry logic with exponential backoff

**FR-7: Error Handling**
- Catch and log exceptions during event processing
- Send error notifications via email (LineMailer)
- Continue processing remaining events on error
- **NEW**: Sanitize sensitive data from error messages
- **NEW**: Return appropriate HTTP status codes for webhook failures

**FR-8: Metrics Collection** (NEW)
- Collect webhook processing duration
- Track event processing success rate
- Monitor LINE API latency and errors
- Export metrics via `/metrics` endpoint

**FR-9: Health Monitoring** (NEW)
- Provide `/health` endpoint for liveness checks
- Provide `/health/deep` endpoint for readiness checks
- Verify database connectivity
- Verify LINE API credentials

### Non-Functional Requirements

**NFR-1: Backward Compatibility**
- No changes to database schema
- No changes to environment variables/credentials structure
- No changes to webhook URL or routing

**NFR-2: Performance**
- Maintain or improve current response times
- Webhook processing < 8 seconds (hard timeout)
- Efficient event processing (< 3 seconds per webhook typical)
- Minimize memory footprint

**NFR-3: Maintainability**
- Follow Rails 8.1 conventions
- Comply with RuboCop style guidelines
- Clear separation of concerns via adapter pattern
- Comprehensive inline documentation

**NFR-4: Testability**
- Maintain existing test coverage
- Enable easier test stubbing/mocking with new SDK
- Support integration testing patterns
- **NEW**: Test utilities independently

**NFR-5: Security**
- Secure signature validation
- Protect against replay attacks (inherent in LINE webhook design)
- Sanitize error messages in email notifications
- **NEW**: Sanitize logs to prevent credential leakage

**NFR-6: Observability** (NEW)
- Structured logging with correlation IDs
- Metrics collection for all critical paths
- Centralized log aggregation
- Log rotation configured

**NFR-7: Reliability** (NEW)
- Transaction management for multi-step operations
- Retry logic for transient failures
- Circuit breaker for LINE API resilience
- Idempotency for webhook retries

**NFR-8: Extensibility** (NEW)
- Platform abstraction for future multi-platform support
- Message handler registry for new message types
- Feature flag system for gradual rollouts

### Constraints

**C-1: Zero Downtime Requirement**
- Production deployment must not interrupt service
- Webhook processing must continue during deployment

**C-2: Database Schema Freeze**
- No database migrations allowed
- LineGroup model structure unchanged

**C-3: Rails Version Compatibility**
- Must work with Rails 8.1.1
- Must work with Ruby 3.4.6

**C-4: Existing Integration Points**
- LineMailer must continue working
- Scheduler class must continue working
- LineGroup model must continue working

---

## 3. Architecture Design

### System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      LINE Platform                           │
│  (Webhook Events: Message, Join, Leave, MemberJoined, etc.) │
└─────────────────────┬───────────────────────────────────────┘
                      │ HTTPS POST
                      │ X-Line-Signature header
                      ▼
┌─────────────────────────────────────────────────────────────┐
│              Operator::WebhooksController                    │
│  - Validate signature (via SignatureValidator utility)      │
│  - Parse events from body                                    │
│  - Delegate to EventProcessor                                │
│  - Return appropriate HTTP status (200/400/503)              │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│              Line::EventProcessor (NEW)                      │
│  - Initialize event router                                   │
│  - Process events with 8-second timeout                      │
│  - Track processed events (idempotency)                      │
│  - Handle errors per event                                   │
└─────┬───────────────┬────────────────┬──────────────────────┘
      │               │                │
      ▼               ▼                ▼
┌──────────┐   ┌──────────┐   ┌──────────────┐
│ Message  │   │   Join   │   │    Leave     │
│ Handler  │   │ Handler  │   │   Handler    │
│          │   │          │   │              │
└────┬─────┘   └────┬─────┘   └──────┬───────┘
     │              │                 │
     ▼              ▼                 ▼
┌─────────────────────────────────────────────┐
│      Line::ClientAdapter (NEW)              │
│  - Abstract interface for LINE SDK          │
│  - Implemented by Line::SdkV2Adapter        │
│  - Enables future SDK version upgrades      │
└────────┬────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│         LINE SDK Client (v2.x)              │
│  - API Client Configuration                 │
│  - Signature Validator                      │
│  - Event Parser                             │
│  - Messaging API Methods                    │
└────────┬────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│          LINE Messaging API                 │
│     (https://api.line.me/v2/bot/*)          │
└─────────────────────────────────────────────┘

Supporting Components (NEW):
┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐
│ GroupService     │   │ MemberCounter    │   │ MessageSanitizer │
│ (Business Logic) │   │ (Utility)        │   │ (Utility)        │
└──────────────────┘   └──────────────────┘   └──────────────────┘

┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐
│ SignatureValidator│  │ RetryHandler     │   │ PrometheusMetrics│
│ (Utility)         │   │ (Utility)        │   │ (Observability)  │
└──────────────────┘   └──────────────────┘   └──────────────────┘

Existing Components:
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│  LineGroup   │   │  Scheduler   │   │  LineMailer  │
│   (Model)    │   │  (Service)   │   │   (Mailer)   │
└──────────────┘   └──────────────┘   └──────────────┘
```

### Component Breakdown

**1. Operator::WebhooksController**
- **Purpose**: HTTP endpoint for LINE webhook callbacks
- **Responsibilities**:
  - Receive POST requests from LINE platform
  - Validate signature using SignatureValidator utility
  - Parse events using SDK
  - Delegate to EventProcessor service
  - Return appropriate HTTP status codes (200 OK, 400 Bad Request, 503 Service Unavailable)
- **Changes Required**:
  - Use SignatureValidator utility (new)
  - Inject EventProcessor dependency
  - Return proper HTTP codes for retry mechanism

**2. Line::EventProcessor (NEW)**
- **Purpose**: Orchestrate event processing with resilience
- **Responsibilities**:
  - Process events within 8-second timeout
  - Track processed webhook events (prevent duplicates)
  - Route events via EventRouter
  - Wrap operations in database transactions
  - Handle errors gracefully with proper logging
- **Implementation**: New service class

**3. Line::ClientAdapter Interface (NEW)**
- **Purpose**: Abstract LINE SDK implementation
- **Responsibilities**:
  - Define interface for messaging operations
  - Enable SDK version upgrades without code changes
  - Support testing with mock adapters
- **Concrete Implementation**: Line::SdkV2Adapter
- **Methods**:
  - `validate_signature(body, signature)`
  - `parse_events(body)`
  - `push_message(target, message)`
  - `reply_message(reply_token, message)`
  - `get_group_member_count(group_id)`
  - `leave_group(group_id)`

**4. Line::EventRouter (NEW)**
- **Purpose**: Route events to appropriate handlers
- **Responsibilities**:
  - Map event types to handler classes
  - Support dynamic handler registration
  - Enable extensibility for new event types
- **Pattern**: Strategy pattern with registry

**5. Line::MessageHandlerRegistry (NEW)**
- **Purpose**: Extensible message type handling
- **Responsibilities**:
  - Register handlers for different message types (text, sticker, image, etc.)
  - Delegate message processing to registered handlers
  - Support adding new message types without modifying core logic
- **Pattern**: Registry pattern

**6. Line::GroupService (NEW)**
- **Purpose**: Business logic for group lifecycle
- **Responsibilities**:
  - Create groups when bot joins (if member count >= 2)
  - Update group records on message receipt
  - Delete groups when empty
  - Calculate next reminder dates
- **Pattern**: Service object (framework-agnostic business logic)

**7. Line::MemberCounter (NEW - Utility)**
- **Purpose**: Reusable member counting logic
- **Responsibilities**:
  - Query member count for groups or rooms
  - Handle fallback when API fails
  - Cache counts to reduce API calls
- **Reusability**: Can be used across entire application

**8. Webhooks::SignatureValidator (NEW - Utility)**
- **Purpose**: Reusable HMAC signature validation
- **Responsibilities**:
  - Validate webhook signatures securely
  - Use constant-time comparison to prevent timing attacks
- **Reusability**: Can be used for any webhook integration (Stripe, GitHub, etc.)

**9. ErrorHandling::MessageSanitizer (NEW - Utility)**
- **Purpose**: Sanitize sensitive data from errors
- **Responsibilities**:
  - Remove credentials from error messages
  - Remove authorization tokens
  - Format errors for logging/email
- **Reusability**: Can be used application-wide

**10. Resilience::RetryHandler (NEW - Utility)**
- **Purpose**: Retry transient failures with exponential backoff
- **Responsibilities**:
  - Retry network timeouts
  - Retry LINE API 500 errors
  - Apply exponential backoff strategy
- **Reusability**: Can be used for all external API calls

**11. PrometheusMetrics (NEW - Observability)**
- **Purpose**: Collect application metrics
- **Responsibilities**:
  - Track webhook processing duration
  - Count events by type
  - Monitor LINE API latency
  - Export via `/metrics` endpoint

**12. Scheduler (Service Class)**
- **Purpose**: Send scheduled reminder messages
- **Responsibilities**:
  - Query LineGroup records due for reminders
  - Push messages via ClientAdapter
  - Update reminder timestamps
  - Handle errors with retry logic
- **Changes Required**: Use ClientAdapter instead of direct client

### Data Flow

**Webhook Request Flow (Enhanced):**
```
1. LINE Platform → POST /operator/callback
2. WebhooksController#callback
   ├─ Read request.body
   ├─ Extract X-Line-Signature header
   ├─ SignatureValidator.valid?(body, signature)
   │  └─ Return 400 Bad Request if invalid
   ├─ ClientAdapter.parse_events(body)
   └─ Call EventProcessor.process(events, client)

3. EventProcessor.process
   ├─ Set 8-second timeout
   ├─ For each event:
   │  ├─ Check if already processed (idempotency)
   │  ├─ Begin database transaction
   │  ├─ Extract group_id/room_id
   │  ├─ MemberCounter.count(event, client)
   │  ├─ GroupService.find_or_create(group_id, member_count)
   │  ├─ EventRouter.route(event, client, context)
   │  │  └─ Delegate to MessageHandler / JoinHandler / LeaveHandler
   │  ├─ Mark event as processed
   │  ├─ Commit transaction
   │  └─ Track metrics (duration, success/failure)
   └─ Return 200 OK to LINE Platform

4. On Error:
   ├─ Rollback transaction
   ├─ Log sanitized error
   ├─ Send notification (if critical)
   ├─ Return 503 Service Unavailable (triggers LINE retry)
   └─ Track error metrics
```

**Scheduled Message Flow (Enhanced):**
```
1. Cron/Scheduler triggers Scheduler.wait_notice or Scheduler.call_notice
2. Scheduler
   ├─ Query LineGroup.remind_wait or LineGroup.remind_call
   ├─ Initialize ClientAdapter
   └─ For each group (in batches):
      ├─ Begin transaction
      ├─ Mark group as "processing"
      ├─ Select message content
      ├─ RetryHandler.call { adapter.push_message(...) }
      ├─ Update group.remind_at
      ├─ Update group.status
      ├─ Commit transaction
      └─ Track metrics

3. On Error:
   ├─ Rollback transaction
   ├─ Mark group as "failed" (for manual retry)
   ├─ Log sanitized error
   └─ Send notification via MessageSanitizer.format_error
```

---

## 4. Data Model

### Database Schema

**No changes required.** The LineGroup model schema remains identical:

```ruby
create_table "line_groups", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
  t.datetime "created_at", null: false
  t.string "line_group_id", null: false          # LINE group/room ID
  t.integer "member_count", default: 0, null: false
  t.integer "post_count", default: 0, null: false
  t.date "remind_at", null: false                # Next reminder date
  t.integer "set_span", default: 0, null: false  # 0=random, 1=faster, 2=latter
  t.integer "status", default: 0, null: false    # 0=wait, 1=call
  t.datetime "updated_at", null: false
  t.index ["line_group_id"], name: "index_line_groups_on_line_group_id", unique: true
end
```

### Transaction Boundaries (NEW)

**TB-1: Webhook Event Processing**
```ruby
ActiveRecord::Base.transaction do
  # 1. Query or create LineGroup
  # 2. Update member_count, post_count
  # 3. Process command (if applicable)
  # 4. Mark webhook event as processed
end
# Atomic: All succeed or all rollback
```

**TB-2: Scheduled Message Sending**
```ruby
ActiveRecord::Base.transaction do
  # 1. Mark group as "processing"
  # 2. Send message via LINE API (non-transactional)
  # 3. Update remind_at and status
  # 4. Mark as complete
end
# On failure: Rollback to "failed" status for manual retry
```

**TB-3: Group Lifecycle (Join/Leave)**
```ruby
ActiveRecord::Base.transaction do
  # 1. Get member count
  # 2. Create/delete LineGroup based on count
  # 3. Send welcome/goodbye message (async if possible)
end
```

### Idempotency Strategy (NEW)

**In-Memory Tracking (Lightweight)**
```ruby
# Track processed webhook event IDs in memory (Redis optional)
class EventProcessor
  def initialize
    @processed_events = Set.new
  end

  def already_processed?(event)
    event_id = generate_event_id(event)
    return true if @processed_events.include?(event_id)

    @processed_events.add(event_id)
    # Expire old IDs after 1 hour (memory management)
    expire_old_events if @processed_events.size > 10000
    false
  end

  private

  def generate_event_id(event)
    # Combination of timestamp + source + message content
    "#{event.timestamp}-#{event.source&.group_id}-#{event.message&.id}"
  end
end
```

### ActiveRecord Models

**LineGroup** (No changes to model, only usage patterns in services)
- **Enums**: `status` (wait/call), `set_span` (random/faster/latter)
- **Validations**: All remain unchanged
- **Scopes**: `remind_wait`, `remind_call`
- **Methods**: `update_record` (no changes)

### External Data Structures (LINE API)

**Event Object (line-bot-sdk v2.x):**
```ruby
# Old pattern (line-bot-api):
event['source']['groupId']
event['source']['roomId']
event['replyToken']
event.message['text']

# New pattern (line-bot-sdk):
event.source.group_id
event.source.room_id
event.reply_token
event.message.text
```

**Member Count Response:**
```ruby
# Old pattern:
json_data = client.get_group_members_count(group_id)
count_members = JSON.parse(json_data.body)
count_members['count']

# New pattern:
response = client.get_group_members_count(group_id)
response['count']  # Already parsed JSON
```

---

## 5. API Design

### LINE Client Adapter Interface (NEW)

```ruby
# app/services/line/client_adapter.rb
module Line
  class ClientAdapter
    # Abstract interface for LINE client operations
    def validate_signature(body, signature)
      raise NotImplementedError
    end

    def parse_events(body)
      raise NotImplementedError
    end

    def push_message(target, message)
      raise NotImplementedError
    end

    def reply_message(reply_token, message)
      raise NotImplementedError
    end

    def get_group_member_count(group_id)
      raise NotImplementedError
    end

    def get_room_member_count(room_id)
      raise NotImplementedError
    end

    def leave_group(group_id)
      raise NotImplementedError
    end

    def leave_room(room_id)
      raise NotImplementedError
    end
  end

  # Concrete implementation for line-bot-sdk v2.x
  class SdkV2Adapter < ClientAdapter
    def initialize(credentials)
      @client = Line::Bot::Client.new do |config|
        config.channel_id = credentials[:channel_id]
        config.channel_secret = credentials[:channel_secret]
        config.channel_token = credentials[:channel_token]
      end
    end

    def validate_signature(body, signature)
      @client.validate_signature(body, signature)
    end

    def parse_events(body)
      @client.parse_events_from(body)
    end

    def push_message(target, message)
      @client.push_message(target, message)
    end

    def reply_message(reply_token, message)
      @client.reply_message(reply_token, message)
    end

    def get_group_member_count(group_id)
      @client.get_group_members_count(group_id)['count'].to_i
    end

    def get_room_member_count(room_id)
      @client.get_room_members_count(room_id)['count'].to_i
    end

    def leave_group(group_id)
      @client.leave_group(group_id)
    end

    def leave_room(room_id)
      @client.leave_room(room_id)
    end
  end

  # Client provider with memoization
  class ClientProvider
    def self.client
      @client ||= SdkV2Adapter.new(
        channel_id: Rails.application.credentials.channel_id,
        channel_secret: Rails.application.credentials.channel_secret,
        channel_token: Rails.application.credentials.channel_token
      )
    end
  end
end
```

### Reusable Utilities

**1. Signature Validator (NEW)**

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

# Usage:
validator = Webhooks::SignatureValidator.new(Rails.application.credentials.channel_secret)
return head :bad_request unless validator.valid?(body, signature)
```

**2. Member Counter (NEW)**

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

**3. Error Message Sanitizer (NEW)**

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

**4. Retry Handler (NEW)**

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

### Event Processing Service (NEW)

```ruby
# app/services/line/event_processor.rb
module Line
  class EventProcessor
    PROCESSING_TIMEOUT = 8 # seconds (leave 2s buffer for LINE's 10s timeout)

    def initialize(adapter:, event_router:, group_service:, member_counter:)
      @adapter = adapter
      @event_router = event_router
      @group_service = group_service
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

      ActiveRecord::Base.transaction do
        group_id = extract_group_id(event)
        member_count = @member_counter.count(event)

        # Business logic
        @group_service.find_or_create(group_id, member_count) if group_id

        # Route to appropriate handler
        context = { group_id: group_id, member_count: member_count }
        @event_router.route(event, @adapter, context)

        # Mark as processed
        mark_processed(event)
      end

      # Track metrics
      PrometheusMetrics.track_event_success(event)
    end

    def extract_group_id(event)
      event.source&.group_id || event.source&.room_id
    end

    def already_processed?(event)
      event_id = generate_event_id(event)
      return true if @processed_events.include?(event_id)

      @processed_events.add(event_id)
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
      LineMailer.error_email(extract_group_id(event), error_message).deliver_later

      PrometheusMetrics.track_event_failure(event, exception)
    end
  end
end
```

### Message Handler Registry (NEW)

```ruby
# app/services/line/message_handler_registry.rb
module Line
  class MessageHandlerRegistry
    def initialize
      @handlers = {}
    end

    def register(message_type, handler)
      @handlers[message_type] = handler
    end

    def handle(event, adapter, context)
      handler = @handlers[event.type]
      return default_handler(event) unless handler

      handler.call(event, adapter, context)
    end

    private

    def default_handler(event)
      Rails.logger.warn "No handler registered for #{event.type}"
    end
  end

  # Global registry
  MESSAGE_REGISTRY = MessageHandlerRegistry.new

  # Register default handlers
  MESSAGE_REGISTRY.register(
    Line::Bot::Event::MessageType::Text,
    ->(event, adapter, context) {
      # Text message handling logic
      text = event.message&.text
      group_id = context[:group_id]

      # Command processing
      if text == "Cat sleeping on our Memory."
        adapter.leave_group(group_id) if group_id
      elsif text =~ /Would you set to (faster|latter|default)\./
        # Span setting logic
      end

      # Update group record
      LineGroup.find_by(line_group_id: group_id)&.increment!(:post_count)
    }
  )

  MESSAGE_REGISTRY.register(
    Line::Bot::Event::MessageType::Sticker,
    ->(event, adapter, context) {
      # Sticker handling logic
    }
  )
end
```

---

## 6. Implementation Plan

### Phase 1: Preparation (45 minutes)

**Task 1.1: Update Gemfile**
```ruby
# Remove:
gem 'line-bot-api'

# Add:
gem 'line-bot-sdk'
gem 'prometheus-client' # For metrics
gem 'lograge' # For structured logging
```

**Task 1.2: Bundle Install**
```bash
bundle install
```

**Task 1.3: Verify Credentials**
- Confirm `Rails.application.credentials.channel_id` exists
- Confirm `Rails.application.credentials.channel_secret` exists
- Confirm `Rails.application.credentials.channel_token` exists

**Task 1.4: Create Feature Branch**
```bash
git checkout -b feature/line-sdk-modernization
```

**Task 1.5: Configure Structured Logging** (NEW)
```ruby
# config/environments/production.rb
config.lograge.enabled = true
config.lograge.formatter = Lograge::Formatters::Json.new
config.lograge.custom_options = lambda do |event|
  {
    correlation_id: RequestStore.store[:correlation_id],
    group_id: event.payload[:group_id],
    event_type: event.payload[:event_type]
  }
end

# Log rotation
config.logger = ActiveSupport::Logger.new(
  Rails.root.join('log', 'production.log'),
  10,           # Keep 10 archived log files
  100.megabytes # Rotate when file reaches 100MB
)
```

**Task 1.6: Configure Prometheus Metrics** (NEW)
```ruby
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

EVENT_PROCESSED_TOTAL = prometheus.counter(
  :event_processed_total,
  docstring: 'Total events processed',
  labels: [:event_type, :status]
)
```

### Phase 2: Create Reusable Utilities (90 minutes)

**Task 2.1: Create Signature Validator**
- File: `app/services/webhooks/signature_validator.rb`
- Implement HMAC-SHA256 validation
- Add RSpec tests
- Estimated: 20 minutes

**Task 2.2: Create Error Message Sanitizer**
- File: `app/services/error_handling/message_sanitizer.rb`
- Implement credential sanitization patterns
- Add RSpec tests
- Estimated: 15 minutes

**Task 2.3: Create Member Counter Utility**
- File: `app/services/line/member_counter.rb`
- Extract group/room counting logic
- Add fallback handling
- Add RSpec tests
- Estimated: 20 minutes

**Task 2.4: Create Retry Handler**
- File: `app/services/resilience/retry_handler.rb`
- Implement exponential backoff
- Configure retryable errors
- Add RSpec tests
- Estimated: 25 minutes

**Task 2.5: Create Prometheus Metrics Module**
- File: `app/services/prometheus_metrics.rb`
- Define metric tracking methods
- Add `/metrics` endpoint
- Estimated: 10 minutes

### Phase 3: Implement Client Adapter (60 minutes)

**Task 3.1: Create Client Adapter Interface**
- File: `app/services/line/client_adapter.rb`
- Define abstract interface
- Document expected methods
- Estimated: 15 minutes

**Task 3.2: Implement SdkV2Adapter**
- File: Same as above
- Implement all interface methods
- Add memoization
- Estimated: 25 minutes

**Task 3.3: Create ClientProvider**
- File: `app/services/line/client_provider.rb`
- Implement singleton client
- Load credentials securely
- Estimated: 10 minutes

**Task 3.4: Add RSpec Tests**
- Test adapter interface
- Mock LINE SDK responses
- Verify all methods work
- Estimated: 10 minutes

### Phase 4: Implement Event Processing Service (75 minutes)

**Task 4.1: Create EventProcessor**
- File: `app/services/line/event_processor.rb`
- Implement timeout protection (8 seconds)
- Add transaction management
- Add idempotency tracking
- Estimated: 30 minutes

**Task 4.2: Create EventRouter**
- File: `app/services/line/event_router.rb`
- Implement strategy pattern
- Support dynamic handler registration
- Estimated: 20 minutes

**Task 4.3: Create MessageHandlerRegistry**
- File: `app/services/line/message_handler_registry.rb`
- Implement registry pattern
- Register text and sticker handlers
- Estimated: 15 minutes

**Task 4.4: Add RSpec Tests**
- Test event processing flow
- Test timeout protection
- Test transaction rollback
- Estimated: 10 minutes

### Phase 5: Create Business Logic Services (60 minutes)

**Task 5.1: Extract GroupService**
- File: `app/services/line/group_service.rb`
- Implement group lifecycle management
- Extract from CatLineBot
- Estimated: 25 minutes

**Task 5.2: Extract SpanSettingService** (Optional)
- File: `app/services/line/span_setting_service.rb`
- Handle span setting commands
- Estimated: 15 minutes

**Task 5.3: Add RSpec Tests**
- Test group creation logic
- Test span setting updates
- Estimated: 20 minutes

### Phase 6: Update Webhook Controller (45 minutes)

**Task 6.1: Refactor WebhooksController**
- File: `app/controllers/operator/webhooks_controller.rb`
- Use SignatureValidator utility
- Inject EventProcessor
- Return proper HTTP status codes
- Estimated: 20 minutes

**Task 6.2: Add Correlation ID Middleware**
- File: `app/controllers/application_controller.rb`
- Set correlation ID from header or generate
- Store in RequestStore
- Estimated: 10 minutes

**Task 6.3: Add Health Check Endpoints**
- File: `app/controllers/health_controller.rb`
- Implement `/health` (shallow check)
- Implement `/health/deep` (dependency checks)
- Estimated: 15 minutes

### Phase 7: Update Scheduler (45 minutes)

**Task 7.1: Refactor Scheduler to Use Adapter**
- File: `app/models/scheduler.rb`
- Use ClientAdapter instead of direct client
- Add RetryHandler for message sends
- Add transaction management
- Estimated: 25 minutes

**Task 7.2: Add Batch Processing**
- Process groups in batches of 50
- Add delay between batches (5 seconds)
- Track progress for recovery
- Estimated: 20 minutes

### Phase 8: Testing (120 minutes)

**Task 8.1: Create Test Fixtures**
- Mock LINE webhook payloads
- Create test helper for client stubbing
- Estimated: 20 minutes

**Task 8.2: Unit Tests - Utilities**
- SignatureValidator: 10 minutes
- MessageSanitizer: 10 minutes
- MemberCounter: 10 minutes
- RetryHandler: 15 minutes

**Task 8.3: Unit Tests - Services**
- ClientAdapter: 10 minutes
- EventProcessor: 20 minutes
- GroupService: 15 minutes

**Task 8.4: Integration Tests - Webhook**
- Test end-to-end webhook flow
- Test signature validation
- Test timeout protection
- Estimated: 20 minutes

### Phase 9: Code Review & Documentation (60 minutes)

**Task 9.1: RuboCop Check**
```bash
bundle exec rubocop app/services/
bundle exec rubocop app/controllers/operator/webhooks_controller.rb
```
- Fix violations
- Estimated: 20 minutes

**Task 9.2: Update Documentation**
- Add extension point documentation
- Document adapter pattern usage
- Create operational runbook
- Estimated: 30 minutes

**Task 9.3: Performance Review**
- Verify metrics collection works
- Check memoization
- Review transaction boundaries
- Estimated: 10 minutes

### Phase 10: Deployment (60 minutes)

**Task 10.1: Deploy to Staging**
- Deploy code
- Verify metrics endpoint works
- Send test webhook
- Monitor logs for 1 hour
- Estimated: 30 minutes

**Task 10.2: Deploy to Production**
- Deploy during low-traffic window (2-4 AM JST)
- Monitor metrics dashboard
- Verify webhook processing
- Check scheduled messages
- Estimated: 30 minutes

---

## 7. Security Considerations

### Threat Model

**Threat 1: Webhook Spoofing**
- **Description**: Attacker sends fake webhook requests pretending to be LINE
- **Impact**: Unauthorized message processing, spam, data manipulation
- **Likelihood**: Medium
- **Severity**: High
- **Mitigation**: Signature validation using SignatureValidator utility (constant-time comparison)

**Threat 2: Credential Exposure**
- **Description**: Channel credentials leaked in logs or error messages
- **Impact**: Complete account takeover
- **Likelihood**: Low (with sanitization)
- **Severity**: Critical
- **Mitigation**: MessageSanitizer removes credentials from all error outputs

**Threat 3: Replay Attacks**
- **Description**: Attacker captures and replays valid webhook requests
- **Impact**: Duplicate message processing
- **Likelihood**: Low
- **Severity**: Medium
- **Mitigation**: Idempotency tracking prevents duplicate processing

**Threat 4: SQL Injection via Group IDs**
- **Description**: Malicious group IDs trigger SQL injection
- **Impact**: Database compromise
- **Likelihood**: Very Low
- **Severity**: Critical
- **Mitigation**: ActiveRecord parameterized queries + input validation

### Security Controls

**SC-1: Enhanced Signature Validation**
```ruby
# Use dedicated utility with constant-time comparison
validator = Webhooks::SignatureValidator.new(Rails.application.credentials.channel_secret)
return head :bad_request if signature.blank?
return head :bad_request unless validator.valid?(body, signature)
```

**SC-2: Credential Protection**
```ruby
# Encrypted credentials only
config.channel_id = Rails.application.credentials.channel_id
config.channel_secret = Rails.application.credentials.channel_secret
config.channel_token = Rails.application.credentials.channel_token

# Verify credentials are loaded
raise "Missing LINE credential: channel_secret" if config.channel_secret.blank?
```

**SC-3: Error Message Sanitization**
```ruby
# Use MessageSanitizer for all error reporting
sanitizer = ErrorHandling::MessageSanitizer.new
error_message = sanitizer.format_error(exception, 'Webhook Processing')
LineMailer.error_email(group_id, error_message).deliver_later
```

**SC-4: Input Validation**
```ruby
# Validate group IDs match expected format
def validate_group_id(group_id)
  return nil if group_id.blank?
  return nil unless group_id.match?(/\A[a-zA-Z0-9]+\z/)
  return nil if group_id.length > 255
  group_id
end
```

**SC-5: HTTPS Enforcement**
```ruby
# config/environments/production.rb
config.force_ssl = true
```

---

## 8. Error Handling

### Error Categories

**Category 1: LINE API Errors**
- 401 Unauthorized → Email notification, no retry
- 429 Rate Limit → Retry with exponential backoff
- 404 Not Found → Log warning, continue processing
- 400 Bad Request → Log error, no retry
- 500 Server Error → Retry with exponential backoff (max 3 attempts)

**Category 2: Network Errors**
- Connection timeout → Retry with exponential backoff
- DNS resolution failure → Retry with exponential backoff
- SSL certificate errors → Email notification, no retry

**Category 3: Application Errors**
- Database connection lost → Return 503, trigger LINE retry
- Record validation failures → Log error, continue processing
- Transaction rollback → Return 503, trigger LINE retry

**Category 4: Business Logic Errors**
- Invalid group state → Log warning, skip operation
- Invalid member count → Use fallback value (2)

### Error Recovery Strategies

**Strategy 1: Retry with Exponential Backoff**
```ruby
retry_handler = Resilience::RetryHandler.new(max_attempts: 3, backoff_factor: 2)
retry_handler.call do
  adapter.push_message(group_id, message)
end
```

**Applied to:**
- LINE API transient errors (500)
- Network timeouts
- Message sending operations

**Strategy 2: Graceful Degradation**
```ruby
member_count = member_counter.count(event)
# Falls back to 2 if API fails
```

**Applied to:**
- Member count API failures
- Non-critical feature unavailability

**Strategy 3: Transaction Rollback**
```ruby
ActiveRecord::Base.transaction do
  # Multi-step operations
rescue ActiveRecord::RecordInvalid => e
  Rails.logger.error "Validation failed: #{e.message}"
  raise # Trigger rollback
end
```

**Applied to:**
- Webhook event processing
- Scheduled message sending
- Group lifecycle operations

**Strategy 4: Circuit Breaker** (Future Enhancement)
```ruby
# Prevent cascading failures
circuit_breaker = CircuitBreaker.new(threshold: 5, timeout: 60)
circuit_breaker.call { adapter.push_message(...) }
```

**Applied to:**
- Repeated LINE API failures
- Preventing cascade failures

### Retry Policies (Explicit)

| Operation | Retry? | Max Attempts | Backoff | Fallback |
|-----------|--------|--------------|---------|----------|
| Member count query | Yes | 3 | Exponential | Return 2 |
| Message send | Yes | 3 | Exponential | Email notification |
| Database write | No | N/A | N/A | Transaction rollback |
| Leave operation | Yes | 3 | Exponential | Email notification |
| Signature validation | No | N/A | N/A | Return 400 |

### Error Response Patterns

**Webhook Processing:**
- **Success**: Return 200 OK
- **Invalid signature**: Return 400 Bad Request (prevents retry)
- **Processing timeout**: Return 503 Service Unavailable (triggers LINE retry)
- **Database unavailable**: Return 503 Service Unavailable (triggers LINE retry)
- **Transaction rollback**: Return 503 Service Unavailable (triggers LINE retry)

**Scheduled Messages:**
- **Success**: Update group status, continue
- **LINE API error**: Retry 3 times, then mark group as "failed"
- **Database error**: Rollback transaction, email notification

---

## 9. Observability

### Logging Strategy

**Framework: Lograge (Structured JSON Logging)**

**Log Levels:**
- **DEBUG**: Event payloads, diagnostic information
- **INFO**: Webhook receipt, event processing, message sending
- **WARN**: Failed member count queries with fallback, non-critical issues
- **ERROR**: Event processing failures, database errors
- **FATAL**: Critical failures (database connection lost)

**Log Context (All Logs Include):**
- `timestamp`: ISO8601 format
- `correlation_id`: Request tracking ID
- `group_id`: LINE group/room ID (if applicable)
- `event_type`: Type of LINE event
- `duration_ms`: Operation duration
- `success`: Boolean status
- `rails_version`: Rails version
- `sdk_version`: LINE SDK version

**Example Structured Log:**
```json
{
  "timestamp": "2025-11-16T10:30:45+09:00",
  "correlation_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "group_id": "Cxxx",
  "event_type": "Line::Bot::Event::Message",
  "duration_ms": 45,
  "success": true,
  "rails_version": "8.1.1",
  "sdk_version": "2.0.0"
}
```

**Log Rotation:**
```ruby
# config/environments/production.rb
config.logger = ActiveSupport::Logger.new(
  Rails.root.join('log', 'production.log'),
  10,           # Keep 10 old log files
  100.megabytes # Rotate when file reaches 100MB
)
```

**Centralized Logging:**
- **Required**: ELK Stack (Elasticsearch + Logstash + Kibana) or CloudWatch Logs
- **Log Shipper**: Fluentd or Filebeat
- **Timeline**: Deployed before production launch (Phase 10)

**Correlation ID Propagation:**
```ruby
# app/controllers/application_controller.rb
around_action :set_correlation_id

def set_correlation_id
  correlation_id = request.headers['X-Request-ID'] || SecureRandom.uuid
  RequestStore.store[:correlation_id] = correlation_id
  yield
ensure
  RequestStore.store[:correlation_id] = nil
end

# Used in all logs:
Rails.logger.tagged(RequestStore.store[:correlation_id]) do
  Rails.logger.info "Processing webhook"
end
```

### Metrics Collection

**Framework: Prometheus**

**Key Metrics:**

1. **Webhook Processing**
   - `webhook_duration_seconds{event_type}` (Histogram)
   - `webhook_requests_total{status}` (Counter)
   - `event_processed_total{event_type, status}` (Counter)

2. **Message Sending**
   - `message_send_total{status}` (Counter)
   - `message_send_duration_seconds` (Histogram)

3. **LINE API**
   - `line_api_calls_total{method, status}` (Counter)
   - `line_api_duration_seconds{method}` (Histogram)

4. **Database**
   - `db_query_duration_seconds{operation}` (Histogram)
   - `db_connection_pool_size` (Gauge)

5. **Business Metrics**
   - `line_groups_total` (Gauge)
   - `scheduled_messages_sent_total{status}` (Counter)

**Metrics Endpoint:**
```ruby
# config/routes.rb
get '/metrics', to: 'metrics#index'

# app/controllers/metrics_controller.rb
class MetricsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def index
    render plain: Prometheus::Client::Formats::Text.marshal(Prometheus::Client.registry),
           content_type: 'text/plain'
  end
end
```

**Usage in Code:**
```ruby
# Track webhook processing duration
start_time = Time.current
# ... process webhook ...
duration = Time.current - start_time

WEBHOOK_DURATION.observe({ event_type: event.class.name }, duration)
EVENT_PROCESSED_TOTAL.increment(labels: { event_type: event.class.name, status: 'success' })
```

### Health Checks

**Shallow Health Check (`/health`):**
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
end
```

**Deep Health Check (`/health/deep`):**
```ruby
def deep
  checks = {
    database: check_database,
    line_api: check_line_api,
    disk_space: check_disk_space
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
  ActiveRecord::Base.connection.execute('SELECT 1')
  { status: 'healthy', latency_ms: 5 }
rescue StandardError => e
  { status: 'unhealthy', error: e.message }
end

def check_line_api
  # Verify credentials are loaded
  { status: 'healthy' } if Rails.application.credentials.channel_token.present?
rescue StandardError => e
  { status: 'unhealthy', error: e.message }
end

def check_disk_space
  stat = Sys::Filesystem.stat('/')
  free_percent = (stat.bytes_free.to_f / stat.bytes_total * 100).round(2)

  if free_percent > 20
    { status: 'healthy', free_percent: free_percent }
  else
    { status: 'unhealthy', free_percent: free_percent, message: 'Low disk space' }
  end
end
```

### Alerting

**Alert Thresholds:**
- **Critical** (Immediate Response):
  - Error rate > 5%
  - Webhook endpoint down (no 200 OK responses)
  - LINE API authentication failure (401)
  - Database connection lost

- **Warning** (Investigate Soon):
  - Error rate > 1%
  - Response time > 5 seconds (95th percentile)
  - Memory usage > 80%

- **Informational**:
  - New group added
  - Group deleted
  - Scheduled message sent

**Alerting Stack:**
- Prometheus Alertmanager
- Notification channels: Email, Slack (future)

**Sample Alert Rule:**
```yaml
# prometheus/alerts.yml
groups:
  - name: line_bot_alerts
    rules:
      - alert: HighErrorRate
        expr: rate(event_processed_total{status="error"}[5m]) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value }} errors/sec"
```

### Operational Runbook (NEW)

**Common Issues and Solutions:**

1. **High Error Rate**
   - **Symptom**: `event_processed_total{status="error"}` increasing
   - **Check**: `/health/deep` endpoint
   - **Check**: Recent logs in centralized logging
   - **Action**: Verify LINE API status, check database connectivity

2. **Slow Response Time**
   - **Symptom**: `webhook_duration_seconds` > 5s
   - **Check**: Database slow query log
   - **Check**: LINE API latency metrics
   - **Action**: Optimize database queries, check LINE API status

3. **Database Connection Errors**
   - **Symptom**: `db_connection_pool_size` at maximum
   - **Check**: Active database connections
   - **Action**: Increase connection pool size, restart application

4. **LINE API Failures**
   - **Symptom**: `line_api_calls_total{status="error"}` increasing
   - **Check**: LINE Developers Console for API status
   - **Action**: Wait for LINE API recovery, verify credentials

---

## 10. Testing Strategy

### Unit Testing Approach

**Test Framework**: RSpec 3.x

**Key Test Cases:**

**1. Utility Tests**
```ruby
RSpec.describe Webhooks::SignatureValidator do
  describe '#valid?' do
    it 'validates correct HMAC signature'
    it 'rejects invalid signature'
    it 'rejects blank signature'
    it 'uses constant-time comparison'
  end
end

RSpec.describe ErrorHandling::MessageSanitizer do
  describe '#sanitize' do
    it 'removes channel_secret from error messages'
    it 'removes authorization tokens'
    it 'preserves other error content'
  end
end

RSpec.describe Line::MemberCounter do
  describe '#count' do
    it 'queries group member count'
    it 'queries room member count'
    it 'returns fallback on API failure'
  end
end

RSpec.describe Resilience::RetryHandler do
  describe '#call' do
    it 'retries transient errors'
    it 'applies exponential backoff'
    it 'stops after max attempts'
    it 'does not retry non-retryable errors'
  end
end
```

**2. Adapter Tests**
```ruby
RSpec.describe Line::SdkV2Adapter do
  describe '#push_message' do
    it 'sends message via LINE SDK'
    it 'handles LINE API errors'
  end

  describe '#get_group_member_count' do
    it 'returns member count as integer'
    it 'parses JSON response'
  end
end
```

**3. Service Tests**
```ruby
RSpec.describe Line::EventProcessor do
  describe '#process' do
    it 'processes all events'
    it 'handles errors per event'
    it 'prevents duplicate processing'
    it 'enforces 8-second timeout'
    it 'wraps operations in transaction'
  end
end

RSpec.describe Line::GroupService do
  describe '#find_or_create' do
    it 'creates group if member count >= 2'
    it 'skips creation for 1-on-1 chats'
    it 'skips existing groups'
  end
end
```

### Integration Testing

**Webhook Integration Test:**
```ruby
RSpec.describe 'LINE Webhook Integration' do
  it 'processes complete webhook flow' do
    payload = {
      events: [
        {
          type: 'message',
          message: { type: 'text', text: 'Hello' },
          source: { groupId: 'GROUP123' },
          replyToken: 'TOKEN123',
          timestamp: Time.current.to_i * 1000
        }
      ]
    }

    # Stub LINE client
    allow(Line::ClientProvider).to receive(:client).and_return(mock_adapter)
    allow(mock_adapter).to receive(:get_group_member_count).and_return(5)

    # Send webhook request
    post operator_callback_path,
         params: payload.to_json,
         headers: {
           'X-Line-Signature' => valid_signature,
           'Content-Type' => 'application/json'
         }

    # Verify response
    expect(response).to have_http_status(:ok)

    # Verify side effects
    expect(LineGroup.find_by(line_group_id: 'GROUP123')).to be_present
  end

  it 'returns 400 for invalid signature' do
    post operator_callback_path,
         params: '{}',
         headers: { 'X-Line-Signature' => 'invalid' }

    expect(response).to have_http_status(:bad_request)
  end

  it 'returns 503 on timeout' do
    # Mock slow processing
    allow_any_instance_of(Line::EventProcessor).to receive(:process).and_raise(Timeout::Error)

    post operator_callback_path,
         params: valid_payload.to_json,
         headers: { 'X-Line-Signature' => valid_signature }

    expect(response).to have_http_status(:service_unavailable)
  end
end
```

### Edge Cases to Test

**EC-1: Transaction Rollback**
- Database write succeeds but LINE API fails
- Multiple events, one fails mid-batch
- Concurrent updates to same LineGroup

**EC-2: Idempotency**
- Same webhook event delivered twice
- Duplicate messages in same batch
- Event ID collision

**EC-3: Timeout Protection**
- Slow database query exceeds timeout
- LINE API latency exceeds timeout
- Multiple slow operations accumulate

**EC-4: Error Sanitization**
- Credentials in exception messages
- Authorization tokens in stack traces
- Sensitive data in query parameters

**EC-5: Member Count Fallback**
- LINE API returns 404 (group deleted)
- LINE API returns 500 (server error)
- Network timeout during count query

---

## 11. Deployment Plan

### Pre-deployment Checklist

- [ ] All RSpec tests passing locally
- [ ] All RSpec tests passing in CI/CD
- [ ] RuboCop violations addressed
- [ ] Manual testing completed in development
- [ ] Credentials verified in production environment
- [ ] Centralized logging configured (ELK/CloudWatch)
- [ ] Prometheus metrics endpoint working (`/metrics`)
- [ ] Health check endpoints working (`/health`, `/health/deep`)
- [ ] Staging deployment successful
- [ ] Rollback plan documented and tested
- [ ] Monitoring dashboards ready (Grafana)
- [ ] Alert rules configured (Alertmanager)
- [ ] Team notified of deployment window

### Deployment Steps

**Step 1: Deploy Monitoring Infrastructure (Before Code Deploy)**

```bash
# 1. Deploy ELK Stack or configure CloudWatch
# 2. Configure Fluentd to ship logs
# 3. Deploy Prometheus server
# 4. Configure Grafana dashboards
# 5. Configure Alertmanager rules
```

**Step 2: Deploy to Staging (1 hour)**

```bash
# 1. Merge feature branch to staging branch
git checkout staging
git merge feature/line-sdk-modernization

# 2. Deploy to staging server
git push staging

# 3. SSH to staging server
ssh user@staging-server

# 4. Install dependencies
cd /path/to/app
bundle install

# 5. Restart application
sudo systemctl restart puma

# 6. Verify metrics endpoint
curl http://staging-server/metrics

# 7. Verify health checks
curl http://staging-server/health/deep

# 8. Monitor logs
tail -f log/production.log
```

**Staging Verification:**
- Send test webhook from LINE Developers Console
- Verify bot responds in test group
- Check `/metrics` endpoint for data
- Check Grafana dashboard for metrics
- Verify error emails work
- Test scheduled message sending
- Monitor for 1 hour

**Step 3: Deploy to Production (During Low-Traffic Window)**

**Recommended Window**: Weekday 2:00 AM - 4:00 AM JST (lowest traffic)

```bash
# 1. Merge to main branch
git checkout main
git merge feature/line-sdk-modernization

# 2. Tag release
git tag -a v2.0.0-line-sdk -m "Modernize LINE SDK to v2.x with observability"
git push origin v2.0.0-line-sdk

# 3. Deploy to production
git push production main

# 4. SSH to production server
ssh user@production-server

# 5. Install dependencies
cd /path/to/app
bundle install --deployment --without development test

# 6. Restart application with zero-downtime (rolling restart)
sudo systemctl reload puma

# 7. Verify health checks
curl https://production-domain.com/health/deep

# 8. Monitor metrics dashboard
# Open Grafana dashboard

# 9. Monitor logs via centralized logging
# Open Kibana/CloudWatch dashboard
```

**Production Verification:**
- Send test message to production bot (from monitoring group)
- Verify response within 3 seconds
- Check Grafana dashboard for metrics
- Verify no error alerts fired
- Verify scheduled jobs run successfully
- Monitor for 24 hours

### Zero-Downtime Strategy

**Approach: Rolling Restart with Puma**

```ruby
# config/puma.rb
workers ENV.fetch("WEB_CONCURRENCY") { 2 }
preload_app!

on_worker_boot do
  ActiveRecord::Base.establish_connection
end
```

**Deployment Process:**
1. Worker 1 continues serving requests
2. Worker 2 restarts with new code
3. Worker 2 passes health check
4. Worker 1 restarts with new code
5. Worker 1 passes health check
6. All workers now on new code

**Load Balancer Configuration:**
- Liveness probe: `GET /health` (every 10s)
- Readiness probe: `GET /health/deep` (every 30s)
- Unhealthy threshold: 3 consecutive failures

### Monitoring During Deployment

**Metrics to Monitor:**

1. **Application Metrics**
   - `webhook_duration_seconds` (should remain < 3s)
   - `event_processed_total{status="error"}` (should be < 1%)
   - Memory usage (should remain < 250MB per worker)
   - CPU usage (should remain < 40%)

2. **LINE API Metrics**
   - `line_api_calls_total{status="success"}` (should be > 99%)
   - `line_api_duration_seconds` (should remain < 1s)

3. **Business Metrics**
   - `line_groups_total` (should not drop)
   - Message processing rate (should remain constant)

**Monitoring Tools:**
- Grafana dashboards (real-time metrics)
- Kibana/CloudWatch (centralized logs)
- Prometheus Alertmanager (alerts)
- LINE Developers Console (webhook delivery logs)

**Alert Thresholds During Deployment:**
- Error rate > 1% → Investigate immediately
- Response time > 5 seconds → Investigate
- Memory usage > 80% → Investigate
- No webhook responses for 5 minutes → Rollback

---

## 12. Rollback Plan

### Rollback Triggers

Execute rollback if any of the following occur within 24 hours of deployment:

1. **Critical Errors**
   - Error rate > 5%
   - Complete webhook processing failure
   - Database corruption
   - Transaction consistency violations

2. **Performance Degradation**
   - Response time > 10 seconds consistently
   - Memory leak detected (memory usage increasing)
   - CPU usage > 90% sustained

3. **Functional Issues**
   - Bot not responding to messages
   - Special commands not working
   - Scheduled messages not sending
   - Metrics collection failing

4. **Integration Issues**
   - LINE API authentication failures
   - Signature validation failures
   - Database connection pool exhaustion

### Rollback Procedure

**Quick Rollback (< 5 minutes):**

```bash
# 1. SSH to production server
ssh user@production-server

# 2. Revert to previous release
cd /path/to/app
git checkout v1.9.0  # Previous stable tag

# 3. Reinstall old gem
bundle install --deployment --without development test

# 4. Restart application
sudo systemctl restart puma

# 5. Verify rollback
curl https://your-domain.com/health
# Should return old version number

# 6. Monitor logs and metrics
# Verify error rate decreases
```

**Rollback Verification:**
- Send test webhook
- Verify bot responds
- Check error logs (should be clean)
- Check Grafana dashboard (error rate should drop)
- Monitor for 30 minutes

### Post-Rollback Analysis

**Investigation Steps:**
1. Collect error logs from failed deployment (via centralized logging)
2. Analyze metrics from Grafana (identify failure pattern)
3. Review transaction consistency (check for orphaned records)
4. Reproduce issue in staging environment
5. Create fix for identified issues
6. Re-test in staging extensively
7. Schedule new deployment

**Communication:**
- Notify team of rollback via Slack/Email
- Document reason for rollback in incident report
- Create post-mortem document
- Schedule post-mortem meeting (within 48 hours)

---

## 13. Extension Points (NEW)

This section documents how to extend the system for future requirements.

### Extension Point 1: New Message Types

**How to Add**: Register handler in MessageHandlerRegistry

**Example: Image Message Support**
```ruby
# app/services/line/message_handlers/image_handler.rb
module Line
  module MessageHandlers
    class ImageHandler
      def call(event, adapter, context)
        # Download image from LINE CDN
        image_url = event.message.image_url
        # Process image (e.g., save to S3)
        # Send confirmation message
        adapter.reply_message(event.reply_token, {
          type: 'text',
          text: 'Image received!'
        })
      end
    end
  end
end

# Register handler
Line::MESSAGE_REGISTRY.register(
  Line::Bot::Event::MessageType::Image,
  Line::MessageHandlers::ImageHandler.new
)
```

**No modification required**: Core event routing logic remains unchanged.

### Extension Point 2: Alternative Messaging Platforms

**How to Add**: Implement new ClientAdapter

**Example: Slack Bot Support**
```ruby
# app/services/slack/client_adapter.rb
module Slack
  class ClientAdapter < MessagingPlatform::ClientAdapter
    def initialize(credentials)
      @client = Slack::Web::Client.new(token: credentials[:bot_token])
    end

    def push_message(target, message)
      @client.chat_postMessage(channel: target, text: message[:text])
    end

    # Implement other required methods...
  end
end

# Use in controller:
adapter = Slack::ClientAdapter.new(credentials)
processor = EventProcessor.new(adapter: adapter, ...)
```

**No modification required**: EventProcessor and business logic work with any adapter.

### Extension Point 3: New Bot Commands

**How to Add**: Register command pattern

**Example: Help Command**
```ruby
# app/services/line/commands/help_command.rb
module Line
  module Commands
    class HelpCommand
      PATTERN = /^(help|ヘルプ)$/i

      def self.matches?(text)
        text.match?(PATTERN)
      end

      def self.execute(event, adapter, context)
        help_text = <<~HELP
          Available commands:
          - "Cat sleeping on our Memory." - Remove bot from group
          - "Would you set to faster." - Set reminder frequency to faster
          - "Would you set to latter." - Set reminder frequency to latter
          - "Would you set to default." - Reset reminder frequency
        HELP

        adapter.reply_message(event.reply_token, {
          type: 'text',
          text: help_text
        })
      end
    end
  end
end

# Register in MessageHandlerRegistry:
if Line::Commands::HelpCommand.matches?(text)
  Line::Commands::HelpCommand.execute(event, adapter, context)
end
```

### Extension Point 4: Message Middleware

**How to Add**: Decorator pattern on ClientAdapter

**Example: Rate Limiting Middleware**
```ruby
# app/services/line/middleware/rate_limited_adapter.rb
module Line
  module Middleware
    class RateLimitedAdapter < ClientAdapter
      def initialize(adapter, rate_limiter:)
        @adapter = adapter
        @rate_limiter = rate_limiter
      end

      def push_message(target, message)
        @rate_limiter.check_and_wait
        @adapter.push_message(target, message)
      end

      # Delegate other methods to @adapter
      def_delegators :@adapter, :validate_signature, :parse_events, ...
    end
  end
end

# Usage:
base_adapter = Line::SdkV2Adapter.new(credentials)
rate_limiter = RateLimiter.new(max_requests_per_minute: 300)
adapter = Line::Middleware::RateLimitedAdapter.new(base_adapter, rate_limiter: rate_limiter)
```

### Extension Point 5: Custom Business Logic per Group

**How to Add**: Strategy pattern in GroupService

**Example: Premium Group Features**
```ruby
# app/services/line/group_strategies/premium_strategy.rb
module Line
  module GroupStrategies
    class PremiumStrategy
      def calculate_next_reminder(group)
        # Premium groups get more frequent reminders
        Date.today + 1.day
      end

      def select_message_content(group)
        # Premium groups get custom messages
        PremiumMessages.for_group(group)
      end
    end

    class StandardStrategy
      def calculate_next_reminder(group)
        # Standard logic
        Date.today + rand(3..7).days
      end

      def select_message_content(group)
        StandardMessages.random
      end
    end
  end
end

# GroupService uses strategy based on group tier:
strategy = group.premium? ? PremiumStrategy.new : StandardStrategy.new
group.remind_at = strategy.calculate_next_reminder(group)
```

---

## 14. Future Enhancements

### Phase 2 Improvements (Post-MVP)

**Enhancement 1: Circuit Breaker for LINE API**
- Implement `CircuitBreaker` class
- Wrap all LINE API calls
- Prevent cascading failures during LINE API outages
- Estimated effort: 2 hours

**Enhancement 2: Rich Message Support**
- Flex messages
- Template messages
- Quick replies
- Image maps
- Estimated effort: 8 hours

**Enhancement 3: Advanced Analytics**
- Message delivery tracking
- User engagement metrics
- A/B testing for message content
- Estimated effort: 16 hours

**Enhancement 4: Redis Caching**
- Cache member counts (TTL: 1 hour)
- Cache group information
- Reduce LINE API dependency
- Estimated effort: 4 hours

**Enhancement 5: Background Job Processing**
- Move welcome messages to Sidekiq
- Implement message queue for scheduled messages
- Add job retry and dead letter queue
- Estimated effort: 6 hours

**Enhancement 6: Multi-Platform Support**
- Implement Slack adapter
- Implement Discord adapter
- Unified bot management interface
- Estimated effort: 20 hours

**Enhancement 7: Feature Flag System**
- Implement feature flag configuration
- Gradual rollout support
- A/B testing infrastructure
- Estimated effort: 4 hours

**Enhancement 8: Distributed Tracing**
- Implement OpenTelemetry instrumentation
- Trace webhook → service → database → LINE API
- Export traces to Jaeger
- Estimated effort: 8 hours

---

## Appendix A: SDK Comparison

### line-bot-api vs line-bot-sdk

| Feature | line-bot-api (Old) | line-bot-sdk (New) |
|---------|-------------------|-------------------|
| Maintenance | ❌ Deprecated | ✅ Active |
| Ruby Version | 2.x - 3.x | 2.5+ (3.4.6 ✅) |
| Rails Version | 5.x - 7.x | 5.x - 8.x ✅ |
| Event Access | Hash-style | Method-style |
| JSON Parsing | Manual | Automatic |
| Documentation | Limited | Comprehensive |
| API Coverage | Partial | Full |

### Migration Effort

| Component | Lines Changed | Complexity | Time Estimate |
|-----------|--------------|------------|---------------|
| Utilities (NEW) | ~300 | Medium | 90 min |
| ClientAdapter (NEW) | ~150 | Medium | 60 min |
| EventProcessor (NEW) | ~200 | High | 75 min |
| Services (NEW) | ~150 | Medium | 60 min |
| WebhooksController | ~50 | Medium | 45 min |
| Scheduler | ~30 | Low | 45 min |
| Tests | ~400 | Medium | 120 min |
| **Total** | **~1280** | **Medium-High** | **8-10 hours** |

---

## Appendix B: Configuration Examples

### Lograge Configuration

```ruby
# config/environments/production.rb
Rails.application.configure do
  # Enable Lograge
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new

  # Custom options
  config.lograge.custom_options = lambda do |event|
    {
      correlation_id: RequestStore.store[:correlation_id],
      group_id: event.payload[:group_id],
      event_type: event.payload[:event_type],
      rails_version: Rails.version,
      environment: Rails.env
    }
  end

  # Log rotation
  config.logger = ActiveSupport::Logger.new(
    Rails.root.join('log', 'production.log'),
    10,           # Keep 10 old log files
    100.megabytes # Rotate when file reaches 100MB
  )
end
```

### Prometheus Configuration

```ruby
# config/initializers/prometheus.rb
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

# Event processing metrics
EVENT_PROCESSED_TOTAL = prometheus.counter(
  :event_processed_total,
  docstring: 'Total events processed',
  labels: [:event_type, :status]
)

# LINE API metrics
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

# Business metrics
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

### Centralized Logging with Fluentd

```conf
# /etc/td-agent/td-agent.conf
<source>
  @type tail
  path /path/to/app/log/production.log
  pos_file /var/log/td-agent/production.log.pos
  tag rails.production
  format json
  time_key timestamp
  time_format %Y-%m-%dT%H:%M:%S%z
</source>

<match rails.**>
  @type elasticsearch
  host elasticsearch-server
  port 9200
  index_name rails-logs
  type_name log
  logstash_format true
  logstash_prefix rails
  flush_interval 10s
</match>
```

---

## Appendix C: Operational Runbook

### Common Issues and Solutions

**Issue 1: High Error Rate**

**Symptoms:**
- Prometheus alert: `HighErrorRate` fires
- Grafana dashboard shows `event_processed_total{status="error"}` increasing

**Diagnosis:**
1. Check `/health/deep` endpoint → Identify failing dependency
2. Query centralized logs → Search for error patterns
3. Check LINE Developers Console → Verify API status
4. Check database → Verify connectivity and performance

**Resolution:**
- If LINE API down → Wait for recovery, errors will auto-resolve
- If database issue → Scale up database, add read replicas
- If application bug → Rollback to previous version

**Prevention:**
- Add more comprehensive error handling
- Implement circuit breaker to fail fast during outages

---

**Issue 2: Slow Response Time**

**Symptoms:**
- Prometheus alert: `SlowWebhookProcessing` fires
- Grafana dashboard shows `webhook_duration_seconds` > 5s

**Diagnosis:**
1. Check `line_api_duration_seconds` → Is LINE API slow?
2. Check `db_query_duration_seconds` → Are database queries slow?
3. Query centralized logs for correlation_id → Identify slow operations

**Resolution:**
- If LINE API slow → Add timeout, return 503 to trigger retry
- If database slow → Optimize queries, add indexes
- If member count query slow → Implement Redis cache

**Prevention:**
- Add database query monitoring
- Implement caching for frequently accessed data

---

**Issue 3: Memory Leak**

**Symptoms:**
- Memory usage continuously increasing
- Worker processes consuming > 500MB RAM

**Diagnosis:**
1. Check Grafana memory dashboard → Identify growth pattern
2. Review recent code changes → Look for object retention
3. Check idempotency tracking → Is `@processed_events` set growing unbounded?

**Resolution:**
- If idempotency set too large → Implement LRU eviction or TTL
- If event objects retained → Add GC after event processing
- Restart workers to reclaim memory (temporary)

**Prevention:**
- Add memory profiling in staging
- Implement automatic worker restart at memory threshold

---

**Issue 4: Database Connection Pool Exhausted**

**Symptoms:**
- Errors: `ActiveRecord::ConnectionTimeoutError`
- `/health/deep` returns unhealthy for database

**Diagnosis:**
1. Check connection pool size → `config.active_record.connection_pool_size`
2. Check active connections → `ActiveRecord::Base.connection_pool.stat`
3. Identify long-running transactions → Database monitoring

**Resolution:**
- Increase connection pool size (short-term)
- Optimize transaction scope (reduce duration)
- Ensure connections are released after use

**Prevention:**
- Monitor connection pool usage metrics
- Add alerts for connection pool > 80% full

---

**End of Design Document**

**Revision Summary (Iteration 2):**
- Added Client Adapter pattern for SDK abstraction
- Implemented Message Handler Registry for extensibility
- Added comprehensive metrics collection strategy
- Implemented transaction management for data consistency
- Extracted reusable utilities (SignatureValidator, MessageSanitizer, MemberCounter, RetryHandler)
- Added structured logging with correlation IDs
- Implemented webhook processing timeout (8 seconds)
- Added deep health check endpoint with dependency verification
- Documented extension points for future development
- Created operational runbook for common issues
- Enhanced security with error sanitization
- Added centralized logging requirement (not optional)

**Next Steps for Main Claude Code:**
1. Re-launch all 7 design evaluators in parallel via Task tool
2. Review updated evaluation results
3. If approved, proceed to Phase 2 (Planning Gate)
4. If changes still requested, iterate design again
