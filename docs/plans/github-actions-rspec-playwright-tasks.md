# Task Plan - GitHub Actions RSpec with Playwright Integration

**Feature ID**: FEAT-GHA-001
**Design Document**: docs/designs/github-actions-rspec-playwright.md
**Created**: 2025-11-23
**Planner**: planner agent

---

## Metadata

```yaml
task_plan_metadata:
  feature_id: "FEAT-GHA-001"
  feature_name: "GitHub Actions RSpec with Playwright Integration"
  total_tasks: 42
  estimated_duration: "6-8 days"
  critical_path: ["TASK-1.1", "TASK-2.1", "TASK-3.1", "TASK-4.1", "TASK-5.1", "TASK-6.1", "TASK-7.1"]
  parallel_opportunities: 18
```

---

## 1. Overview

**Feature Summary**: Implement comprehensive CI/CD pipeline for RSpec testing using GitHub Actions, replacing Selenium WebDriver with Playwright for more reliable, faster, and cross-platform browser automation. All components are framework-agnostic and reusable across Ruby projects (Sinatra, Hanami, pure Ruby).

**Total Tasks**: 42
**Execution Phases**: 7 (Utilities → Playwright Core → Artifact Management → Browser Session → RSpec Integration → GitHub Actions → Documentation)
**Parallel Opportunities**: 18 tasks can run in parallel across phases

**Critical Path Highlights**:
- Utility libraries creation (Phase 1)
- Playwright configuration and driver (Phase 2)
- Artifact storage implementation (Phase 3)
- Browser session management (Phase 4)
- RSpec/Capybara integration (Phase 5)
- GitHub Actions workflow (Phase 6)
- Documentation and verification (Phase 7)

---

## 2. Task Breakdown

### Phase 1: Framework-Agnostic Utility Libraries (2-3 hours)

#### TASK-1.1: Create PathUtils Module
**Worker**: backend-worker-v1-self-adapting
**Duration**: 30 minutes
**Dependencies**: None

**Description**: Implement framework-agnostic path management utility that works with or without Rails.

**Files to Create**:
- `lib/testing/utils/path_utils.rb`

**Implementation Requirements**:
- Detect Rails.root if Rails is available, otherwise use Dir.pwd
- Provide paths for: root, tmp, screenshots, traces, coverage
- Allow custom root path configuration (setter method)
- Use Pathname for path manipulation
- All methods return Pathname objects

**Code Structure**:
```ruby
module Testing
  module Utils
    module PathUtils
      class << self
        def root_path
        def tmp_path
        def screenshots_path
        def traces_path
        def coverage_path
        def root_path=(path)
      end
    end
  end
end
```

**Acceptance Criteria**:
- [ ] PathUtils.root_path returns correct path in Rails environment
- [ ] PathUtils.root_path returns Dir.pwd in non-Rails environment
- [ ] All path methods return Pathname objects
- [ ] Custom root path can be set via PathUtils.root_path=
- [ ] No Rails dependencies in implementation
- [ ] Module documented with YARD comments

**Testing Requirements**:
- Unit tests for each method
- Tests for Rails and non-Rails environments
- Tests for custom root path configuration

**Risks**:
- **Risk**: Path resolution issues on Windows
- **Mitigation**: Use Pathname for cross-platform compatibility

---

#### TASK-1.2: Create EnvUtils Module
**Worker**: backend-worker-v1-self-adapting
**Duration**: 30 minutes
**Dependencies**: None (can parallel with TASK-1.1)

**Description**: Implement framework-agnostic environment detection utility.

**Files to Create**:
- `lib/testing/utils/env_utils.rb`

**Implementation Requirements**:
- Detect Rails.env if Rails is available, otherwise use RACK_ENV or APP_ENV
- Provide boolean helpers: test_environment?, ci_environment?, production_environment?, development_environment?
- Detect CI environment from CI=true or GITHUB_ACTIONS=true
- Provide get(key, default) method for environment variables with fallback

**Code Structure**:
```ruby
module Testing
  module Utils
    module EnvUtils
      class << self
        def environment
        def test_environment?
        def ci_environment?
        def production_environment?
        def development_environment?
        def get(key, default = nil)
      end
    end
  end
end
```

**Acceptance Criteria**:
- [ ] EnvUtils.environment returns Rails.env in Rails environment
- [ ] EnvUtils.environment returns RACK_ENV/APP_ENV in non-Rails environment
- [ ] CI detection works for GitHub Actions (GITHUB_ACTIONS=true)
- [ ] CI detection works for generic CI (CI=true)
- [ ] get() method returns environment variable or default
- [ ] No Rails dependencies in implementation
- [ ] Module documented with YARD comments

**Testing Requirements**:
- Unit tests for each method
- Tests for Rails and non-Rails environments
- Tests for CI detection
- Tests for environment variable fallback

**Risks**:
- **Risk**: Incorrect environment detection
- **Mitigation**: Test with multiple environment variable combinations

---

#### TASK-1.3: Create TimeUtils Module
**Worker**: backend-worker-v1-self-adapting
**Duration**: 25 minutes
**Dependencies**: None (can parallel with TASK-1.1, TASK-1.2)

**Description**: Implement timestamp formatting utility for artifact filenames and correlation IDs.

**Files to Create**:
- `lib/testing/utils/time_utils.rb`

**Implementation Requirements**:
- format_for_filename: Returns YYYYMMDD-HHMMSS format
- format_iso8601: Returns ISO 8601 format for JSON/logs
- format_human: Returns human-readable format
- generate_correlation_id: Returns unique ID with timestamp and random hex

**Code Structure**:
```ruby
module Testing
  module Utils
    module TimeUtils
      class << self
        def format_for_filename(time = Time.now)
        def format_iso8601(time = Time.now)
        def format_human(time = Time.now)
        def generate_correlation_id(prefix = 'test-run')
      end
    end
  end
end
```

**Acceptance Criteria**:
- [ ] format_for_filename returns safe filename format (no colons/slashes)
- [ ] format_iso8601 returns valid ISO 8601 timestamp
- [ ] format_human returns readable format (YYYY-MM-DD HH:MM:SS)
- [ ] generate_correlation_id includes prefix, timestamp, and random hex
- [ ] correlation_id is unique on each call
- [ ] Module documented with YARD comments

**Testing Requirements**:
- Unit tests for each formatting method
- Test correlation ID uniqueness (call multiple times)
- Test custom time parameter handling

**Risks**:
- **Risk**: Correlation ID collisions
- **Mitigation**: Use SecureRandom.hex(3) for uniqueness

---

#### TASK-1.4: Create StringUtils Module
**Worker**: backend-worker-v1-self-adapting
**Duration**: 30 minutes
**Dependencies**: None (can parallel with TASK-1.1, TASK-1.2, TASK-1.3)

**Description**: Implement string sanitization utility for safe filenames.

**Files to Create**:
- `lib/testing/utils/string_utils.rb`

**Implementation Requirements**:
- sanitize_filename: Replace non-alphanumeric characters with underscores
- generate_artifact_name: Combine test name with optional index
- truncate_filename: Limit filename length to 255 characters while preserving extension

**Code Structure**:
```ruby
module Testing
  module Utils
    module StringUtils
      class << self
        def sanitize_filename(name)
        def generate_artifact_name(test_name, index = nil)
        def truncate_filename(name, max_length = 255)
      end
    end
  end
end
```

