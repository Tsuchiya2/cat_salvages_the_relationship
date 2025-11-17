# Design Reusability Evaluation - LINE Bot SDK Modernization

**Evaluator**: design-reusability-evaluator
**Design Document**: /Users/yujitsuchiya/cat_salvages_the_relationship/docs/designs/line-sdk-modernization.md
**Evaluated**: 2025-11-16T10:30:00+09:00

---

## Overall Judgment

**Status**: Request Changes
**Overall Score**: 3.4 / 5.0

The design shows moderate reusability but has significant opportunities for improvement. While the SDK migration maintains functional compatibility, the design perpetuates existing coupling issues and misses opportunities to create truly reusable components. The current approach treats this as a direct SDK replacement rather than an opportunity to extract reusable patterns for future LINE bot features or other messaging platform integrations.

---

## Detailed Scores

### 1. Component Generalization: 2.5 / 5.0 (Weight: 35%)

**Findings**:
- **Limited Abstraction**: The design maintains tight coupling between business logic and LINE-specific implementations. All components directly reference LINE SDK classes rather than working through abstractions.
- **Hardcoded Dependencies**: Business rules are embedded throughout the codebase (e.g., "Cat sleeping on our Memory." command text, span setting strings) rather than being parameterized.
- **Platform-Specific Implementation**: No abstraction layer exists between the application and LINE SDK, making it impossible to reuse this bot logic for other messaging platforms (Slack, Discord, Telegram).
- **Monolithic Service Class**: `CatLineBot` handles multiple concerns (event routing, member counting, group management) that could be separated into reusable components.

**Issues**:
1. **No Messaging Abstraction**: Direct coupling to `Line::Bot::Client` throughout the codebase
   - Example: `client.push_message(group_id, message)` is LINE-specific
   - Better: Abstract messaging interface that could support multiple platforms

2. **Hardcoded Command Strings**: Command detection is string-based and hardcoded
   - Example: `if text == "Cat sleeping on our Memory."`
   - Better: Command registry pattern with parameterized commands

3. **LINE-Specific Event Routing**: Event routing is tightly coupled to LINE event types
   - Example: `case event when Line::Bot::Event::Message`
   - Better: Generic event handler interface

4. **No Utility Extraction**: Common patterns (signature validation, member counting) not extracted to reusable utilities

**Recommendation**:

Create abstraction layers to decouple business logic from LINE SDK:

```ruby
# 1. Create messaging platform abstraction
module MessagingPlatform
  class Client
    def send_message(recipient, content)
      raise NotImplementedError
    end

    def leave_group(group_id)
      raise NotImplementedError
    end

    def get_member_count(group_id)
      raise NotImplementedError
    end
  end

  class LineClient < Client
    def initialize(line_client)
      @line_client = line_client
    end

    def send_message(recipient, content)
      @line_client.push_message(recipient, { type: 'text', text: content })
    end

    def leave_group(group_id)
      @line_client.leave_group(group_id)
    end

    def get_member_count(group_id)
      @line_client.get_group_members_count(group_id)['count']
    end
  end
end

# 2. Create command registry for reusable commands
class CommandRegistry
  def initialize
    @commands = {}
  end

  def register(pattern, handler)
    @commands[pattern] = handler
  end

  def execute(text, context)
    @commands.each do |pattern, handler|
      return handler.call(context) if text.match?(pattern)
    end
    nil
  end
end

# 3. Generic event handler interface
class EventHandler
  def can_handle?(event)
    raise NotImplementedError
  end

  def handle(event, client, context)
    raise NotImplementedError
  end
end

class MessageEventHandler < EventHandler
  def can_handle?(event)
    event.is_a?(Line::Bot::Event::Message)
  end

  def handle(event, client, context)
    # Generic message handling logic
  end
end
```

**Reusability Potential**:
- **Event Router** → Can be extracted to handle any webhook-based platform (Slack, Discord)
- **Signature Validator** → Can be generalized for HMAC-based webhook validation
- **Member Counter** → Can be abstracted for any group-based messaging platform
- **Message Sender** → Can support multiple message formats and platforms

---

### 2. Business Logic Independence: 3.5 / 5.0 (Weight: 30%)

