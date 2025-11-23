# Design Reusability Evaluation - GitHub Actions RSpec with Playwright Integration

**Evaluator**: design-reusability-evaluator
**Design Document**: /Users/yujitsuchiya/cat_salvages_the_relationship/docs/designs/github-actions-rspec-playwright.md
**Evaluated**: 2025-11-23T16:00:00+09:00
**Iteration**: 2 (Re-evaluation after design revision)

---

## Overall Judgment

**Status**: Request Changes
**Overall Score**: 3.4 / 5.0

**Summary**: The revised design shows **significant improvements** with abstraction layers (BrowserDriver, ArtifactStorage, RetryPolicy), but still requires changes to remove Rails dependencies and implement missing utilities for full reusability.

---

## Detailed Scores

### 1. Component Generalization: 3.5 / 5.0 (Weight: 35%)

**Findings**:

**Improvements from Previous Evaluation**:
- ✅ BrowserDriver interface created - allows switching between Playwright, Selenium, Puppeteer
- ✅ ArtifactStorage interface created - enables filesystem, S3, GCS, Azure Blob storage
- ✅ RetryPolicy extracted as standalone component
- ✅ PlaywrightArtifactCapture service separates concerns from RSpec

**Remaining Issues**:

1. **Rails.root and Rails.env dependencies still present** - Multiple locations still hardcode Rails dependencies:
   ```ruby
   # Line 468
   def self.for_environment(env = Rails.env)

   # Lines 497, 514, 528
   screenshots_path: Rails.root.join('tmp/screenshots')
   traces_path: Rails.root.join('tmp/traces')

   # Line 775
   FileSystemStorage.new(base_path: Rails.root.join('tmp'))

   # Lines 950, 1196
   logger: Rails.logger
   ```

2. **PlaywrightBrowserSession component not implemented** - Architecture document (lines 296-302) mentions this component but no implementation provided:
   ```
   Component 6: Playwright Browser Session Manager
   - Purpose: Manage browser session lifecycle independent of RSpec
   - File: lib/testing/playwright_browser_session.rb
   - Responsibilities: Browser instance creation, context management, session isolation
   - Reusable in non-RSpec contexts (Minitest, Cucumber, CLI)
   ```

3. **No shared utility libraries created** - The following utilities were requested in previous evaluation but not implemented:
   - PathUtils (for Rails.root.join abstraction)
   - EnvUtils (for Rails.env abstraction)
   - RetryUtils (RetryPolicy exists but not as general-purpose utility)
   - TimeUtils (for timestamp formatting)
   - StringUtils (for filename sanitization)

4. **Configuration still coupled to Rails environment** - The `for_environment` method assumes Rails:
   ```ruby
   def self.for_environment(env = Rails.env)
     case env
     when 'test'  # Rails-specific naming
   ```

**Recommendation**:

**1. Remove Rails.root dependencies with PathUtils**:

```ruby
# lib/testing/utils/path_utils.rb
module Testing
  module Utils
    class PathUtils
      # Get base path for testing artifacts
      # @param custom_path [String, Pathname, nil] Custom path override
      # @return [Pathname] Base path for artifacts
      def self.base_path(custom_path = nil)
        return Pathname.new(custom_path) if custom_path

        # Auto-detect Rails or use environment variable
        if defined?(Rails)
          Rails.root.join('tmp')
        else
          Pathname.new(ENV.fetch('TEST_ARTIFACTS_PATH', 'tmp'))
        end
      end

      def self.screenshots_path(base_path = nil)
        base_path(base_path).join('screenshots')
      end

      def self.traces_path(base_path = nil)
        base_path(base_path).join('traces')
      end
    end
  end
end

# Updated PlaywrightConfiguration
def self.ci_config(base_path: nil)
  base = base_path || Testing::Utils::PathUtils.base_path

  new(
    browser_type: ENV.fetch('PLAYWRIGHT_BROWSER', DEFAULT_BROWSER),
    headless: true,
    viewport: { width: DEFAULT_VIEWPORT_WIDTH, height: DEFAULT_VIEWPORT_HEIGHT },
    slow_mo: 0,
    timeout: 60_000,
    screenshots_path: base.join('screenshots'),  # No Rails.root!
    traces_path: base.join('traces'),
    trace_mode: 'on-first-retry'
  )
end
```