**Acceptance Criteria**:
- [ ] sanitize_filename removes special characters (/, \, :, *, ?, ", <, >, |)
- [ ] sanitize_filename preserves alphanumeric, hyphen, and underscore
- [ ] generate_artifact_name sanitizes and optionally appends index
- [ ] truncate_filename preserves file extension
- [ ] truncate_filename adds ellipsis (...) when truncating
- [ ] Module documented with YARD comments

**Testing Requirements**:
- Unit tests for each method
- Test with various special characters
- Test truncation with different filename lengths
- Test edge cases (empty strings, very long filenames)

**Risks**:
- **Risk**: Path traversal attacks with unsanitized filenames
- **Mitigation**: Strict character whitelist (alphanumeric, hyphen, underscore only)

---

#### TASK-1.5: Create NullLogger Class
**Worker**: backend-worker-v1-self-adapting
**Duration**: 15 minutes
**Dependencies**: None (can parallel with TASK-1.1, TASK-1.2, TASK-1.3, TASK-1.4)

**Description**: Implement null object pattern for logger to avoid Rails.logger dependency.

**Files to Create**:
- `lib/testing/utils/null_logger.rb`

**Implementation Requirements**:
- Implement all standard logger methods (debug, info, warn, error, fatal)
- All methods accept any arguments and do nothing (no-op)
- Used as default when no logger is injected

**Code Structure**:
```ruby
module Testing
  module Utils
    class NullLogger
      def debug(*_args); end
      def info(*_args); end
      def warn(*_args); end
      def error(*_args); end
      def fatal(*_args); end
    end
  end
end
```

**Acceptance Criteria**:
- [ ] All logger methods implemented as no-ops
- [ ] NullLogger can be used as drop-in replacement for Rails.logger
- [ ] No exceptions raised when calling logger methods
- [ ] Class documented with YARD comments

**Testing Requirements**:
- Unit tests verifying all methods are callable
- Test with various argument types

**Risks**: None

---

#### TASK-1.6: Create Unit Tests for Utility Modules
**Worker**: test-worker-v1-self-adapting
**Duration**: 1 hour
**Dependencies**: [TASK-1.1, TASK-1.2, TASK-1.3, TASK-1.4, TASK-1.5]

**Description**: Implement comprehensive unit tests for all utility modules.

**Files to Create**:
- `spec/lib/testing/utils/path_utils_spec.rb`
- `spec/lib/testing/utils/env_utils_spec.rb`
- `spec/lib/testing/utils/time_utils_spec.rb`
- `spec/lib/testing/utils/string_utils_spec.rb`
- `spec/lib/testing/utils/null_logger_spec.rb`

**Test Coverage Requirements**:
- PathUtils: Rails vs non-Rails environment, custom root path
- EnvUtils: Environment detection, CI detection, variable fallback
- TimeUtils: Timestamp formats, correlation ID uniqueness
- StringUtils: Sanitization, truncation, edge cases
- NullLogger: All methods callable, no exceptions

**Acceptance Criteria**:
- [ ] All utility modules have ≥95% code coverage
- [ ] Tests cover Rails and non-Rails environments
- [ ] Tests cover CI and local environments
- [ ] Tests cover edge cases and error conditions
- [ ] All tests pass

**Testing Requirements**:
- Minimum 95% code coverage for utility modules
- Use RSpec with proper describe/context blocks
- Mock Rails constant where needed

**Risks**:
- **Risk**: Tests coupled to Rails
- **Mitigation**: Use conditional Rails detection in tests

---

### Phase 2: Playwright Configuration and Driver (2-3 hours)

#### TASK-2.1: Update Gemfile and Install Playwright
**Worker**: backend-worker-v1-self-adapting
**Duration**: 20 minutes
**Dependencies**: None

**Description**: Update Gemfile to add playwright-ruby-client and remove webdrivers gem.

**Files to Modify**:
- `Gemfile`

**Changes Required**:
```ruby
group :test do
  # Replace Selenium with Playwright
  gem 'playwright-ruby-client', '~> 1.45'
  gem 'capybara', '>= 3.26'
  # Remove: gem 'webdrivers'

  gem 'rspec-rails', '~> 7.1'
  gem 'simplecov', require: false
  gem 'simplecov-console', require: false
  gem 'bundler-audit', require: false
end
```

**Commands**:
```bash
bundle install
npx playwright install chromium --with-deps
```

**Acceptance Criteria**:
- [ ] playwright-ruby-client added to Gemfile
- [ ] webdrivers removed from Gemfile
- [ ] bundle install completes successfully
- [ ] Playwright browsers installed (chromium)
- [ ] No dependency conflicts

**Testing Requirements**:
- Verify Playwright can be required: `require 'playwright'`
- Verify browsers installed: `npx playwright --version`

**Risks**:
- **Risk**: Playwright browser installation fails
- **Mitigation**: Use --with-deps flag to install system dependencies

---

#### TASK-2.2: Create BrowserDriver Interface
**Worker**: backend-worker-v1-self-adapting
**Duration**: 30 minutes
**Dependencies**: None (can parallel with TASK-2.1)

**Description**: Implement abstract interface for browser automation drivers to enable future driver swapping.

**Files to Create**:
- `lib/testing/browser_driver.rb`

**Implementation Requirements**:
- Define abstract methods: launch_browser, close_browser, create_context, take_screenshot, start_trace, stop_trace
- All methods raise NotImplementedError
- Used as base class for PlaywrightDriver and potential future drivers

**Code Structure**:
```ruby
module Testing
  class BrowserDriver
    def launch_browser(config)
    def close_browser(browser)
    def create_context(browser, config)
    def take_screenshot(page, path)
    def start_trace(context)
    def stop_trace(context, path)
  end
end
```

**Acceptance Criteria**:
- [ ] All abstract methods defined
- [ ] Methods raise NotImplementedError with descriptive message
- [ ] Interface documented with YARD comments
- [ ] Parameter types documented

**Testing Requirements**:
- Unit tests verifying NotImplementedError is raised
- Tests for each abstract method

**Risks**: None

---

#### TASK-2.3: Create PlaywrightConfiguration Class
**Worker**: backend-worker-v1-self-adapting
**Duration**: 1 hour
**Dependencies**: [TASK-1.1, TASK-1.2] (needs PathUtils and EnvUtils)

**Description**: Implement centralized Playwright configuration with environment-specific settings.

**Files to Create**:
- `lib/testing/playwright_configuration.rb`

**Implementation Requirements**:
- Use PathUtils for directory paths (not Rails.root)
- Use EnvUtils for environment detection (not Rails.env)
- Factory method: for_environment(env) returning appropriate config
- Three configuration presets: ci_config, local_config, development_config
- Validation for browser_type, trace_mode, timeout
- Generate browser_launch_options and browser_context_options
- Ensure artifact directories exist on initialization

**Configuration Presets**:
- **CI**: headless=true, timeout=60s, trace_mode=on-first-retry
- **Local**: headless=configurable via env var, timeout=30s, trace_mode=off
- **Development**: headless=false, slow_mo=500ms, trace_mode=on

**Code Structure**:
```ruby
module Testing
  class PlaywrightConfiguration
    DEFAULT_BROWSER = 'chromium'
    DEFAULT_HEADLESS = true
    DEFAULT_VIEWPORT_WIDTH = 1920
    DEFAULT_VIEWPORT_HEIGHT = 1080

    attr_reader :browser_type, :headless, :viewport, :slow_mo, :timeout,
                :screenshots_path, :traces_path, :trace_mode

    def self.for_environment(env = nil)
    def self.ci_config
    def self.local_config
    def self.development_config

    def initialize(...)
    def browser_launch_options
    def browser_context_options

    private
    def validate!
    def ensure_directories_exist
  end
end
```

**Acceptance Criteria**:
- [ ] for_environment returns correct config for test, development, CI
- [ ] CI config always uses headless=true
- [ ] Development config uses headless=false and slow_mo=500
- [ ] Configuration validates browser_type (chromium, firefox, webkit)
- [ ] Configuration validates trace_mode (on, off, on-first-retry)
- [ ] Configuration creates artifact directories on initialization
- [ ] Environment variables override defaults (PLAYWRIGHT_BROWSER, etc.)
- [ ] No Rails dependencies used
- [ ] Class documented with YARD comments

**Testing Requirements**:
- Unit tests for each configuration preset
- Tests for validation (invalid browser_type, trace_mode)
- Tests for environment variable overrides
- Tests for directory creation

**Risks**:
- **Risk**: Directory creation fails due to permissions
- **Mitigation**: Use FileUtils.mkdir_p (creates parent directories)

---

#### TASK-2.4: Create PlaywrightDriver Implementation
**Worker**: backend-worker-v1-self-adapting
**Duration**: 45 minutes
**Dependencies**: [TASK-2.2, TASK-2.3]

**Description**: Implement Playwright-specific driver using BrowserDriver interface.

**Files to Create**:
- `lib/testing/playwright_driver.rb`

**Implementation Requirements**:
- Inherit from BrowserDriver
- Initialize Playwright instance in constructor
- Implement all abstract methods using playwright-ruby-client API
- Handle Playwright gem not installed error with helpful message
- Use config.browser_type to select chromium/firefox/webkit
- Implement full_page screenshot capture
- Implement trace capture with screenshots, snapshots, sources

**Code Structure**:
```ruby
module Testing
  class PlaywrightDriver < BrowserDriver
    def initialize
      require 'playwright'
      @playwright = Playwright.create(playwright_cli_executable_path: 'npx playwright')
    rescue LoadError => e
      raise LoadError, "Playwright gem not installed..."
    end

    def launch_browser(config)
    def close_browser(browser)
    def create_context(browser, config)
    def take_screenshot(page, path)
    def start_trace(context)
    def stop_trace(context, path)
  end
end
```

**Acceptance Criteria**:
- [ ] Playwright instance created with npx playwright path
- [ ] Browser launches with correct config options
- [ ] Browser closes cleanly
- [ ] Context created with viewport and video settings
- [ ] Screenshot captures full page
- [ ] Trace captures screenshots, snapshots, sources
- [ ] Helpful error message if Playwright not installed
- [ ] Class documented with YARD comments

**Testing Requirements**:
- Integration tests with real Playwright browser (in test mode)
- Tests for browser launch/close lifecycle
- Tests for screenshot capture
- Tests for trace capture
- Mock tests for LoadError handling

**Risks**:
- **Risk**: Playwright browsers not installed
- **Mitigation**: Clear error message with installation instructions

---

#### TASK-2.5: Create Unit Tests for Playwright Configuration and Driver
**Worker**: test-worker-v1-self-adapting
**Duration**: 1 hour
**Dependencies**: [TASK-2.3, TASK-2.4]

**Description**: Implement comprehensive tests for Playwright configuration and driver.

**Files to Create**:
- `spec/lib/testing/playwright_configuration_spec.rb`
- `spec/lib/testing/browser_driver_spec.rb`
- `spec/lib/testing/playwright_driver_spec.rb`

**Test Coverage Requirements**:
- PlaywrightConfiguration: All configuration presets, validation, environment detection
- BrowserDriver: NotImplementedError for all abstract methods
- PlaywrightDriver: Browser lifecycle, screenshot, trace (integration tests)

**Acceptance Criteria**:
- [ ] PlaywrightConfiguration has ≥95% code coverage
- [ ] BrowserDriver has 100% code coverage
- [ ] PlaywrightDriver has ≥90% code coverage (integration tests)
- [ ] Tests verify CI vs local vs development configs
- [ ] Tests verify environment variable overrides
- [ ] All tests pass

**Testing Requirements**:
- Minimum 95% code coverage
- Use RSpec with proper describe/context blocks
- Integration tests run real Playwright browser (headless)

**Risks**:
- **Risk**: Integration tests flaky on CI
- **Mitigation**: Use proper timeout and retry mechanisms

---

### Phase 3: Artifact Storage and Capture (2-3 hours)

#### TASK-3.1: Create ArtifactStorage Interface
**Worker**: backend-worker-v1-self-adapting
**Duration**: 30 minutes
**Dependencies**: None

**Description**: Implement abstract interface for artifact storage to enable future cloud storage integration.

**Files to Create**:
- `lib/testing/artifact_storage.rb`

**Implementation Requirements**:
- Define abstract methods: save_screenshot, save_trace, list_artifacts, get_artifact, delete_artifact
- All methods raise NotImplementedError
- Used as base class for FileSystemStorage and potential cloud storage

**Code Structure**:
```ruby
module Testing
  class ArtifactStorage
    def save_screenshot(name, file_path, metadata = {})
    def save_trace(name, file_path, metadata = {})
    def list_artifacts
    def get_artifact(name)
    def delete_artifact(name)
  end
end
```

**Acceptance Criteria**:
- [ ] All abstract methods defined
- [ ] Methods raise NotImplementedError
- [ ] Interface documented with YARD comments
- [ ] Parameter types and return values documented

**Testing Requirements**:
- Unit tests verifying NotImplementedError is raised

**Risks**: None

---

#### TASK-3.2: Create FileSystemStorage Implementation
**Worker**: backend-worker-v1-self-adapting
**Duration**: 1 hour
**Dependencies**: [TASK-3.1, TASK-1.1, TASK-1.3, TASK-1.4] (needs PathUtils, TimeUtils, StringUtils)

**Description**: Implement filesystem-based artifact storage with metadata support.

**Files to Create**:
- `lib/testing/file_system_storage.rb`

**Implementation Requirements**:
- Inherit from ArtifactStorage
- Use PathUtils.tmp_path as default base path
- Use StringUtils.sanitize_filename for safe filenames
- Save metadata as JSON files alongside artifacts (filename.metadata.json)
- Create separate directories for screenshots and traces
- Implement list_artifacts to return all screenshots and traces
- Implement get_artifact to read binary files
- Implement delete_artifact to remove file and metadata

**Code Structure**:
```ruby
module Testing
  class FileSystemStorage < ArtifactStorage
    attr_reader :base_path

    def initialize(base_path: Utils::PathUtils.tmp_path)
    def save_screenshot(name, file_path, metadata = {})
    def save_trace(name, file_path, metadata = {})
    def list_artifacts
    def get_artifact(name)
    def delete_artifact(name)

    private
    def screenshots_path
    def traces_path
    def save_metadata(artifact_path, metadata)
    def ensure_directories_exist
  end
end
```

**Acceptance Criteria**:
- [ ] Screenshots saved to tmp/screenshots/ with sanitized filenames
- [ ] Traces saved to tmp/traces/ with sanitized filenames
- [ ] Metadata saved as .metadata.json alongside artifacts
- [ ] list_artifacts returns sorted list of all artifacts
- [ ] get_artifact reads binary file contents
- [ ] delete_artifact removes file and metadata
- [ ] Directories created automatically if missing
- [ ] Class documented with YARD comments

**Testing Requirements**:
- Unit tests for save/get/delete operations
- Tests for metadata persistence
- Tests for directory creation
- Tests for filename sanitization

**Risks**:
- **Risk**: Disk space exhaustion
- **Mitigation**: Document artifact cleanup strategy in README

---

#### TASK-3.3: Create PlaywrightArtifactCapture Service
**Worker**: backend-worker-v1-self-adapting
**Duration**: 1 hour
**Dependencies**: [TASK-2.4, TASK-3.2, TASK-1.3] (needs PlaywrightDriver, FileSystemStorage, TimeUtils)

**Description**: Implement artifact capture service for screenshots and traces with correlation IDs.

**Files to Create**:
- `lib/testing/playwright_artifact_capture.rb`

**Implementation Requirements**:
- Accept injected driver, storage, logger (no Rails dependencies)
- Use TimeUtils.generate_correlation_id for artifact naming
- capture_screenshot: Take screenshot on test failure with metadata
- capture_trace: Start/stop trace with configurable mode
- Structured logging with correlation IDs
- Support for test metadata (test name, file location, example ID)

**Code Structure**:
```ruby
module Testing
  class PlaywrightArtifactCapture
    attr_reader :driver, :storage, :logger

    def initialize(driver:, storage:, logger: Utils::NullLogger.new)
    def capture_screenshot(page, test_name:, metadata: {})
    def capture_trace(context, test_name:, trace_mode:, metadata: {}, &block)

    private
    def generate_artifact_name(test_name)
    def log_artifact_saved(type, path, metadata)
  end
end
```

**Acceptance Criteria**:
- [ ] Screenshot captured with correlation ID in filename
- [ ] Screenshot metadata includes test name, timestamp, example ID
- [ ] Trace captured with correlation ID in filename
- [ ] Trace mode supports: on, off, on-first-retry
- [ ] Logger receives structured log messages
- [ ] NullLogger used as default (no Rails.logger dependency)
- [ ] Class documented with YARD comments

**Testing Requirements**:
- Unit tests with mocked driver and storage
- Integration tests with real Playwright
- Tests for correlation ID generation
- Tests for metadata structure

**Risks**:
- **Risk**: Large trace files consume disk space
- **Mitigation**: Document trace retention policy

---

#### TASK-3.4: Create Unit Tests for Artifact Storage and Capture
**Worker**: test-worker-v1-self-adapting
**Duration**: 1 hour
**Dependencies**: [TASK-3.2, TASK-3.3]

**Description**: Implement comprehensive tests for artifact storage and capture.

**Files to Create**:
- `spec/lib/testing/artifact_storage_spec.rb`
- `spec/lib/testing/file_system_storage_spec.rb`
- `spec/lib/testing/playwright_artifact_capture_spec.rb`

**Test Coverage Requirements**:
- ArtifactStorage: NotImplementedError for all abstract methods
- FileSystemStorage: Save/get/delete operations, metadata persistence
- PlaywrightArtifactCapture: Screenshot/trace capture, correlation IDs

**Acceptance Criteria**:
- [ ] ArtifactStorage has 100% code coverage
- [ ] FileSystemStorage has ≥95% code coverage
- [ ] PlaywrightArtifactCapture has ≥90% code coverage
- [ ] Tests use temporary directories (cleaned up after)
- [ ] Tests verify metadata structure
- [ ] All tests pass

**Testing Requirements**:
- Minimum 95% code coverage
- Use temporary directories for file tests
- Clean up test artifacts after each test

**Risks**:
- **Risk**: Test artifacts not cleaned up
- **Mitigation**: Use RSpec after(:each) hooks for cleanup

---

### Phase 4: Retry Policy and Browser Session (2-3 hours)

#### TASK-4.1: Create RetryPolicy Class
**Worker**: backend-worker-v1-self-adapting
**Duration**: 45 minutes
**Dependencies**: [TASK-1.5] (needs NullLogger)

**Description**: Implement configurable retry mechanism with exponential backoff for transient failures.

**Files to Create**:
- `lib/testing/retry_policy.rb`

**Implementation Requirements**:
- Configurable max retry attempts (default: 3)
- Exponential backoff: 2s, 4s, 8s
- Configurable error types (not hardcoded to RSpec)
- Skip retry for assertion failures (Minitest::Assertion, RSpec::Expectations::ExpectationNotMetError)
- Log each retry attempt with structured output
- Use injected logger (default: NullLogger)

**Code Structure**:
```ruby
module Testing
  class RetryPolicy
    DEFAULT_MAX_ATTEMPTS = 3
    DEFAULT_BACKOFF_MULTIPLIER = 2
    DEFAULT_INITIAL_DELAY = 2

    attr_reader :max_attempts, :backoff_multiplier, :initial_delay, :logger,
                :retryable_errors, :non_retryable_errors

    def initialize(max_attempts:, backoff_multiplier:, initial_delay:,
                   logger:, retryable_errors:, non_retryable_errors:)
    def execute(&block)

    private
    def calculate_delay(attempt)
    def retryable_error?(error)
    def log_retry_attempt(attempt, error)
  end
end
```

**Acceptance Criteria**:
- [ ] Retries transient errors up to max_attempts
- [ ] Does not retry assertion failures
- [ ] Exponential backoff: 2s, 4s, 8s (configurable)
- [ ] Logs each retry attempt with error details
- [ ] Works with RSpec, Minitest, and standalone Ruby
- [ ] Class documented with YARD comments

**Testing Requirements**:
- Unit tests for retry logic
- Tests for backoff calculation
- Tests for retryable vs non-retryable errors
- Tests for logging

**Risks**:
- **Risk**: Infinite retry loops
- **Mitigation**: Hard cap at max_attempts

---

#### TASK-4.2: Create PlaywrightBrowserSession Class
**Worker**: backend-worker-v1-self-adapting
**Duration**: 1.5 hours
**Dependencies**: [TASK-2.4, TASK-3.3, TASK-4.1] (needs PlaywrightDriver, PlaywrightArtifactCapture, RetryPolicy)

**Description**: Implement framework-agnostic browser session manager with retry support.

**Files to Create**:
- `lib/testing/playwright_browser_session.rb`

**Implementation Requirements**:
- Accept injected driver, config, artifact_capture, retry_policy
- Manage browser lifecycle: start, stop, restart
- Manage context lifecycle: create_context, close_context
- Session isolation for concurrent tests (separate contexts)
- Framework-agnostic test execution wrapper (works outside RSpec)
- Automatic cleanup on session end
- Error handling with retry support

**Code Structure**:
```ruby
module Testing
  class PlaywrightBrowserSession
    attr_reader :driver, :config, :artifact_capture, :retry_policy, :browser, :context

    def initialize(driver:, config:, artifact_capture:, retry_policy:)
    def start
    def stop
    def restart
    def create_context
    def close_context
    def execute_with_retry(test_name:, &block)

    private
    def ensure_browser_started
    def cleanup
  end
end
```

**Acceptance Criteria**:
- [ ] Browser starts with correct configuration
- [ ] Browser stops cleanly (closes all contexts)
- [ ] Context created with isolation (separate storage, cookies)
- [ ] execute_with_retry retries transient failures
- [ ] Captures screenshot/trace on failure (via artifact_capture)
- [ ] Works in RSpec, Minitest, and standalone Ruby
- [ ] Automatic cleanup on stop
- [ ] Class documented with YARD comments

**Testing Requirements**:
- Integration tests with real Playwright browser
- Tests for browser/context lifecycle
- Tests for retry mechanism
- Tests for cleanup

**Risks**:
- **Risk**: Browser processes not cleaned up
- **Mitigation**: Ensure stop method called in ensure block

---

#### TASK-4.3: Create Unit Tests for Retry Policy and Browser Session
**Worker**: test-worker-v1-self-adapting
**Duration**: 1.5 hours
**Dependencies**: [TASK-4.1, TASK-4.2]

**Description**: Implement comprehensive tests for retry policy and browser session.

**Files to Create**:
- `spec/lib/testing/retry_policy_spec.rb`
- `spec/lib/testing/playwright_browser_session_spec.rb`

**Test Coverage Requirements**:
- RetryPolicy: Retry logic, backoff calculation, error filtering
- PlaywrightBrowserSession: Browser lifecycle, context isolation, retry integration

**Acceptance Criteria**:
- [ ] RetryPolicy has ≥95% code coverage
- [ ] PlaywrightBrowserSession has ≥90% code coverage
- [ ] Tests verify retry attempts and backoff
- [ ] Tests verify browser cleanup
- [ ] Integration tests run real Playwright browser
- [ ] All tests pass

**Testing Requirements**:
- Minimum 95% code coverage
- Integration tests with real browser (headless)
- Mock tests for error scenarios

**Risks**:
- **Risk**: Browser processes leak in tests
- **Mitigation**: Use RSpec after(:each) to ensure cleanup

---

### Phase 5: RSpec Integration and System Spec Updates (1-2 days)

#### TASK-5.1: Update Capybara Configuration for Playwright
**Worker**: backend-worker-v1-self-adapting
**Duration**: 1 hour
**Dependencies**: [TASK-2.4, TASK-2.3, TASK-3.2, TASK-3.3]

**Description**: Update Capybara configuration to use Playwright driver instead of Selenium.

**Files to Modify**:
- `spec/support/capybara.rb`

**Implementation Requirements**:
- Register :playwright driver using Capybara.register_driver
- Use PlaywrightConfiguration.for_environment for config
- Initialize PlaywrightDriver, FileSystemStorage, PlaywrightArtifactCapture
- Set driven_by :playwright in system specs
- Configure screenshot directory
- Remove Selenium driver configuration

**Code Structure**:
```ruby
# spec/support/capybara.rb

require 'testing/playwright_configuration'
require 'testing/playwright_driver'
require 'testing/file_system_storage'
require 'testing/playwright_artifact_capture'

RSpec.configure do |config|
  config.before(:each, type: :system) do
    # Initialize Playwright components
    playwright_config = Testing::PlaywrightConfiguration.for_environment
    playwright_driver = Testing::PlaywrightDriver.new

    # Register Playwright driver with Capybara
    Capybara.register_driver :playwright do |app|
      # ... driver setup
    end

    driven_by :playwright, screen_size: [1920, 1080]
  end
end
```

**Acceptance Criteria**:
- [ ] :playwright driver registered with Capybara
- [ ] Selenium driver removed from configuration
- [ ] Screenshot directory configured
- [ ] Environment-specific configuration applied (CI vs local)
- [ ] No Rails-specific dependencies in driver setup
- [ ] Configuration commented and documented

**Testing Requirements**:
- Manual test: Run existing system specs with Playwright
- Verify screenshots saved on failure

**Risks**:
- **Risk**: Capybara API incompatible with Playwright
- **Mitigation**: Use capybara-playwright-driver gem if needed

---

#### TASK-5.2: Create RSpec Playwright Helpers
**Worker**: backend-worker-v1-self-adapting
**Duration**: 45 minutes
**Dependencies**: [TASK-4.2, TASK-3.3]

**Description**: Create RSpec helper methods for common Playwright operations.

**Files to Create**:
- `spec/support/playwright_helpers.rb`

**Implementation Requirements**:
- Helper methods for screenshot capture, trace capture, page inspection
- Helper methods for waiting (wait_for_selector, wait_for_url)
- Helper methods for debugging (pause, inspect_state)
- Integration with PlaywrightBrowserSession
- RSpec metadata hooks for automatic artifact capture

**Code Structure**:
```ruby
# spec/support/playwright_helpers.rb

module PlaywrightHelpers
  def capture_screenshot(name)
  def start_trace
  def stop_trace(name)
  def wait_for_selector(selector, timeout: 30000)
  def wait_for_url(url_pattern, timeout: 30000)
  def pause_for_debugging
  def inspect_page_state
end

RSpec.configure do |config|
  config.include PlaywrightHelpers, type: :system

  # Automatic screenshot on failure
  config.after(:each, type: :system) do |example|
    if example.exception
      capture_screenshot(example.description)
    end
  end
end
```

**Acceptance Criteria**:
- [ ] Helper methods available in system specs
- [ ] Automatic screenshot on test failure
- [ ] Helper methods documented with examples
- [ ] Integration with PlaywrightBrowserSession
- [ ] No global state (thread-safe)

**Testing Requirements**:
- Integration tests using helpers in system specs
- Verify screenshot capture on failure

**Risks**:
- **Risk**: Helper methods conflict with existing RSpec helpers
- **Mitigation**: Use unique method names with playwright_ prefix

---

#### TASK-5.3: Update Existing System Specs to Use Playwright
**Worker**: backend-worker-v1-self-adapting
**Duration**: 2-3 hours
**Dependencies**: [TASK-5.1, TASK-5.2]

**Description**: Update all 7 existing system specs to use Playwright driver and remove Selenium dependencies.

**Files to Modify**:
- All files in `spec/system/` (7 system spec files)

**Changes Required**:
- Remove Selenium-specific code (if any)
- Verify Capybara DSL works with Playwright
- Update wait conditions if needed (Playwright has better auto-wait)
- Test all user flows (login, CRUD operations, etc.)
- Verify screenshots captured on failure

**Acceptance Criteria**:
- [ ] All 7 system specs pass with Playwright driver
- [ ] No Selenium dependencies remain
- [ ] Screenshots captured on failure
- [ ] Test execution time ≤ 2 minutes for all system specs
- [ ] No flaky tests (run 5 times without failures)

**Testing Requirements**:
- Run all system specs 5 times to verify stability
- Verify screenshot artifacts created on failure
- Compare execution time with Selenium baseline

**Risks**:
- **Risk**: Capybara DSL incompatible with Playwright
- **Mitigation**: Use capybara-playwright-driver gem for compatibility layer

---

#### TASK-5.4: Configure SimpleCov for CI Environment
**Worker**: backend-worker-v1-self-adapting
**Duration**: 30 minutes
**Dependencies**: [TASK-5.3]

**Description**: Update SimpleCov configuration for CI environment with proper thresholds.

**Files to Modify**:
- `spec/spec_helper.rb` or `spec/rails_helper.rb`

**Implementation Requirements**:
- Enable SimpleCov in test environment
- Set minimum coverage threshold: 88% (as per existing config)
- Configure coverage output format (HTML + JSON)
- Exclude vendor, spec, config directories from coverage
- CI-specific configuration (fail build if coverage drops)

**Code Structure**:
```ruby
# spec/spec_helper.rb or spec/rails_helper.rb

if ENV['CI'] == 'true' || ENV['COVERAGE'] == 'true'
  require 'simplecov'
  require 'simplecov-console'

  SimpleCov.start 'rails' do
    minimum_coverage 88
    add_filter '/vendor/'
    add_filter '/spec/'
    add_filter '/config/'

    formatter SimpleCov::Formatter::MultiFormatter.new([
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::Console
    ])
  end
end
```

**Acceptance Criteria**:
- [ ] SimpleCov runs in CI environment (CI=true)
- [ ] Coverage threshold set to 88%
- [ ] HTML report generated to coverage/
- [ ] Build fails if coverage < 88%
- [ ] Coverage report includes all specs (unit + integration + system)

**Testing Requirements**:
- Run specs locally with COVERAGE=true
- Verify coverage report generated
- Verify threshold enforcement

**Risks**:
- **Risk**: Coverage drops below 88% with new code
- **Mitigation**: Write unit tests for all new components (Phases 1-4)

---

#### TASK-5.5: Create Integration Tests for RSpec-Playwright Integration
**Worker**: test-worker-v1-self-adapting
**Duration**: 2 hours
**Dependencies**: [TASK-5.1, TASK-5.2, TASK-5.3]

**Description**: Create integration tests verifying RSpec and Playwright work together correctly.

**Files to Create**:
- `spec/integration/playwright_integration_spec.rb`

**Test Coverage Requirements**:
- Driver registration and initialization
- Screenshot capture on failure
- Trace capture (if enabled)
- Artifact storage and retrieval
- Retry mechanism in system specs
- Environment-specific configuration (CI vs local)

**Acceptance Criteria**:
- [ ] Integration tests verify Capybara-Playwright integration
- [ ] Tests verify screenshot capture on failure
- [ ] Tests verify artifact metadata
- [ ] Tests run in CI environment
- [ ] All integration tests pass

**Testing Requirements**:
- Run integration tests with real Playwright browser
- Verify artifacts created in tmp/ directory
- Test both success and failure scenarios

**Risks**:
- **Risk**: Integration tests flaky
- **Mitigation**: Use proper wait conditions and timeouts

---

### Phase 6: GitHub Actions Workflow (1 day)

#### TASK-6.1: Create GitHub Actions RSpec Workflow
**Worker**: backend-worker-v1-self-adapting
**Duration**: 1.5 hours
**Dependencies**: [TASK-2.1, TASK-5.4]

**Description**: Create GitHub Actions workflow for automated RSpec test execution.

**Files to Create**:
- `.github/workflows/rspec.yml`

**Implementation Requirements**:
- Trigger on push to main/develop and pull requests
- Set up Ruby 3.4.6 with bundler cache
- Set up Node.js 20 for asset building
- Set up MySQL 8.0 service container
- Install Playwright browsers (chromium with deps)
- Run database migrations
- Build assets (JavaScript + CSS)
- Run RSpec with coverage
- Upload artifacts: screenshots, traces, coverage

**Workflow Structure**:
```yaml
name: RSpec Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  rspec:
    runs-on: ubuntu-latest

    services:
      mysql:
        image: mysql:8.0
        env:
          MYSQL_ROOT_PASSWORD: password
          MYSQL_DATABASE: test_db
        ports:
          - 3306:3306
        options: --health-cmd="mysqladmin ping" ...

    steps:
      - Checkout code
      - Set up Ruby
      - Set up Node.js
      - Install dependencies
      - Install Playwright browsers
      - Set up database
      - Build assets
      - Run RSpec tests
      - Upload screenshots (on failure)
      - Upload traces (on failure)
      - Upload coverage report
```

**Acceptance Criteria**:
- [ ] Workflow triggers on push to main/develop
- [ ] Workflow triggers on pull requests
- [ ] MySQL 8.0 service container configured
- [ ] Ruby 3.4.6 installed with bundler cache
- [ ] Node.js 20 installed
- [ ] Playwright chromium installed with system dependencies
- [ ] Database migrations run successfully
- [ ] Assets built successfully
- [ ] RSpec runs all specs (unit + integration + system)
- [ ] Artifacts uploaded on failure (screenshots, traces)
- [ ] Coverage report uploaded on success
- [ ] Workflow documented with comments

**Testing Requirements**:
- Push test commit to verify workflow runs
- Verify MySQL connection works
- Verify Playwright browser launches
- Verify artifacts uploaded on failure

**Risks**:
- **Risk**: Playwright installation fails in CI
- **Mitigation**: Use npx playwright install chromium --with-deps

---

#### TASK-6.2: Update Docker Configuration for Playwright
**Worker**: backend-worker-v1-self-adapting
**Duration**: 1 hour
**Dependencies**: [TASK-2.1]

**Description**: Update Dockerfile to support Playwright browser automation.

**Files to Modify**:
- `Dockerfile`

**Changes Required**:
- Install Playwright system dependencies (libnss3, libatk-bridge2.0-0, etc.)
- Install Playwright browsers (chromium) in Docker image
- Ensure headless mode works in container
- Optimize image size (multi-stage build if needed)

**Implementation**:
```dockerfile
FROM ruby:3.4.6-slim

# Install system dependencies including Playwright requirements
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    default-libmysqlclient-dev \
    nodejs \
    npm \
    # Playwright dependencies
    libnss3 \
    libatk-bridge2.0-0 \
    libdrm2 \
    libxkbcommon0 \
    libgbm1 \
    libasound2 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Ruby and Node dependencies
COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY package.json package-lock.json ./
RUN npm install

# Install Playwright browsers
RUN npx playwright install chromium --with-deps

# Copy application code
COPY . .

# Build assets
RUN npm run build && npm run build:css

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
```

**Acceptance Criteria**:
- [ ] Playwright system dependencies installed
- [ ] Playwright chromium browser installed in image
- [ ] Docker image builds successfully
- [ ] RSpec system specs run in Docker container
- [ ] Headless mode works in container
- [ ] Image size ≤ 2GB

**Testing Requirements**:
- Build Docker image locally
- Run system specs in Docker container
- Verify screenshot capture works

**Risks**:
- **Risk**: Large Docker image size
- **Mitigation**: Use --no-install-recommends and clean apt cache

---

#### TASK-6.3: Test GitHub Actions Workflow End-to-End
**Worker**: test-worker-v1-self-adapting
**Duration**: 2 hours
**Dependencies**: [TASK-6.1, TASK-6.2, TASK-5.3]

**Description**: Verify GitHub Actions workflow runs successfully from start to finish.

**Testing Plan**:
1. Push test commit to trigger workflow
2. Monitor workflow execution in GitHub Actions UI
3. Verify all steps complete successfully
4. Verify test results and coverage
5. Verify artifact uploads (screenshots, traces, coverage)
6. Trigger failure scenario and verify artifacts

**Acceptance Criteria**:
- [ ] Workflow completes successfully on clean run
- [ ] All RSpec specs pass (unit + integration + system)
- [ ] Coverage ≥ 88%
- [ ] Total execution time ≤ 5 minutes
- [ ] Screenshots uploaded on failure
- [ ] Traces uploaded on failure
- [ ] Coverage report uploaded
- [ ] No flaky tests (run 3 times without failures)

**Testing Requirements**:
- Run workflow 3 times to verify stability
- Introduce intentional failure to verify artifact upload
- Download and inspect artifacts

**Risks**:
- **Risk**: Workflow times out (exceeds 6 hours)
- **Mitigation**: Optimize asset building and test execution

---

### Phase 7: Documentation and Verification (1 day)

#### TASK-7.1: Update README with Setup Instructions
**Worker**: backend-worker-v1-self-adapting
**Duration**: 1.5 hours
**Dependencies**: [TASK-6.3]

**Description**: Update README.md with comprehensive setup and usage instructions.

**Files to Modify**:
- `README.md`

**Sections to Add/Update**:
- Local development setup (Playwright installation)
- Running tests locally (RSpec with Playwright)
- Environment variables (PLAYWRIGHT_BROWSER, PLAYWRIGHT_HEADLESS, etc.)
- Docker setup and testing
- CI/CD pipeline overview
- Troubleshooting guide
- Artifact location (screenshots, traces, coverage)

**Content Structure**:
```markdown
## Testing

### Local Setup

1. Install Playwright browsers:
   ```bash
   bundle install
   npx playwright install chromium --with-deps
   ```

2. Run all tests:
   ```bash
   bundle exec rspec
   ```

3. Run system specs only:
   ```bash
   bundle exec rspec spec/system
   ```

### Environment Variables

- `PLAYWRIGHT_BROWSER`: Browser type (chromium, firefox, webkit) [default: chromium]
- `PLAYWRIGHT_HEADLESS`: Headless mode (true/false) [default: true]
- `PLAYWRIGHT_SLOW_MO`: Slow down execution in ms [default: 0]
- `PLAYWRIGHT_TRACE_MODE`: Trace capture mode (on, off, on-first-retry) [default: off]

### Docker

1. Build and run tests in Docker:
   ```bash
   docker-compose up --build
   docker-compose exec web bundle exec rspec
   ```

### CI/CD

GitHub Actions runs all tests automatically on push and pull requests.
- View workflow: .github/workflows/rspec.yml
- Test artifacts: Screenshots, traces, coverage reports

### Troubleshooting

**Playwright browsers not installed:**
```bash
npx playwright install chromium --with-deps
```

**Tests fail in headless mode:**
```bash
PLAYWRIGHT_HEADLESS=false bundle exec rspec spec/system
```
```

**Acceptance Criteria**:
- [ ] README includes local setup instructions
- [ ] README includes environment variable documentation
- [ ] README includes Docker instructions
- [ ] README includes CI/CD overview
- [ ] README includes troubleshooting section
- [ ] README includes artifact location

**Testing Requirements**:
- Follow setup instructions on fresh machine to verify accuracy
- Verify all commands work as documented

**Risks**: None

---

#### TASK-7.2: Create TESTING.md Guide
**Worker**: backend-worker-v1-self-adapting
**Duration**: 2 hours
**Dependencies**: [TASK-7.1]

**Description**: Create comprehensive testing guide with framework-agnostic usage examples.

**Files to Create**:
- `TESTING.md`

**Content Requirements**:
- Overview of testing architecture
- Utility libraries documentation (PathUtils, EnvUtils, TimeUtils, StringUtils)
- Playwright configuration guide
- Artifact storage and capture guide
- RSpec integration guide
- Framework-agnostic usage examples (Sinatra, Hanami, pure Ruby)
- Best practices and patterns
- Advanced topics (retry policy, custom drivers, cloud storage)

**Content Structure**:
```markdown
# Testing Guide

## Overview

This guide explains the testing infrastructure and how to use it in different contexts.

## Architecture

- **Utility Libraries**: Framework-agnostic helpers (PathUtils, EnvUtils, etc.)
- **Playwright Integration**: Browser automation with Playwright
- **Artifact Management**: Screenshot and trace capture
- **Retry Policy**: Transient failure handling

## Utility Libraries

### PathUtils

Provides framework-agnostic path management...

### EnvUtils

Provides environment detection...

## Framework-Agnostic Usage

### Sinatra Application

```ruby
# test/test_helper.rb
require 'testing/playwright_browser_session'
...
```

### Minitest Integration

...

### Standalone Ruby Script

...

## Best Practices

- Use dependency injection
- Avoid global state
- Clean up resources
- Use structured logging

## Advanced Topics

### Custom Browser Drivers

...

### Cloud Storage Integration

...
```

**Acceptance Criteria**:
- [ ] TESTING.md includes architecture overview
- [ ] TESTING.md documents all utility libraries
- [ ] TESTING.md includes framework-agnostic examples
- [ ] TESTING.md includes Sinatra/Minitest examples
- [ ] TESTING.md includes best practices
- [ ] TESTING.md includes advanced topics
- [ ] All code examples are tested and working

**Testing Requirements**:
- Verify all code examples run successfully
- Test examples in different frameworks (Sinatra, Minitest)

**Risks**: None

---

#### TASK-7.3: Add YARD Documentation to All Classes
**Worker**: backend-worker-v1-self-adapting
**Duration**: 2 hours
**Dependencies**: [TASK-1.6, TASK-2.5, TASK-3.4, TASK-4.3]

**Description**: Add comprehensive YARD documentation to all classes and modules.

**Files to Update**:
- All files in `lib/testing/` (utilities, drivers, configuration, storage, etc.)

**Documentation Requirements**:
- Class-level documentation with purpose and usage examples
- Method-level documentation with parameters, return types, examples
- @param, @return, @raise, @example tags
- @see tags for related classes
- @since tags for versioning

**Example**:
```ruby
module Testing
  module Utils
    # Provides framework-agnostic path management utilities.
    #
    # Works with or without Rails, using Rails.root when available
    # and Dir.pwd otherwise.
    #
    # @example Basic usage
    #   PathUtils.root_path #=> #<Pathname:/path/to/project>
    #   PathUtils.screenshots_path #=> #<Pathname:/path/to/project/tmp/screenshots>
    #
    # @example Custom root path
    #   PathUtils.root_path = '/custom/path'
    #   PathUtils.tmp_path #=> #<Pathname:/custom/path/tmp>
    #
    # @since 1.0.0
    module PathUtils
      # Get project root path (works with or without Rails).
      #
      # @return [Pathname] Project root path
      # @example
      #   PathUtils.root_path #=> #<Pathname:/path/to/project>
      def self.root_path
        # ...
      end
    end
  end
end
```

**Acceptance Criteria**:
- [ ] All classes documented with YARD
- [ ] All public methods documented with @param, @return
- [ ] All modules documented with usage examples
- [ ] YARD documentation generates without warnings
- [ ] Generated HTML documentation is readable

**Testing Requirements**:
- Run `yard doc` to generate documentation
- Verify no YARD warnings or errors
- Review generated HTML documentation

**Risks**: None

---

#### TASK-7.4: Create Usage Examples
**Worker**: backend-worker-v1-self-adapting
**Duration**: 2 hours
**Dependencies**: [TASK-7.2, TASK-7.3]

**Description**: Create working code examples for different frameworks and use cases.

**Files to Create**:
- `examples/sinatra_example.rb`
- `examples/minitest_example.rb`
- `examples/standalone_example.rb`
- `examples/custom_driver_example.rb`
- `examples/cloud_storage_example.rb`

**Example Requirements**:
- Sinatra: Complete test setup with Minitest
- Minitest: System test with Playwright
- Standalone: Browser automation script
- Custom driver: Implementing BrowserDriver interface
- Cloud storage: Implementing ArtifactStorage for S3

**Code Structure**:
```ruby
# examples/sinatra_example.rb

require 'bundler/setup'
require 'sinatra'
require 'minitest/autorun'
require 'testing/playwright_browser_session'
require 'testing/playwright_configuration'
require 'testing/playwright_driver'

class MyApp < Sinatra::Base
  get '/' do
    'Hello, World!'
  end
end

class SinatraSystemTest < Minitest::Test
  def setup
    @config = Testing::PlaywrightConfiguration.for_environment('test')
    @driver = Testing::PlaywrightDriver.new
    @session = Testing::PlaywrightBrowserSession.new(
      driver: @driver,
      config: @config,
      artifact_capture: Testing::PlaywrightArtifactCapture.new(driver: @driver),
      retry_policy: Testing::RetryPolicy.new(max_attempts: 3)
    )
    @session.start
  end

  def teardown
    @session.stop
  end

  def test_homepage
    @session.execute_with_retry(test_name: 'homepage') do
      page = @session.context.new_page
      page.goto('http://localhost:4567')
      assert_equal 'Hello, World!', page.text_content('body')
    end
  end
end
```

**Acceptance Criteria**:
- [ ] All examples run successfully
- [ ] Examples demonstrate different frameworks
- [ ] Examples demonstrate different use cases
- [ ] Examples are well-commented
- [ ] Examples include README with setup instructions

**Testing Requirements**:
- Run each example to verify it works
- Test on fresh environment (no existing setup)

**Risks**:
- **Risk**: Examples become outdated
- **Mitigation**: Include examples in automated tests

---

#### TASK-7.5: Final Verification and Cleanup
**Worker**: test-worker-v1-self-adapting
**Duration**: 2 hours
**Dependencies**: [TASK-7.1, TASK-7.2, TASK-7.3, TASK-7.4, TASK-6.3]

**Description**: Perform final end-to-end verification and cleanup.

**Verification Checklist**:
1. All RSpec specs pass (unit + integration + system)
2. Coverage ≥ 88%
3. GitHub Actions workflow passes
4. Docker tests pass
5. Local tests pass (headless and headed mode)
6. All documentation accurate and up-to-date
7. No TODOs or FIXMEs in code
8. No commented-out code
9. All dependencies documented in Gemfile
10. All environment variables documented

**Cleanup Tasks**:
- Remove unused code
- Remove debug statements
- Remove unused dependencies
- Clean up test artifacts
- Update .gitignore for new artifacts
- Verify branch is clean (no uncommitted changes)

**Acceptance Criteria**:
- [ ] All RSpec specs pass locally
- [ ] All RSpec specs pass in GitHub Actions
- [ ] All RSpec specs pass in Docker
- [ ] Coverage ≥ 88%
- [ ] No RuboCop violations
- [ ] No security vulnerabilities (bundle audit)
- [ ] Documentation complete and accurate
- [ ] No TODOs or FIXMEs
- [ ] Clean git status

**Testing Requirements**:
- Run full test suite locally
- Run tests in Docker
- Trigger GitHub Actions workflow
- Run RuboCop
- Run bundle audit

**Risks**: None

---

## 3. Execution Sequence

### Phase 1: Framework-Agnostic Utility Libraries (2-3 hours)
**Parallel Opportunities**: TASK-1.1, TASK-1.2, TASK-1.3, TASK-1.4, TASK-1.5 (5 tasks)
- TASK-1.1: PathUtils
- TASK-1.2: EnvUtils (parallel)
- TASK-1.3: TimeUtils (parallel)
- TASK-1.4: StringUtils (parallel)
- TASK-1.5: NullLogger (parallel)
- TASK-1.6: Unit tests (depends on all above)

**Critical**: Must complete before Phase 2 and 3

---

### Phase 2: Playwright Configuration and Driver (2-3 hours)
**Parallel Opportunities**: TASK-2.1, TASK-2.2 (2 tasks)
- TASK-2.1: Update Gemfile and install Playwright
- TASK-2.2: BrowserDriver interface (parallel)
- TASK-2.3: PlaywrightConfiguration (depends on PathUtils, EnvUtils)
- TASK-2.4: PlaywrightDriver (depends on BrowserDriver, PlaywrightConfiguration)
- TASK-2.5: Unit tests (depends on all above)

**Critical**: Must complete before Phase 3, 4, 5

---

### Phase 3: Artifact Storage and Capture (2-3 hours)
**Parallel Opportunities**: TASK-3.1 (1 task)
- TASK-3.1: ArtifactStorage interface
- TASK-3.2: FileSystemStorage (depends on PathUtils, TimeUtils, StringUtils, ArtifactStorage)
- TASK-3.3: PlaywrightArtifactCapture (depends on PlaywrightDriver, FileSystemStorage, TimeUtils)
- TASK-3.4: Unit tests (depends on all above)

**Critical**: Must complete before Phase 4, 5

---

### Phase 4: Retry Policy and Browser Session (2-3 hours)
**Parallel Opportunities**: TASK-4.1 (1 task, can parallel with Phase 3)
- TASK-4.1: RetryPolicy (depends on NullLogger)
- TASK-4.2: PlaywrightBrowserSession (depends on PlaywrightDriver, PlaywrightArtifactCapture, RetryPolicy)
- TASK-4.3: Unit tests (depends on all above)

**Critical**: Must complete before Phase 5

---

### Phase 5: RSpec Integration and System Spec Updates (1-2 days)
- TASK-5.1: Update Capybara configuration (depends on Phase 2, 3)
- TASK-5.2: Create RSpec helpers (depends on Phase 3, 4, parallel with 5.1)
- TASK-5.3: Update system specs (depends on TASK-5.1, TASK-5.2)
- TASK-5.4: Configure SimpleCov (depends on TASK-5.3, parallel with 5.5)
- TASK-5.5: Integration tests (depends on TASK-5.1, TASK-5.2, TASK-5.3)

**Critical**: Must complete before Phase 6

---

### Phase 6: GitHub Actions Workflow (1 day)
**Parallel Opportunities**: TASK-6.2 (1 task, can parallel with 6.1)
- TASK-6.1: Create GitHub Actions workflow (depends on Phase 5)
- TASK-6.2: Update Docker configuration (depends on TASK-2.1, parallel with 6.1)
- TASK-6.3: Test workflow end-to-end (depends on TASK-6.1, TASK-6.2, Phase 5)

**Critical**: Must complete before Phase 7

---

### Phase 7: Documentation and Verification (1 day)
**Parallel Opportunities**: TASK-7.2, TASK-7.3, TASK-7.4 (3 tasks, can parallel)
- TASK-7.1: Update README (depends on Phase 6)
- TASK-7.2: Create TESTING.md (depends on TASK-7.1, parallel with 7.3, 7.4)
- TASK-7.3: Add YARD documentation (depends on Phase 1-4, parallel with 7.2, 7.4)
- TASK-7.4: Create usage examples (depends on TASK-7.2, TASK-7.3)
- TASK-7.5: Final verification (depends on all above)

**Critical**: Final phase

---

## 4. Risk Assessment

### Technical Risks

**Risk 1: Playwright Browser Installation Fails in CI**
- **Severity**: High
- **Probability**: Medium
- **Impact**: Blocks all system specs in CI
- **Mitigation**:
  - Use `npx playwright install chromium --with-deps` to install system dependencies
  - Add explicit Playwright system dependencies to GitHub Actions workflow
  - Test workflow early (TASK-6.3)

**Risk 2: Capybara-Playwright Compatibility Issues**
- **Severity**: High
- **Probability**: Medium
- **Impact**: System specs fail with Playwright driver
- **Mitigation**:
  - Use official capybara-playwright-driver gem if direct integration fails
  - Test Capybara integration early (TASK-5.1)
  - Have Selenium fallback option ready

**Risk 3: Test Flakiness with Playwright**
- **Severity**: Medium
- **Probability**: Medium
- **Impact**: Unreliable CI pipeline
- **Mitigation**:
  - Implement retry policy (TASK-4.1)
  - Use Playwright auto-wait features
  - Run tests multiple times to verify stability (TASK-6.3)

**Risk 4: Coverage Drops Below 88%**
- **Severity**: Medium
- **Probability**: Low
- **Impact**: Build fails in CI
- **Mitigation**:
  - Write unit tests for all new components (Phases 1-4)
  - Achieve ≥95% coverage for utility libraries
  - Monitor coverage throughout development

**Risk 5: Docker Image Size Exceeds 2GB**
- **Severity**: Low
- **Probability**: Low
- **Impact**: Slow build times
- **Mitigation**:
  - Use slim base image (ruby:3.4.6-slim)
  - Use --no-install-recommends for apt-get
  - Clean apt cache after installation

---

### Dependency Risks

**Risk 1: Critical Path Delays**
- **Severity**: Medium
- **Probability**: Medium
- **Impact**: Total project delay
- **Critical Path**: TASK-1.1 → TASK-2.3 → TASK-3.2 → TASK-4.2 → TASK-5.1 → TASK-6.1 → TASK-7.5
- **Mitigation**:
  - Prioritize critical path tasks
  - Use parallel execution where possible (18 parallel opportunities)
  - Start Phase 2 tasks before Phase 1 tests complete (if implementations ready)

**Risk 2: RSpec Integration Blocks Workflow Creation**
- **Severity**: High
- **Probability**: Low
- **Impact**: Cannot test GitHub Actions workflow
- **Dependencies**: Phase 5 blocks Phase 6
- **Mitigation**:
  - Complete Phase 5 thoroughly before starting Phase 6
  - Test Capybara integration early (TASK-5.1)

---

### Resource Risks

**Risk 1: GitHub Actions Free Tier Limit**
- **Severity**: Low
- **Probability**: Low
- **Impact**: CI pipeline disabled
- **Mitigation**:
  - Monitor GitHub Actions usage
  - Optimize test execution time (target: < 5 minutes)
  - Use caching for Ruby gems and Node modules

---

## 5. Definition of Done (Overall)

- [ ] All 42 tasks completed
- [ ] All RSpec specs pass (unit + integration + system)
- [ ] Code coverage ≥ 88%
- [ ] GitHub Actions workflow runs successfully
- [ ] Docker tests pass
- [ ] Local tests pass (headless and headed mode)
- [ ] No RuboCop violations
- [ ] No security vulnerabilities (bundle audit clean)
- [ ] Documentation complete (README, TESTING.md, YARD)
- [ ] Usage examples work
- [ ] System spec execution time ≤ 2 minutes
- [ ] Total RSpec execution time ≤ 5 minutes in CI
- [ ] Screenshots captured on failure
- [ ] Traces captured on retry (CI)
- [ ] Coverage report uploaded to GitHub Actions
- [ ] No flaky tests (verified by running 5 times)
- [ ] All utility libraries work without Rails
- [ ] Framework-agnostic components tested with Sinatra/Minitest
- [ ] Branch ready for pull request to main

---

## 6. Success Metrics

**Performance Metrics**:
- System spec execution time: < 2 minutes (target: 20% faster than Selenium)
- Total RSpec execution time: < 5 minutes in CI
- Playwright browser launch time: < 2 seconds

**Reliability Metrics**:
- Test flakiness rate: < 1% (verified by running 100 times)
- CI pipeline success rate: ≥ 95%
- Zero Playwright installation failures in CI (last 10 runs)

**Quality Metrics**:
- Code coverage: ≥ 88% (SimpleCov)
- Utility library coverage: ≥ 95%
- RuboCop violations: 0
- Security vulnerabilities: 0 (bundle audit)

**Reusability Metrics**:
- All utility libraries work without Rails: Yes
- PlaywrightBrowserSession works with Minitest: Yes (verified with examples)
- Components work in Sinatra: Yes (verified with examples)

---

**This task plan is ready for evaluation by planner-evaluators.**