**Findings**:
- **Partial Separation**: Business logic (reminder scheduling, group management) is somewhat separated from LINE SDK concerns, but still mixed in places.
- **Service Layer Exists**: `CatLineBot` and `Scheduler` act as service layers, which is positive.
- **UI-Agnostic Core**: Core logic doesn't depend on HTTP/UI frameworks (good).
- **Mixed Concerns**: Event processing logic includes both business rules and LINE API calls.

**Issues**:
1. **Business Rules in Event Handlers**: Command processing logic embedded in `MessageEvent` concern
   - Example: Span setting logic is mixed with LINE-specific message handling
   - Better: Extract to dedicated business logic classes

2. **Scheduler Depends on LINE Client**: `Scheduler` class directly creates LINE client instances
   - Example: `client = CatLineBot.line_client_config`
   - Better: Inject messaging client via dependency injection

3. **Group Management Mixed with Events**: LineGroup creation/deletion logic embedded in event processing
   - Example: `create_line_group` called directly in event routing
   - Better: Separate GroupManagementService

**Recommendation**:

Extract pure business logic classes that are framework-agnostic:

```ruby
# 1. Pure business logic service
class GroupReminderService
  def initialize(message_sender)
    @message_sender = message_sender
  end

  def send_reminders(groups, message_content)
    groups.each do |group|
      @message_sender.send_message(group.line_group_id, message_content)
      yield(group) if block_given?
    end
  end
end

# 2. Command processing business logic
class SpanSettingService
  SPAN_MAPPINGS = {
    'faster' => :faster,
    'latter' => :latter,
    'default' => :random
  }.freeze

  def update_span(group, setting_key)
    return false unless SPAN_MAPPINGS.key?(setting_key)

    group.update(set_span: SPAN_MAPPINGS[setting_key])
  end

  def confirmation_message(setting_key)
    case SPAN_MAPPINGS[setting_key]
    when :faster then "設定を「頻繁」に変更したニャ🐾"
    when :latter then "設定を「まれ」に変更したニャ🐾"
    when :random then "設定を「ランダム」に戻したニャ🐾"
    end
  end
end

# 3. Group lifecycle management
class GroupLifecycleService
  def create_group_if_needed(group_id, member_count)
    return if member_count < 2
    return if LineGroup.exists?(line_group_id: group_id)

    LineGroup.create!(
      line_group_id: group_id,
      member_count: member_count,
      remind_at: calculate_next_reminder_date
    )
  end

  def remove_group_if_empty(group_id, member_count)
    return if member_count > 1

    LineGroup.find_by(line_group_id: group_id)&.destroy
  end

  private

  def calculate_next_reminder_date
    # Pure business logic without LINE dependencies
    Date.today + rand(3..7).days
  end
end
```

**Portability Assessment**:
- **Can this logic run in CLI?** Partially - Core group management could, but event handling is tightly coupled
- **Can this logic run in mobile app?** Partially - Business rules yes, but needs refactoring
- **Can this logic run in background job?** Yes - Scheduler demonstrates this capability

---

### 3. Domain Model Abstraction: 4.5 / 5.0 (Weight: 20%)

**Findings**:
- **Clean Domain Model**: `LineGroup` is a pure ActiveRecord model without framework-specific dependencies (excellent).
- **ORM-Agnostic Design**: Model uses standard ActiveRecord patterns, no LINE SDK coupling.
- **Portable Entities**: LineGroup model could be used across different persistence layers with minimal changes.
- **Good Separation**: Domain models don't include LINE API logic or HTTP concerns.

**Issues**:
1. **Minor Naming Coupling**: Model name `LineGroup` is platform-specific
   - Better: More generic name like `MessagingGroup` or `BotGroup` with platform identifier field

2. **Missing Value Objects**: Concepts like "span setting" and "status" could be extracted as value objects
   - Better: `SpanSetting` value object, `GroupStatus` value object

**Recommendation**:

Consider future refactoring for multi-platform support:

```ruby
# 1. Rename model to be platform-agnostic
class MessagingGroup < ApplicationRecord
  # Add platform field
  enum platform: { line: 0, slack: 1, discord: 2 }

  # External ID is platform-specific
  validates :external_group_id, presence: true, uniqueness: { scope: :platform }

  # Business logic remains the same
  enum status: { wait: 0, call: 1 }
  enum set_span: { random: 0, faster: 1, latter: 2 }
end

# 2. Create value objects for domain concepts
class SpanSetting
  VALUES = { random: 0, faster: 1, latter: 2 }.freeze

  attr_reader :value

  def initialize(value)
    @value = VALUES[value] || VALUES[:random]
  end

  def random?
    value == VALUES[:random]
  end

  def faster?
    value == VALUES[:faster]
  end

  def latter?
    value == VALUES[:latter]
  end
end

# 3. Platform adapter pattern
class GroupPlatformAdapter
  def self.for(platform)
    case platform
    when :line then LineGroupAdapter.new
    when :slack then SlackGroupAdapter.new
    else raise "Unsupported platform: #{platform}"
    end
  end
end
```

**Note**: The current `LineGroup` model is excellent for LINE-specific use. The suggestions above are for future multi-platform support and are NOT required for this SDK migration.

---

### 4. Shared Utility Design: 3.0 / 5.0 (Weight: 15%)

**Findings**:
- **Some Utilities Exist**: Client configuration is extracted to a method.
- **Limited Extraction**: Many reusable patterns remain inline (signature validation, error sanitization, member counting).
- **Code Duplication**: Similar error handling patterns appear in multiple places (`CatLineBot`, `Scheduler`).
- **No Utility Library**: No dedicated utility modules for common operations.

**Issues**:
1. **Signature Validation Not Extracted**: Validation logic embedded in controller
   - Appears in: `Operator::WebhooksController#signature`
   - Should be: `WebhookSignatureValidator` utility

2. **Error Sanitization Proposed But Not Extracted**: Design document proposes `sanitized_error_message` but doesn't formalize it
   - Should be: `ErrorMessageSanitizer` utility class

3. **Member Counting Logic Duplicated**: Group vs room counting logic appears in multiple methods
   - Should be: `GroupMemberCounter` utility

4. **Message Content Selection**: Message selection logic hardcoded in Scheduler
   - Should be: `MessageContentSelector` utility

**Recommendation**:

Extract reusable utilities:

```ruby
# 1. Webhook signature validation utility
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
      OpenSSL::HMAC.digest(OpenSSL::Digest.new('SHA256'), @secret, body)
    end

    def secure_compare(a, b)
      ActiveSupport::SecurityUtils.secure_compare(a, b)
    end
  end
end

# 2. Error message sanitization utility
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

# 3. Group member counter utility
module Line
  class MemberCounter
    def initialize(client)
      @client = client
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
      @client.get_group_members_count(group_id)['count'].to_i
    end

    def count_for_room(room_id)
      @client.get_room_members_count(room_id)['count'].to_i
    end

    def fallback_count
      2
    end
  end
end

# 4. Message content selector utility
class MessageContentSelector
  def self.for_status(status)
    case status
    when :wait
      wait_messages
    when :call
      call_messages
    else
      raise ArgumentError, "Unknown status: #{status}"
    end
  end

  def self.wait_messages
    [
      { type: 'text', text: 'First wait message' },
      { type: 'text', text: 'Second wait message' }
    ]
  end

  def self.call_messages
    [
      { type: 'text', text: 'First call message' },
      { type: 'text', text: 'Second call message' }
    ]
  end
end

# 5. Retry utility for transient errors
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

**Usage Example**:
```ruby
# In controller
validator = Webhooks::SignatureValidator.new(Rails.application.credentials.channel_secret)
return head :bad_request unless validator.valid?(body, signature)

# In error handling
sanitizer = ErrorHandling::MessageSanitizer.new
error_message = sanitizer.format_error(e, 'Webhook Callback')

# In event processing
counter = Line::MemberCounter.new(client)
member_count = counter.count(event)

# In scheduler
messages = MessageContentSelector.for_status(:wait)