**2. Remove Rails.env dependencies with EnvUtils**:

```ruby
# lib/testing/utils/env_utils.rb
module Testing
  module Utils
    class EnvUtils
      # Get current environment (Rails-agnostic)
      def self.current_env
        if defined?(Rails)
          Rails.env.to_s
        else
          ENV.fetch('RAILS_ENV', ENV.fetch('RACK_ENV', 'test'))
        end
      end

      def self.ci?
        ENV['CI'] == 'true' || ENV['CONTINUOUS_INTEGRATION'] == 'true'
      end

      def self.test?
        current_env == 'test'
      end

      def self.development?
        current_env == 'development'
      end
    end
  end
end

# Updated PlaywrightConfiguration
def self.for_environment(env = nil, base_path: nil)
  env ||= Testing::Utils::EnvUtils.current_env  # No Rails.env!

  case env
  when 'test'
    Testing::Utils::EnvUtils.ci? ? ci_config(base_path: base_path) : local_config(base_path: base_path)
  when 'development'
    development_config(base_path: base_path)
  else
    raise "Unsupported environment: #{env}"
  end
end
```

**3. Remove Rails.logger dependencies with dependency injection**:

```ruby
# lib/testing/retry_policy.rb
def initialize(max_attempts: DEFAULT_MAX_ATTEMPTS,
               base_delay: DEFAULT_BASE_DELAY,
               max_delay: DEFAULT_MAX_DELAY,
               logger: nil)
  @max_attempts = max_attempts
  @base_delay = base_delay
  @max_delay = max_delay
  @logger = logger || default_logger  # No Rails.logger as default!
end

private

def default_logger
  if defined?(Rails)
    Rails.logger
  else
    Logger.new($stdout, level: Logger::INFO)
  end
end
```

**4. Implement PlaywrightBrowserSession (as documented in architecture)**:

```ruby
# lib/testing/playwright_browser_session.rb
module Testing
  # Browser session manager independent of RSpec
  # Can be used in Minitest, Cucumber, CLI, or standalone scripts
  class PlaywrightBrowserSession
    attr_reader :browser, :context, :page, :config

    def initialize(config:, driver: nil)
      @config = config
      @driver = driver || PlaywrightDriver.new
      @browser = nil
      @context = nil
      @page = nil
    end

    # Start browser session
    def start
      @browser = @driver.launch_browser(config)
      @context = @driver.create_context(browser, config)
      @page = @context.new_page

      self
    end

    # Navigate to URL
    def goto(url)
      raise "Session not started" unless page
      page.goto(url)
    end

    # Take screenshot
    def screenshot(path)
      raise "Session not started" unless page
      @driver.take_screenshot(page, path)
    end

    # Close session and cleanup
    def close
      page&.close
      context&.close
      @driver.close_browser(browser) if browser

      @page = nil
      @context = nil
      @browser = nil
    end

    # Execute block with automatic cleanup
    def with_session(&block)
      start
      yield self
    ensure
      close
    end
  end
end

# Usage in CLI (non-RSpec context):
config = Testing::PlaywrightConfiguration.for_environment('test', base_path: '/tmp/artifacts')
session = Testing::PlaywrightBrowserSession.new(config: config)

session.with_session do |browser|
  browser.goto('http://localhost:3000/login')
  browser.screenshot('/tmp/login-page.png')
end
```

**5. Create shared utility libraries**:

```ruby
# lib/testing/utils/time_utils.rb
module Testing
  module Utils
    class TimeUtils
      def self.iso8601_now
        Time.now.iso8601
      end

      def self.filename_timestamp
        Time.now.strftime('%Y%m%d%H%M%S')
      end

      def self.correlation_timestamp
        Time.now.strftime('%Y%m%d-%H%M%S')
      end
    end
  end
end

# lib/testing/utils/string_utils.rb
module Testing
  module Utils
    class StringUtils
      def self.sanitize_filename(filename, max_length: 255)
        sanitized = filename.gsub(/[^0-9A-Za-z_-]/, '_')
        sanitized[0..max_length - 1]
      end

      def self.sanitize_test_name(test_name, max_length: 50)
        sanitized = test_name.downcase.gsub(/[^a-z0-9]+/, '_')
        sanitized[0..max_length - 1]
      end
    end
  end
end

# Usage in PlaywrightArtifactCapture:
def generate_artifact_name(test_metadata, artifact_type)
  test_name = test_metadata[:test_name] || 'unknown_test'
  timestamp = Testing::Utils::TimeUtils.filename_timestamp

  sanitized_name = Testing::Utils::StringUtils.sanitize_test_name(test_name)

  "#{sanitized_name}_#{timestamp}"
end
```

**Reusability Potential**:
- BrowserDriver interface → Can be reused for Selenium, Puppeteer, Appium adapters
- ArtifactStorage interface → Can be reused for S3, GCS, Azure Blob storage
- RetryPolicy → Can be extracted to gem for any Ruby project
- PlaywrightBrowserSession (if implemented) → Reusable in Minitest, Cucumber, CLI scripts

### 2. Business Logic Independence: 3.8 / 5.0 (Weight: 30%)

**Findings**:

**Improvements**:
- ✅ Most business logic separated from RSpec (browser automation, artifact capture, retry)
- ✅ Configuration logic well-isolated in PlaywrightConfiguration class
- ✅ Artifact capture service is framework-agnostic in design
- ✅ Good separation between driver abstraction and implementation

**Remaining Issues**:

1. **RSpec-specific output in PlaywrightArtifactCapture** - Service has RSpec-specific logging:
   ```ruby
   # Line 1290
   puts "\n[ARTIFACT] #{artifact_type.capitalize} saved: #{artifact_path}"

   # Line 1294
   if ENV['CI']
     puts "::notice file=#{artifact_path}::#{artifact_type.capitalize} captured"
   end
   ```
   These should be callbacks or event handlers for framework independence.

2. **RetryPolicy includes RSpec-specific errors** - Hardcoded RSpec coupling:
   ```ruby
   NON_RETRYABLE_ERRORS = [
     RSpec::Expectations::ExpectationNotMetError,  # RSpec-specific!
     Minitest::Assertion
   ].freeze
   ```
   Should be configurable via dependency injection.

3. **RSpec hooks required for artifact capture** - Design requires RSpec hooks (`before(:each)`, `after(:each)`) for trace/screenshot capture. Should provide framework-agnostic event system.

**Recommendation**:

**1. Make RetryPolicy errors configurable**:

```ruby
# lib/testing/retry_policy.rb
module Testing
  class RetryPolicy
    DEFAULT_RETRYABLE_ERRORS = [
      Playwright::TimeoutError,
      Net::ReadTimeout,
      Errno::ECONNREFUSED,
      Errno::ECONNRESET
    ].freeze

    DEFAULT_NON_RETRYABLE_ERRORS = [].freeze

    def initialize(max_attempts: DEFAULT_MAX_ATTEMPTS,
                   base_delay: DEFAULT_BASE_DELAY,
                   max_delay: DEFAULT_MAX_DELAY,
                   logger: nil,
                   retryable_errors: DEFAULT_RETRYABLE_ERRORS,
                   non_retryable_errors: DEFAULT_NON_RETRYABLE_ERRORS)
      @max_attempts = max_attempts
      @base_delay = base_delay
      @max_delay = max_delay
      @logger = logger || default_logger
      @retryable_errors = retryable_errors
      @non_retryable_errors = non_retryable_errors
    end

    private

    def should_retry?(error, attempt)
      return false if attempt >= max_attempts
      return false if @non_retryable_errors.any? { |klass| error.is_a?(klass) }
      @retryable_errors.any? { |klass| error.is_a?(klass) }
    end
  end
end

# Usage in RSpec:
retry_policy = Testing::RetryPolicy.new(
  non_retryable_errors: [RSpec::Expectations::ExpectationNotMetError]
)

# Usage in Minitest:
retry_policy = Testing::RetryPolicy.new(
  non_retryable_errors: [Minitest::Assertion]
)

# Usage in standalone script:
retry_policy = Testing::RetryPolicy.new(
  retryable_errors: [Playwright::TimeoutError, Net::ReadTimeout]
)
```