# For resilient API calls
retry_handler = Resilience::RetryHandler.new
retry_handler.call { client.push_message(group_id, message) }
```

**Potential Utilities**:
- **WebhookSignatureValidator** - Reusable across any HMAC-signed webhook (Stripe, GitHub, etc.)
- **ErrorMessageSanitizer** - Reusable across entire application
- **MemberCounter** - Reusable for any group-based messaging platform
- **MessageContentSelector** - Reusable for different notification types
- **RetryHandler** - Reusable for any external API calls

---

## Reusability Opportunities

### High Potential
1. **Webhook Signature Validator** - Can be shared across any webhook integration (payment gateways, other messaging platforms)
   - Contexts: Stripe webhooks, GitHub webhooks, Slack webhooks
   - Effort: 1 hour to extract and test

2. **Error Sanitization Utility** - Can be used application-wide for safe error logging
   - Contexts: All error reporting, logging, email notifications
   - Effort: 30 minutes to extract and integrate

3. **Retry Handler with Exponential Backoff** - Reusable for all external API calls
   - Contexts: Payment APIs, third-party services, any HTTP client
   - Effort: 1 hour to create comprehensive utility

4. **Messaging Platform Abstraction** - Enable support for Slack, Discord, Telegram
   - Contexts: Multi-platform bot support, notification system
   - Effort: 4-6 hours to design and implement

### Medium Potential
1. **Event Router Pattern** - Can be adapted for other webhook-based integrations
   - Contexts: Stripe events, GitHub events, custom webhooks
   - Minor refactoring needed: Extract LINE-specific types to configuration
   - Effort: 2 hours

2. **Group Lifecycle Service** - Pattern can be reused for any group-based feature
   - Contexts: Team management, project groups, chat rooms
   - Minor refactoring needed: Remove LINE-specific naming
   - Effort: 1 hour

3. **Command Registry System** - Reusable for any command-based bot
   - Contexts: CLI tools, chatbots, automation systems
   - Effort: 2-3 hours to create flexible implementation

### Low Potential (Feature-Specific)
1. **Reminder Scheduling Logic** - Specific to this application's reminder feature
   - Reason: Business rules are unique to "cat relationship" feature
   - Acceptable: Domain-specific logic should be feature-specific

2. **Span Setting Values** - Specific to reminder frequency feature
   - Reason: "faster/latter/random" is unique business requirement
   - Acceptable: Business rules can be feature-specific

3. **Japanese Message Content** - Specific to target audience
   - Reason: Localization is context-dependent
   - Acceptable: Message content should be configurable, not reusable

---

## Action Items for Designer

### Critical (Must Address Before Implementation)

1. **Extract Signature Validation Utility**
   - Create `app/services/webhooks/signature_validator.rb`
   - Make it platform-agnostic (not LINE-specific)
   - Add comprehensive tests
   - Document usage for future webhook integrations

2. **Create Error Sanitization Service**
   - Create `app/services/error_handling/message_sanitizer.rb`
   - Use in all error reporting (CatLineBot, Scheduler, Mailers)
   - Add patterns for all credential types
   - Add tests for various sensitive data patterns

3. **Extract Member Counter Utility**
   - Create `app/services/line/member_counter.rb`
   - Handle both group and room types
   - Include fallback logic and error handling
   - Make it easy to mock in tests

### Recommended (Improve Long-term Maintainability)

4. **Create Messaging Platform Abstraction**
   - Design `MessagingPlatform::Client` interface
   - Implement `MessagingPlatform::LineClient` adapter
   - Refactor CatLineBot to use abstraction
   - Document how to add new platforms (Slack, Discord)

5. **Implement Command Registry Pattern**
   - Create flexible command registration system
   - Move hardcoded command strings to configuration
   - Make commands testable in isolation
   - Document how to add new commands

6. **Extract Business Logic Services**
   - Create `GroupReminderService` (framework-agnostic)
   - Create `SpanSettingService` (pure business logic)
   - Create `GroupLifecycleService` (domain logic only)
   - Inject dependencies (messaging client, configuration)

### Optional (Future Enhancement)

7. **Create Retry Utility**
   - Implement `Resilience::RetryHandler` with exponential backoff
   - Make it configurable (max attempts, backoff factor, retryable errors)
   - Use for all LINE API calls
   - Add circuit breaker pattern for repeated failures

8. **Extract Message Content Management**
   - Create `MessageContentSelector` utility
   - Move message arrays to configuration files (YAML)
   - Support internationalization (I18n)
   - Enable A/B testing of message content

---

## Structured Data

```yaml
evaluation_result:
  evaluator: "design-reusability-evaluator"
  design_document: "/Users/yujitsuchiya/cat_salvages_the_relationship/docs/designs/line-sdk-modernization.md"
  timestamp: "2025-11-16T10:30:00+09:00"
  overall_judgment:
    status: "Request Changes"
    overall_score: 3.4
  detailed_scores:
    component_generalization:
      score: 2.5
      weight: 0.35
      weighted_contribution: 0.875
    business_logic_independence:
      score: 3.5
      weight: 0.30
      weighted_contribution: 1.05
    domain_model_abstraction:
      score: 4.5
      weight: 0.20
      weighted_contribution: 0.90
    shared_utility_design:
      score: 3.0
      weight: 0.15
      weighted_contribution: 0.45
  reusability_opportunities:
    high_potential:
      - component: "WebhookSignatureValidator"
        contexts: ["Stripe webhooks", "GitHub webhooks", "Slack webhooks", "Any HMAC-signed webhook"]
        effort_hours: 1
      - component: "ErrorMessageSanitizer"
        contexts: ["Application-wide error reporting", "Email notifications", "Log files"]
        effort_hours: 0.5
      - component: "RetryHandler"
        contexts: ["All external API calls", "Payment gateways", "Third-party services"]
        effort_hours: 1
      - component: "MessagingPlatformAbstraction"
        contexts: ["Slack bot", "Discord bot", "Telegram bot", "Multi-platform notifications"]
        effort_hours: 5
    medium_potential:
      - component: "EventRouter"
        contexts: ["Stripe events", "GitHub webhooks", "Custom webhook integrations"]
        refactoring_needed: "Extract event type configuration"
        effort_hours: 2
      - component: "GroupLifecycleService"
        contexts: ["Team management", "Project groups", "Any group-based feature"]
        refactoring_needed: "Remove LINE-specific naming"
        effort_hours: 1
      - component: "CommandRegistry"
        contexts: ["Chatbots", "CLI tools", "Automation systems"]
        refactoring_needed: "Make pattern matching flexible"
        effort_hours: 2.5
    low_potential:
      - component: "ReminderSchedulingLogic"
        reason: "Business logic specific to relationship reminder feature"
      - component: "SpanSettingValues"
        reason: "Domain-specific enumeration for this application"
      - component: "JapaneseMessageContent"
        reason: "Localization is context-dependent"
  reusable_component_ratio: 35
  code_duplication_issues:
    - pattern: "Error handling with email notification"
      occurrences: 2
      locations: ["CatLineBot.line_bot_action", "Scheduler.scheduler"]
      recommendation: "Extract to shared ErrorNotificationService"
    - pattern: "Member count querying"
      occurrences: 2
      locations: ["CatLineBot.count_members", "CatLineBot.parse_event"]
      recommendation: "Extract to MemberCounter utility"
    - pattern: "Group vs room detection"
      occurrences: 3
      locations: ["count_members", "current_group_id", "leave operations"]
      recommendation: "Extract to GroupTypeDetector utility"
  missing_abstractions:
    - abstraction: "MessagingPlatform::Client"
      impact: "High"
      description: "Direct coupling to LINE SDK prevents supporting other platforms"
    - abstraction: "CommandHandler interface"
      impact: "Medium"
      description: "Hardcoded command strings make adding new commands difficult"
    - abstraction: "EventHandler interface"
      impact: "Medium"
      description: "Event routing logic mixed with business logic"
  improvement_priority:
    critical:
      - "Extract signature validation utility (security + reusability)"
      - "Create error sanitization service (security + DRY)"
      - "Extract member counter utility (reduce duplication)"
    high:
      - "Create messaging platform abstraction (future multi-platform support)"
      - "Implement command registry pattern (maintainability)"
    medium:
      - "Extract business logic services (testability)"
      - "Create retry utility (resilience)"
    low:
      - "Extract message content management (nice to have)"
```

---

## Summary

The LINE SDK modernization design maintains backward compatibility and follows Rails conventions, which is commendable. However, it misses significant opportunities to improve code reusability and modularity. The design should be revised to:

1. **Extract reusable utilities** (signature validation, error sanitization, retry logic)
2. **Create platform abstractions** to decouple business logic from LINE SDK
3. **Separate business logic** from framework-specific implementation details
4. **Implement command registry** to make bot commands configurable and testable

The domain model design is excellent (4.5/5.0) and should serve as a template for other components. With the recommended changes, this codebase could serve as a foundation for multi-platform messaging bot support and provide reusable utilities for other webhook integrations.

**Recommendation**: Request changes to improve component generalization and utility extraction before proceeding to implementation phase.