**2. Extract artifact output to event system**:

```ruby
# lib/testing/artifact_events.rb
module Testing
  # Event-based artifact notification system
  class ArtifactEvents
    attr_reader :handlers

    def initialize
      @handlers = []
    end

    # Register event handler
    def on_artifact_captured(&handler)
      @handlers << handler
    end

    # Emit artifact captured event
    def emit(artifact_type, path, metadata)
      @handlers.each { |h| h.call(artifact_type, path, metadata) }
    end
  end
end

# Updated PlaywrightArtifactCapture
module Testing
  class PlaywrightArtifactCapture
    attr_reader :events

    def initialize(storage:, config:, logger: nil)
      @storage = storage
      @config = config
      @logger = logger || default_logger
      @correlation_id = generate_correlation_id
      @events = ArtifactEvents.new  # Event system instead of puts!
    end

    def capture_screenshot(page, test_metadata)
      # ... existing code ...

      # Emit event instead of printing
      events.emit('screenshot', final_path, test_metadata)

      final_path
    end

    private

    def default_logger
      defined?(Rails) ? Rails.logger : Logger.new($stdout)
    end
  end
end

# RSpec integration (spec/support/playwright.rb):
artifact_capture.events.on_artifact_captured do |type, path, metadata|
  puts "\n[ARTIFACT] #{type.capitalize} saved: #{path}"
  puts "::notice file=#{path}::#{type.capitalize} captured" if ENV['CI']
end

# Minitest integration:
artifact_capture.events.on_artifact_captured do |type, path, metadata|
  puts "[#{type.upcase}] #{path}"
end

# CLI integration:
artifact_capture.events.on_artifact_captured do |type, path, metadata|
  File.write('artifacts.log', "#{type}: #{path}\n", mode: 'a')
end
```

**Portability Assessment**:
- Can this logic run in CLI? **Partially** - Needs Rails dependency removal (PathUtils, EnvUtils)
- Can this logic run in mobile app? **No** - Playwright is browser-only (but architecture is portable to Appium)
- Can this logic run in background job? **Yes** - With Rails dependency removal and event system

### 3. Domain Model Abstraction: 3.2 / 5.0 (Weight: 20%)

**Findings**:

**Positive Aspects**:
- ✅ Good use of value objects for configuration (browser_type, viewport, timeout)
- ✅ Artifact metadata uses plain hashes (portable)
- ✅ No ORM dependencies (no ActiveRecord models)
- ✅ Configuration classes are pure Ruby

**Issues**:

1. **Rails.logger dependency** - Logger is framework-specific:
   ```ruby
   # Lines 950, 1196
   logger: Rails.logger
   ```
   Should accept any Ruby Logger interface.

2. **Rails.env and Rails.root in domain logic** - Configuration factory method couples to Rails:
   ```ruby
   def self.for_environment(env = Rails.env)  # Line 468
   ```

3. **Missing value objects for common concepts**:
   - No ViewportSize value object (just hash `{width: 1920, height: 1080}`)
   - No BrowserType value object (just string `'chromium'`)
   - No ArtifactMetadata value object (just hash)

4. **No validation in domain models** - Configuration validation is basic:
   - `validate!` checks browser type and trace mode only
   - No validation for viewport dimensions, timeout ranges

**Recommendation**:

**1. Create value objects for domain concepts**:

```ruby
# lib/testing/value_objects/viewport_size.rb
module Testing
  module ValueObjects
    class ViewportSize
      attr_reader :width, :height

      def initialize(width:, height:)
        @width = width.to_i
        @height = height.to_i
        validate!
      end

      def to_h
        { width: width, height: height }
      end

      def ==(other)
        width == other.width && height == other.height
      end

      private

      def validate!
        raise ArgumentError, "Width must be > 0" if width <= 0
        raise ArgumentError, "Height must be > 0" if height <= 0
        raise ArgumentError, "Width too large (max 7680)" if width > 7680
        raise ArgumentError, "Height too large (max 4320)" if height > 4320
      end
    end
  end
end

# lib/testing/value_objects/browser_type.rb
module Testing
  module ValueObjects
    class BrowserType
      VALID_TYPES = %w[chromium firefox webkit].freeze

      attr_reader :value

      def initialize(value)
        @value = value.to_s.downcase
        validate!
      end

      def chromium?
        value == 'chromium'
      end

      def firefox?
        value == 'firefox'
      end

      def webkit?
        value == 'webkit'
      end

      def to_s
        value
      end

      def to_sym
        value.to_sym
      end

      private

      def validate!
        unless VALID_TYPES.include?(value)
          raise ArgumentError, "Invalid browser type: #{value}. Must be one of: #{VALID_TYPES.join(', ')}"
        end
      end
    end
  end
end

# Usage:
viewport = Testing::ValueObjects::ViewportSize.new(width: 1920, height: 1080)
browser = Testing::ValueObjects::BrowserType.new('chromium')

config = Testing::PlaywrightConfiguration.new(
  browser_type: browser,
  viewport: viewport,
  # ...
)
```

**2. Remove Rails dependencies with defaults**:

```ruby
def self.for_environment(env = nil, logger: nil, base_path: nil)
  env ||= detect_environment
  logger ||= default_logger
  base_path ||= Testing::Utils::PathUtils.base_path

  # ...
end

def self.detect_environment
  if defined?(Rails)
    Rails.env.to_s
  else
    ENV.fetch('RAILS_ENV', ENV.fetch('RACK_ENV', 'test'))
  end
end

def self.default_logger
  if defined?(Rails)
    Rails.logger
  else
    Logger.new($stdout, level: Logger::INFO)
  end
end
```

### 4. Shared Utility Design: 3.0 / 5.0 (Weight: 15%)

**Findings**:

**Positive Aspects**:
- ✅ RetryPolicy extracted as reusable utility
- ✅ FileSystemStorage provides reusable file operations
- ✅ BrowserDriver interface defines clear utility contract

**Issues**:

1. **No PathUtils utility** - Path operations duplicated:
   - `Rails.root.join('tmp/screenshots')` appears 3+ times
   - `Rails.root.join('tmp/traces')` appears 3+ times
   - No centralized path resolution

2. **No EnvUtils utility** - Environment detection duplicated:
   - `ENV['CI'] == 'true'` appears multiple times
   - `Rails.env` appears multiple times

3. **No TimeUtils utility** - Time formatting duplicated:
   - `Time.now.iso8601` appears multiple times
   - `Time.now.strftime('%Y%m%d-%H%M%S')` in correlation ID generation

4. **No StringUtils utility** - String sanitization duplicated:
   - Filename sanitization in FileSystemStorage: `name.gsub(/[^0-9A-Za-z_-]/, '_')`
   - Test name sanitization in PlaywrightArtifactCapture: `test_name.downcase.gsub(/[^a-z0-9]+/, '_')[0..50]`

5. **No LoggerUtils utility** - JSON logging pattern duplicated

**Recommendation**:

Create comprehensive utility library (code examples provided in Section 1).

**Potential Utilities**:
- PathUtils → Path resolution (reusable across all testing projects)
- EnvUtils → Environment detection (reusable in any Ruby project)
- TimeUtils → Time formatting (reusable in any project)
- StringUtils → String sanitization (reusable for file/artifact handling)
- LoggerUtils → Structured logging (reusable across all projects)

---

## Reusability Opportunities

### High Potential
1. **BrowserDriver interface** - Can be shared across Selenium, Puppeteer, Appium adapters
   - Extract to: `playwright-browser-driver` gem
   - Contexts: Any Ruby browser automation project

2. **ArtifactStorage interface** - Can be shared for S3, GCS, Azure Blob implementations
   - Extract to: `test-artifact-storage` gem
   - Contexts: Any testing framework (RSpec, Minitest, Cucumber)

3. **RetryPolicy** - Can be extracted to separate gem
   - Extract to: `transient-failure-retry` gem
   - Contexts: Any Ruby project (Rails, Sinatra, CLI tools)

4. **Utility library** - PathUtils, EnvUtils, TimeUtils, StringUtils
   - Extract to: `testing-utils` gem
   - Contexts: Any testing project

### Medium Potential
1. **PlaywrightConfiguration** - After Rails dependency removal
   - Reusable in: Sinatra, Hanami, Roda projects
   - Refactoring needed: Remove Rails.root, Rails.env, Rails.logger

2. **PlaywrightArtifactCapture** - After event system implementation
   - Reusable in: Minitest, Cucumber, CLI scripts
   - Refactoring needed: Extract event system, remove puts statements

3. **FileSystemStorage** - Already reusable
   - Minor improvements: Add more validation

### Low Potential (Feature-Specific)
1. **Capybara driver registration** - Inherently Capybara-specific (acceptable)
2. **RSpec hooks** - Inherently RSpec-specific (acceptable)
3. **GitHub Actions workflow** - CI-specific (acceptable)

---

## Action Items for Designer

Since status is "Request Changes", please address the following:

### Critical (Must Fix)

1. **Remove Rails.root dependencies** - Replace with PathUtils:
   - Create `lib/testing/utils/path_utils.rb`
   - Replace all `Rails.root.join('tmp/...')` with `PathUtils.base_path.join('...')`
   - Update PlaywrightConfiguration to accept base_path parameter

2. **Remove Rails.env dependencies** - Replace with EnvUtils:
   - Create `lib/testing/utils/env_utils.rb`
   - Replace all `Rails.env` with `EnvUtils.current_env`
   - Update PlaywrightConfiguration.for_environment to accept env parameter

3. **Remove Rails.logger dependencies** - Use dependency injection:
   - Add logger parameter to all classes with default: `Logger.new($stdout)`
   - Update PlaywrightConfiguration, RetryPolicy, PlaywrightArtifactCapture

4. **Implement PlaywrightBrowserSession** - As documented in architecture (Component 6):
   - Create `lib/testing/playwright_browser_session.rb`
   - Make it independent of RSpec (usable in Minitest, CLI, Cucumber)
   - Provide examples for non-RSpec usage

### Important (Should Fix)

5. **Create shared utility library** - Extract common patterns:
   - Create `lib/testing/utils/string_utils.rb` for sanitization
   - Create `lib/testing/utils/time_utils.rb` for timestamp formatting
   - Create `lib/testing/utils/logger_utils.rb` for structured logging
   - Create `lib/testing/utils.rb` as index file

6. **Make RetryPolicy errors configurable** - Remove hardcoded RSpec/Minitest dependencies:
   - Add retryable_errors and non_retryable_errors parameters
   - Provide examples for RSpec, Minitest, and custom usage

7. **Extract artifact output to event system** - Remove RSpec-specific logging:
   - Create `lib/testing/artifact_events.rb`
   - Update PlaywrightArtifactCapture to use events
   - Provide RSpec, Minitest, and custom event handler examples

### Nice to Have (Optional)

8. **Create value objects for domain concepts**:
   - Create `lib/testing/value_objects/viewport_size.rb`
   - Create `lib/testing/value_objects/browser_type.rb`
   - Create `lib/testing/value_objects/artifact_metadata.rb`

9. **Add comprehensive validation** - Enhance domain model validation:
   - Validate viewport dimensions (min/max)
   - Validate timeout ranges
   - Validate file paths and permissions

10. **Document non-Rails usage** - Show how to use components outside Rails:
    - Add Minitest integration example
    - Add standalone CLI script example
    - Add Cucumber integration example

---

## Structured Data

```yaml
evaluation_result:
  evaluator: "design-reusability-evaluator"
  design_document: "/Users/yujitsuchiya/cat_salvages_the_relationship/docs/designs/github-actions-rspec-playwright.md"
  timestamp: "2025-11-23T16:00:00+09:00"
  iteration: 2
  overall_judgment:
    status: "Request Changes"
    overall_score: 3.4
  detailed_scores:
    component_generalization:
      score: 3.5
      weight: 0.35
      weighted_score: 1.225
      improvements_from_v1:
        - "BrowserDriver interface created"
        - "ArtifactStorage interface created"
        - "RetryPolicy extracted"
      remaining_issues:
        - "Rails.root dependencies in 8+ locations"
        - "PlaywrightBrowserSession not implemented"
        - "No utility libraries (PathUtils, EnvUtils)"
    business_logic_independence:
      score: 3.8
      weight: 0.30
      weighted_score: 1.14
      improvements_from_v1:
        - "Good separation of concerns"
        - "Configuration well-isolated"
      remaining_issues:
        - "RSpec-specific puts statements"
        - "Hardcoded RSpec error types in RetryPolicy"
        - "No event system for framework independence"
    domain_model_abstraction:
      score: 3.2
      weight: 0.20
      weighted_score: 0.64
      remaining_issues:
        - "Rails.logger dependencies"
        - "No value objects (ViewportSize, BrowserType)"
        - "Limited validation"
    shared_utility_design:
      score: 3.0
      weight: 0.15
      weighted_score: 0.45
      remaining_issues:
        - "No PathUtils utility"
        - "No EnvUtils utility"
        - "No TimeUtils utility"
        - "No StringUtils utility"
  reusability_opportunities:
    high_potential:
      - component: "BrowserDriver interface"
        contexts: ["Selenium", "Puppeteer", "Appium"]
        gem_potential: "playwright-browser-driver"
      - component: "ArtifactStorage interface"
        contexts: ["S3", "GCS", "Azure Blob"]
        gem_potential: "test-artifact-storage"
      - component: "RetryPolicy"
        contexts: ["Any Ruby project"]
        gem_potential: "transient-failure-retry"
      - component: "Utility library"
        contexts: ["Any testing project"]
        gem_potential: "testing-utils"
    medium_potential:
      - component: "PlaywrightConfiguration"
        refactoring_needed: "Remove Rails.root, Rails.env, Rails.logger"
      - component: "PlaywrightArtifactCapture"
        refactoring_needed: "Implement event system"
    low_potential:
      - component: "Capybara driver registration"
        reason: "Inherently Capybara-specific"
      - component: "RSpec hooks"
        reason: "Inherently RSpec-specific"
  reusable_component_ratio: 60
  framework_dependencies:
    rails_root_count: 8
    rails_env_count: 5
    rails_logger_count: 4
  missing_components:
    - "lib/testing/playwright_browser_session.rb"
    - "lib/testing/utils/path_utils.rb"
    - "lib/testing/utils/env_utils.rb"
    - "lib/testing/utils/time_utils.rb"
    - "lib/testing/utils/string_utils.rb"
    - "lib/testing/utils/logger_utils.rb"
    - "lib/testing/value_objects/viewport_size.rb"
    - "lib/testing/value_objects/browser_type.rb"
    - "lib/testing/value_objects/artifact_metadata.rb"
    - "lib/testing/artifact_events.rb"
  comparison_with_previous_evaluation:
    improvements:
      - "BrowserDriver abstraction layer added (+1.0 for generalization)"
      - "ArtifactStorage abstraction layer added (+0.8 for generalization)"
      - "RetryPolicy extracted as standalone component (+0.5)"
      - "Better separation of concerns in artifact capture (+0.3)"
    degradations: []
    overall_score_change: +0.0
    reason: "Improvements offset by unresolved Rails dependencies and missing utilities"
```

---

## Summary

The revised design shows **significant progress** with abstraction layers, but **Rails dependencies remain a blocker** for full reusability:

**Strengths**:
- ✅ Interface-based design (BrowserDriver, ArtifactStorage)
- ✅ Good separation of concerns (configuration, capture, retry, storage)
- ✅ RetryPolicy is well-designed and mostly reusable

**Critical Weaknesses**:
- ❌ **Rails dependencies scattered** (Rails.root, Rails.env, Rails.logger in 17+ locations)
- ❌ **Missing promised component** (PlaywrightBrowserSession mentioned but not implemented)
- ❌ **No shared utility libraries** (PathUtils, EnvUtils, TimeUtils, StringUtils not created)
- ❌ **Framework coupling** (RSpec-specific logging, hardcoded error types)

**Impact Without Fixes**:
Components cannot be:
- Extracted to separate gems
- Reused in non-Rails projects (Sinatra, Hanami, Roda)
- Reused in non-RSpec contexts (Minitest, Cucumber, CLI tools)

**Final Recommendation**: **Request Changes** - Remove Rails dependencies, implement missing utilities, and add event system before proceeding to implementation phase.
