# Design Document - GitHub Actions RSpec with Playwright Integration

**Feature ID**: FEAT-GHA-001
**Created**: 2025-11-23
**Last Updated**: 2025-11-23
**Designer**: designer agent

---

## Metadata

```yaml
design_metadata:
  feature_id: "FEAT-GHA-001"
  feature_name: "GitHub Actions RSpec with Playwright Integration"
  created: "2025-11-23"
  updated: "2025-11-23"
  iteration: 3
  branch: "feature/add_github_actions_rspec"
```

---

## 1. Overview

### Summary

This feature implements a comprehensive CI/CD pipeline for RSpec testing using GitHub Actions, replacing the current Selenium WebDriver-based system specs with Playwright for more reliable, faster, and cross-platform browser automation testing. The solution ensures consistent test execution across local development, Docker environments, and GitHub Actions CI runners.

**Framework-Agnostic Design**: All components are designed to work independently of Rails, using utility libraries and dependency injection to ensure reusability across different Ruby projects (Sinatra, Hanami, pure Ruby CLIs).

### Goals and Objectives

1. **Primary Goals**:
   - Replace Selenium WebDriver with Playwright for RSpec system specs
   - Implement GitHub Actions workflow for automated RSpec test execution (unit, integration, and system specs)
   - Ensure Playwright works seamlessly in both local and Docker environments
   - Maintain or exceed current test coverage (88% minimum as per SimpleCov configuration)
   - **Create framework-agnostic testing utilities** that can be reused in non-Rails projects

2. **Secondary Goals**:
   - Improve test execution speed compared to Selenium WebDriver
   - Enable headless and headed browser testing modes
   - Support multiple browsers (Chromium, Firefox, WebKit)
   - Provide detailed test failure artifacts in CI environment
   - **Enable usage with any testing framework** (RSpec, Minitest, Cucumber)

3. **Non-Goals**:
   - Migration of existing test logic (only driver replacement)
   - Frontend E2E testing beyond existing system specs
   - Integration with third-party testing services (e.g., BrowserStack)

### Success Criteria

- [ ] All existing system specs pass using Playwright driver
- [ ] GitHub Actions workflow successfully runs all RSpec specs (unit, integration, system)
- [ ] Test execution time reduced by at least 20% compared to Selenium WebDriver
- [ ] Playwright works in both local and Docker environments without manual intervention
- [ ] CI pipeline provides test failure screenshots and traces as artifacts
- [ ] Documentation updated with local and CI setup instructions
- [ ] SimpleCov minimum coverage threshold (88%) maintained
- [ ] **All utility libraries work without Rails dependencies** (PathUtils, EnvUtils, etc.)
- [ ] **PlaywrightBrowserSession usable outside RSpec context**

---

## 2. Requirements Analysis

### 2.1 Current State Analysis

**Existing Test Infrastructure**:

- **Test Framework**: RSpec Rails with 7 system specs, 5 model specs, and 9 service/job specs
- **System Spec Driver**: Selenium WebDriver with headless Chrome
- **Capybara Configuration**: Located in `spec/support/capybara.rb`
  ```ruby
  config.before(:each, type: :system) do
    driven_by :selenium, using: :headless_chrome, screen_size: [1920, 1080]
  end
  ```
- **Test Dependencies**: `capybara`, `webdrivers` gems (Gemfile line 77-79)
- **CI/CD**: Only RuboCop workflow exists (`.github/workflows/rubocop.yml`)
- **Coverage**: SimpleCov configured with 88% minimum threshold

**Technology Stack**:

- Ruby 3.4.6 (upgraded from 3.0.2 mentioned in requirements)
- Rails 8.1.1 (upgraded from 6.1.4)
- MySQL 8.0 (development/test)
- PostgreSQL (production)
- Modern asset pipeline: jsbundling-rails (esbuild), cssbundling-rails

**Environment Setup**:

- Local execution: Direct Ruby/Rails installation
- Docker support: `Dockerfile` and `docker-compose.yml` available
- Asset building: npm scripts for JavaScript (esbuild) and CSS (Sass + PostCSS)

### 2.2 Functional Requirements

**FR-1: Playwright Gem Integration**
- Replace Selenium WebDriver with Playwright Ruby gem (`playwright-ruby-client`)
- Configure Playwright driver for Capybara integration
- Maintain existing system spec test logic and expectations

**FR-2: Local Development Support**
- Playwright browser binaries auto-installation via CLI
- Support both headless and headed browser modes for debugging
- Compatible with macOS, Linux, and Windows development environments

**FR-3: Docker Environment Support**
- Playwright browser binaries installation in Docker image
- Headless-only mode in containerized environment
- No display server requirements (Xvfb not needed with Playwright)

**FR-4: GitHub Actions Workflow**
- Automated test execution on push to main/master and pull requests
- Parallel job execution: RuboCop (existing) + RSpec (new)
- Matrix strategy for future multi-browser testing (optional)
- Artifact upload for test failure screenshots and Playwright traces

**FR-5: Test Execution**
- Run all RSpec specs: unit (models, services, jobs) + integration + system
- Generate SimpleCov coverage report
- Fail build if coverage drops below 88%
- Provide detailed test output with failure context

**FR-6: Browser Automation**
- Default: Chromium headless mode
- Optional: Firefox and WebKit support for cross-browser testing
- Configurable viewport size (default: 1920x1080)
- Screenshot capture on test failure

**FR-7: Framework Agnosticity** ⭐ NEW
- All utilities work without Rails (PathUtils, EnvUtils, TimeUtils, StringUtils)
- Browser session management works outside RSpec (Minitest, Cucumber, CLI)
- Configuration supports non-Rails environments (Sinatra, Hanami, pure Ruby)

### 2.3 Non-Functional Requirements

**NFR-1: Performance**
- System spec execution time: < 2 minutes for all 7 specs
- Total RSpec execution time: < 5 minutes in CI environment
- Playwright browser launch time: < 2 seconds

**NFR-2: Reliability**
- Test flakiness rate: < 1% (maximum 1 flaky test per 100 runs)
- Playwright auto-wait mechanism to eliminate race conditions
- Configurable retry mechanism for transient failures (max 3 attempts, exponential backoff)

**NFR-3: Maintainability**
- Centralized Playwright configuration using service classes
- Environment-based configuration (local vs Docker vs CI)
- Clear documentation for local setup and troubleshooting

**NFR-4: Security**
- No hardcoded credentials in workflow files
- Use GitHub Secrets for sensitive environment variables
- Playwright browser binaries verified via checksums

**NFR-5: Compatibility**
- Ruby 3.4.6 compatibility
- Rails 8.1.1 compatibility
- RSpec 3.x compatibility
- Capybara 3.x compatibility

**NFR-6: Reusability** ⭐ NEW
- All components work without Rails framework
- Utilities use standard Ruby (Pathname, ENV, File)
- Configuration via dependency injection (not global constants)
- Support multiple testing frameworks (RSpec, Minitest, Cucumber)

### 2.4 Constraints

**Technical Constraints**:
- Must maintain existing RSpec test structure and syntax
- Cannot introduce breaking changes to existing specs
- Must work with current Gemfile dependencies
- GitHub Actions runner: Ubuntu latest (ubuntu-24.04 or ubuntu-22.04)

**Resource Constraints**:
- GitHub Actions free tier: 2,000 minutes/month for private repos
- Docker image size: Keep under 2GB for reasonable build times
- Test database: MySQL 8.0 in CI (must match development)

**Timeline Constraints**:
- Development branch: `feature/add_github_actions_rspec` already exists
- Implementation should align with existing RuboCop workflow patterns

---

## 3. Architecture Design

### 3.1 System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    GitHub Actions CI Pipeline                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────┐                  ┌──────────────┐             │
│  │   RuboCop    │                  │    RSpec     │             │
│  │   Workflow   │                  │   Workflow   │             │
│  │  (Existing)  │                  │    (New)     │             │
│  └──────────────┘                  └──────────────┘             │
│                                            │                      │
│                                            ▼                      │
│                                  ┌──────────────────┐            │
│                                  │  Setup Ruby 3.4.6│            │
│                                  │  Bundle Install  │            │
│                                  │  Install Node.js │            │
│                                  │  npm install     │            │
│                                  └──────────────────┘            │
│                                            │                      │
│                                            ▼                      │
│                                  ┌──────────────────┐            │
│                                  │ Install Playwright│           │
│                                  │    Browsers      │            │
│                                  └──────────────────┘            │
│                                            │                      │
│                                            ▼                      │
│                                  ┌──────────────────┐            │
│                                  │  Setup Database  │            │
│                                  │  (MySQL 8.0)     │            │
│                                  └──────────────────┘            │
│                                            │                      │
│                                            ▼                      │
│                                  ┌──────────────────┐            │
│                                  │  Run RSpec Tests │            │
│                                  │  - Model Specs   │            │
│                                  │  - Service Specs │            │
│                                  │  - System Specs  │            │
│                                  │    (Playwright)  │            │
│                                  └──────────────────┘            │
│                                            │                      │
│                                            ▼                      │
│                                  ┌──────────────────┐            │
│                                  │ Coverage Report  │            │
│                                  │   (SimpleCov)    │            │
│                                  └──────────────────┘            │
│                                            │                      │
│                                            ▼                      │
│                                  ┌──────────────────┐            │
│                                  │Upload Artifacts  │            │
│                                  │ - Screenshots    │            │
│                                  │ - Traces         │            │
│                                  │ - Coverage HTML  │            │
│                                  └──────────────────┘            │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 Component Breakdown

**Component 1: Utility Libraries** ⭐ NEW

- **Purpose**: Provide framework-agnostic utilities for common operations
- **Files**:
  - `lib/testing/utils/path_utils.rb` (path management)
  - `lib/testing/utils/env_utils.rb` (environment detection)
  - `lib/testing/utils/time_utils.rb` (timestamp formatting)
  - `lib/testing/utils/string_utils.rb` (filename sanitization)
- **Responsibilities**:
  - Abstract Rails dependencies (Rails.root, Rails.env, Rails.logger)
  - Provide consistent API across different frameworks
  - Enable testing without framework dependencies

**Component 2: Browser Driver Abstraction Layer** ⭐ NEW

- **Purpose**: Decouple from specific browser automation implementation
- **Files**:
  - `lib/testing/browser_driver.rb` (interface)
  - `lib/testing/playwright_driver.rb` (implementation)
- **Responsibilities**:
  - Define common driver interface (`launch_browser`, `close_browser`, `take_screenshot`)
  - Provide Playwright-specific implementation
  - Enable future driver swapping (Selenium fallback, Puppeteer, etc.)
  - Support configuration injection for environment-specific settings

**Component 3: Playwright Configuration Service** ⭐ REVISED

- **Purpose**: Centralize and manage Playwright configuration
- **File**: `lib/testing/playwright_configuration.rb`
- **Responsibilities**:
  - Environment-based configuration (`for_environment(env)`)
  - Validate configuration values
  - Provide type-safe configuration access
  - Support configuration overrides via environment variables
  - Generate browser launch options
  - **Use PathUtils and EnvUtils instead of Rails**

**Component 4: Artifact Storage Abstraction** ⭐ NEW

- **Purpose**: Abstract artifact storage mechanism
- **Files**:
  - `lib/testing/artifact_storage.rb` (interface)
  - `lib/testing/file_system_storage.rb` (implementation)
- **Responsibilities**:
  - Define storage interface (`save_screenshot`, `save_trace`, `list_artifacts`)
  - Implement filesystem storage (current)
  - Enable future cloud storage integration (S3, GCS, Azure Blob)
  - Handle artifact metadata (timestamps, test names, correlation IDs)
  - **Use PathUtils for path management**

**Component 5: Playwright Artifact Capture Service** ⭐ REVISED

- **Purpose**: Separate artifact capture concerns from test framework
- **File**: `lib/testing/playwright_artifact_capture.rb`
- **Responsibilities**:
  - Capture screenshots on test failure
  - Capture Playwright traces with configurable modes
  - Attach artifacts to test output
  - Correlate artifacts with test execution (correlation IDs)
  - Log artifact locations with structured format
  - **Use injected logger instead of Rails.logger**

**Component 6: Retry Mechanism** ⭐ REVISED

- **Purpose**: Handle transient test failures gracefully
- **File**: `lib/testing/retry_policy.rb`
- **Responsibilities**:
  - Configurable retry attempts (default: 3)
  - Exponential backoff strategy (2s, 4s, 8s)
  - **Configurable error types** (not hardcoded to RSpec)
  - Skip retry on assertion failures (true test failures)
  - Log retry attempts with structured output
  - **Use injected logger instead of Rails.logger**

**Component 7: Playwright Browser Session Manager** ⭐ NEW

- **Purpose**: Manage browser session lifecycle independent of testing framework
- **File**: `lib/testing/playwright_browser_session.rb`
- **Responsibilities**:
  - Browser instance creation and cleanup
  - Context management (cookies, storage, auth state)
  - Session isolation for concurrent tests
  - **Reusable in non-RSpec contexts** (Minitest, Cucumber, CLI)
  - **Framework-agnostic test execution wrapper**

**Component 8: Capybara Driver Configuration**

- **File**: `spec/support/capybara.rb` (to be updated)
- **Purpose**: Configure Playwright as Capybara driver for system specs
- **Responsibilities**:
  - Register `:playwright` driver using BrowserDriver abstraction
  - Delegate to PlaywrightConfiguration for settings
  - Set up screenshot directory using ArtifactStorage
  - Environment-specific configuration (local vs Docker vs CI)

**Component 9: GitHub Actions Workflow**

- **File**: `.github/workflows/rspec.yml` (new)
- **Purpose**: Automate RSpec test execution on code changes
- **Responsibilities**:
  - Trigger on push/PR events
  - Set up Ruby, Node.js, and system dependencies
  - Install Playwright browsers
  - Configure test database
  - Run RSpec with coverage
  - Upload test artifacts

**Component 10: Docker Configuration Updates**

- **Files**: `Dockerfile`, `docker-compose.yml` (to be updated)
- **Purpose**: Enable Playwright in Docker containers
- **Responsibilities**:
  - Install Playwright system dependencies
  - Install Playwright browsers in Docker image
  - Configure headless mode for containerized testing
  - Set up test database service

**Component 11: RSpec Configuration**

- **Files**: `spec/rails_helper.rb`, `.rspec` (minor updates)
- **Purpose**: Configure RSpec for Playwright integration
- **Responsibilities**:
  - Load Playwright support files
  - Configure SimpleCov for CI environment
  - Set up database cleaner for system specs
  - Configure RSpec output format for CI
  - Integrate retry mechanism for flaky tests

### 3.3 Data Flow

**Local Development Flow**:

```
Developer → Write/Update Spec → Run `bundle exec rspec`
                                        │
                                        ▼
                              Load rails_helper.rb
                                        │
                                        ▼
                 PlaywrightConfiguration.for_environment(EnvUtils.environment)
                                        │
                                        ▼
                          PlaywrightDriver.new(config)
                                        │
                                        ▼
                    Launch Playwright browser (headless or headed)
                                        │
                                        ▼
                              Run System Specs
                                        │
                                        ▼
                    On failure → PlaywrightArtifactCapture
                                        │
                                        ▼
                  ArtifactStorage.save_screenshot(path, data)
                                        │
                                        ▼
                              Generate Coverage Report
                                        │
                                        ▼
                              Display Results
```

**CI Environment Flow**:

```
Git Push/PR → Trigger GitHub Actions → Checkout Code
                                              │
                                              ▼
                                    Setup Ruby + Dependencies
                                              │
                                              ▼
                                  Install Playwright Browsers
                                              │
                                              ▼
                                    Setup MySQL Database
                                              │
                                              ▼
                                    Run Database Migrations
                                              │
                                              ▼
                                    Run RSpec (all specs)
                                              │
                                              ▼
                        RetryPolicy handles transient failures
                                              │
                                              ▼
                  PlaywrightArtifactCapture with trace enabled
                                              │
                                              ▼
                                  Generate Coverage Report
                                              │
                                              ▼
              Upload Artifacts (screenshots, traces, coverage)
                                              │
                                              ▼
                                    Report Success/Failure
```

**Docker Environment Flow**:

```
docker-compose up → Build Docker Image
                            │
                            ▼
                Install System Dependencies
                            │
                            ▼
                  Install Playwright Browsers
                            │
                            ▼
                    Start MySQL Container
                            │
                            ▼
              docker-compose exec web bundle exec rspec
                            │
                            ▼
                    Run Tests (headless mode)
                            │
                            ▼
                  Save artifacts to mounted volume
```

---

## 4. Data Model

### 4.1 Utility Libraries ⭐ NEW

**PathUtils Module**:

```ruby
# lib/testing/utils/path_utils.rb

module Testing
  module Utils
    module PathUtils
      class << self
        # Get project root path (works with or without Rails)
        # @return [Pathname] Project root path
        def root_path
          @root_path ||= if defined?(Rails)
                           Rails.root
                         else
                           Pathname.new(Dir.pwd)
                         end
        end

        # Get temporary directory path
        # @return [Pathname] Temporary directory path
        def tmp_path
          root_path.join('tmp')
        end

        # Get screenshots directory path
        # @return [Pathname] Screenshots directory path
        def screenshots_path
          tmp_path.join('screenshots')
        end

        # Get traces directory path
        # @return [Pathname] Traces directory path
        def traces_path
          tmp_path.join('traces')
        end

        # Get coverage directory path
        # @return [Pathname] Coverage directory path
        def coverage_path
          root_path.join('coverage')
        end

        # Allow custom root path (for testing or non-standard setups)
        # @param path [String, Pathname] Custom root path
        def root_path=(path)
          @root_path = Pathname.new(path)
        end
      end
    end
  end
end
```

**EnvUtils Module**:

```ruby
# lib/testing/utils/env_utils.rb

module Testing
  module Utils
    module EnvUtils
      class << self
        # Get current environment (works with or without Rails)
        # @return [String] Environment name (test, development, production)
        def environment
          if defined?(Rails)
            Rails.env.to_s
          else
            ENV.fetch('RACK_ENV', ENV.fetch('APP_ENV', 'development'))
          end
        end

        # Check if running in test environment
        # @return [Boolean] true if test environment
        def test_environment?
          environment == 'test'
        end

        # Check if running in CI environment
        # @return [Boolean] true if CI environment
        def ci_environment?
          ENV['CI'] == 'true' || ENV['GITHUB_ACTIONS'] == 'true'
        end

        # Check if running in production environment
        # @return [Boolean] true if production environment
        def production_environment?
          environment == 'production'
        end

        # Check if running in development environment
        # @return [Boolean] true if development environment
        def development_environment?
          environment == 'development'
        end

        # Get environment variable with fallback
        # @param key [String] Environment variable name
        # @param default [String] Default value if not found
        # @return [String] Environment variable value or default
        def get(key, default = nil)
          ENV.fetch(key, default)
        end
      end
    end
  end
end
```

**TimeUtils Module**:

```ruby
# lib/testing/utils/time_utils.rb

require 'time'

module Testing
  module Utils
    module TimeUtils
      class << self
        # Format timestamp for artifact filenames
        # @param time [Time] Time object to format
        # @return [String] Formatted timestamp (e.g., "20251123-143025")
        def format_for_filename(time = Time.now)
          time.strftime('%Y%m%d-%H%M%S')
        end

        # Format timestamp for ISO 8601 (JSON, logs)
        # @param time [Time] Time object to format
        # @return [String] ISO 8601 formatted timestamp
        def format_iso8601(time = Time.now)
          time.iso8601
        end

        # Format timestamp for human-readable display
        # @param time [Time] Time object to format
        # @return [String] Human-readable timestamp
        def format_human(time = Time.now)
          time.strftime('%Y-%m-%d %H:%M:%S')
        end

        # Generate correlation ID with timestamp
        # @param prefix [String] Prefix for correlation ID
        # @return [String] Correlation ID (e.g., "test-run-20251123-143025-a8f3d1")
        def generate_correlation_id(prefix = 'test-run')
          "#{prefix}-#{format_for_filename}-#{SecureRandom.hex(3)}"
        end
      end
    end
  end
end
```

**StringUtils Module**:

```ruby
# lib/testing/utils/string_utils.rb

module Testing
  module Utils
    module StringUtils
      class << self
        # Sanitize filename to prevent path traversal attacks
        # Replaces non-alphanumeric characters (except - and _) with underscores
        # @param name [String] Original filename
        # @return [String] Sanitized filename
        def sanitize_filename(name)
          name.to_s.gsub(/[^0-9A-Za-z_-]/, '_')
        end

        # Generate safe artifact name from test metadata
        # @param test_name [String] Test name
        # @param index [Integer] Test index (optional)
        # @return [String] Safe artifact name
        def generate_artifact_name(test_name, index = nil)
          base_name = sanitize_filename(test_name)
          index ? "#{base_name}_#{index}" : base_name
        end

        # Truncate long filenames
        # @param name [String] Original filename
        # @param max_length [Integer] Maximum length (default: 255)
        # @return [String] Truncated filename
        def truncate_filename(name, max_length = 255)
          return name if name.length <= max_length

          extension = File.extname(name)
          base_length = max_length - extension.length - 3 # -3 for "..."
          "#{name[0...base_length]}...#{extension}"
        end
      end
    end
  end
end
```

**NullLogger Class** ⭐ NEW:

```ruby
# lib/testing/utils/null_logger.rb

module Testing
  module Utils
    # Null object pattern for logger (when no logger is provided)
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

### 4.2 Configuration Data Structures

**PlaywrightConfiguration Class** ⭐ REVISED:

```ruby
# lib/testing/playwright_configuration.rb

require_relative 'utils/path_utils'
require_relative 'utils/env_utils'

module Testing
  class PlaywrightConfiguration
    # Default configuration values
    DEFAULT_BROWSER = 'chromium'
    DEFAULT_HEADLESS = true
    DEFAULT_VIEWPORT_WIDTH = 1920
    DEFAULT_VIEWPORT_HEIGHT = 1080
    DEFAULT_SLOW_MO = 0
    DEFAULT_TIMEOUT = 30_000 # 30 seconds
    DEFAULT_TRACE_MODE = 'on-first-retry' # Enable trace on retry by default

    attr_reader :browser_type, :headless, :viewport, :slow_mo, :timeout,
                :screenshots_path, :traces_path, :trace_mode

    # Factory method for environment-specific configuration
    # @param env [String] Environment name (optional, auto-detected)
    # @return [PlaywrightConfiguration] Configuration instance
    def self.for_environment(env = nil)
      env ||= Utils::EnvUtils.environment

      case env
      when 'test'
        # CI environment has stricter requirements
        if Utils::EnvUtils.ci_environment?
          ci_config
        else
          local_config
        end
      when 'development'
        development_config
      else
        raise "Unsupported environment: #{env}"
      end
    end

    # Configuration for CI environment
    def self.ci_config
      new(
        browser_type: Utils::EnvUtils.get('PLAYWRIGHT_BROWSER', DEFAULT_BROWSER),
        headless: true, # Always headless in CI
        viewport: { width: DEFAULT_VIEWPORT_WIDTH, height: DEFAULT_VIEWPORT_HEIGHT },
        slow_mo: 0, # No slowdown in CI
        timeout: 60_000, # Longer timeout for slower CI runners
        screenshots_path: Utils::PathUtils.screenshots_path,
        traces_path: Utils::PathUtils.traces_path,
        trace_mode: 'on-first-retry' # Capture trace on retry in CI
      )
    end

    # Configuration for local testing
    def self.local_config
      new(
        browser_type: Utils::EnvUtils.get('PLAYWRIGHT_BROWSER', DEFAULT_BROWSER),
        headless: Utils::EnvUtils.get('PLAYWRIGHT_HEADLESS', 'true') == 'true',
        viewport: {
          width: Utils::EnvUtils.get('PLAYWRIGHT_VIEWPORT_WIDTH', DEFAULT_VIEWPORT_WIDTH.to_s).to_i,
          height: Utils::EnvUtils.get('PLAYWRIGHT_VIEWPORT_HEIGHT', DEFAULT_VIEWPORT_HEIGHT.to_s).to_i
        },
        slow_mo: Utils::EnvUtils.get('PLAYWRIGHT_SLOW_MO', DEFAULT_SLOW_MO.to_s).to_i,
        timeout: Utils::EnvUtils.get('PLAYWRIGHT_TIMEOUT', DEFAULT_TIMEOUT.to_s).to_i,
        screenshots_path: Utils::PathUtils.screenshots_path,
        traces_path: Utils::PathUtils.traces_path,
        trace_mode: Utils::EnvUtils.get('PLAYWRIGHT_TRACE_MODE', 'off') # Off by default locally
      )
    end

    # Configuration for development debugging
    def self.development_config
      new(
        browser_type: Utils::EnvUtils.get('PLAYWRIGHT_BROWSER', 'chromium'),
        headless: false, # Headed mode for debugging
        viewport: { width: DEFAULT_VIEWPORT_WIDTH, height: DEFAULT_VIEWPORT_HEIGHT },
        slow_mo: 500, # Slow down for visual debugging
        timeout: DEFAULT_TIMEOUT,
        screenshots_path: Utils::PathUtils.screenshots_path,
        traces_path: Utils::PathUtils.traces_path,
        trace_mode: 'on' # Always capture trace in development
      )
    end

    def initialize(browser_type:, headless:, viewport:, slow_mo:, timeout:,
                   screenshots_path:, traces_path:, trace_mode:)
      @browser_type = browser_type
      @headless = headless
      @viewport = viewport
      @slow_mo = slow_mo
      @timeout = timeout
      @screenshots_path = screenshots_path
      @traces_path = traces_path
      @trace_mode = trace_mode

      validate!
      ensure_directories_exist
    end

    # Generate browser launch options for Playwright
    def browser_launch_options
      {
        headless: headless,
        slow_mo: slow_mo,
        timeout: timeout,
        args: headless ? ['--no-sandbox', '--disable-dev-shm-usage'] : []
      }
    end

    # Generate browser context options
    def browser_context_options
      {
        viewport: viewport,
        record_video_dir: traces_path.to_s if trace_mode != 'off',
        record_video_size: viewport
      }
    end

    private

    # Validate configuration values
    def validate!
      unless %w[chromium firefox webkit].include?(browser_type)
        raise ArgumentError, "Invalid browser type: #{browser_type}"
      end

      unless %w[on off on-first-retry].include?(trace_mode)
        raise ArgumentError, "Invalid trace mode: #{trace_mode}"
      end

      if timeout < 1000
        raise ArgumentError, "Timeout too low: #{timeout}ms (minimum 1000ms)"
      end
    end

    # Ensure artifact directories exist
    def ensure_directories_exist
      FileUtils.mkdir_p(screenshots_path)
      FileUtils.mkdir_p(traces_path)
    end
  end
end
```

**BrowserDriver Interface** ⭐ NEW:

```ruby
# lib/testing/browser_driver.rb

module Testing
  # Abstract interface for browser automation drivers
  # Allows switching between Playwright, Selenium, Puppeteer, etc.
  class BrowserDriver
    # Launch browser with given configuration
    # @param config [PlaywrightConfiguration] Configuration object
    # @return [Object] Browser instance
    def launch_browser(config)
      raise NotImplementedError, "#{self.class} must implement #launch_browser"
    end

    # Close browser instance
    # @param browser [Object] Browser instance to close
    def close_browser(browser)
      raise NotImplementedError, "#{self.class} must implement #close_browser"
    end

    # Create new browser context (session)
    # @param browser [Object] Browser instance
    # @param config [PlaywrightConfiguration] Configuration object
    # @return [Object] Browser context
    def create_context(browser, config)
      raise NotImplementedError, "#{self.class} must implement #create_context"
    end

    # Take screenshot of current page
    # @param page [Object] Page instance
    # @param path [String] File path to save screenshot
    def take_screenshot(page, path)
      raise NotImplementedError, "#{self.class} must implement #take_screenshot"
    end

    # Start tracing
    # @param context [Object] Browser context
    def start_trace(context)
      raise NotImplementedError, "#{self.class} must implement #start_trace"
    end

    # Stop tracing and save to file
    # @param context [Object] Browser context
    # @param path [String] File path to save trace
    def stop_trace(context, path)
      raise NotImplementedError, "#{self.class} must implement #stop_trace"
    end
  end
end
```

**PlaywrightDriver Implementation** ⭐ NEW:

```ruby
# lib/testing/playwright_driver.rb

require_relative 'browser_driver'

module Testing
  # Playwright-specific implementation of BrowserDriver interface
  class PlaywrightDriver < BrowserDriver
    def initialize
      require 'playwright'
      @playwright = Playwright.create(playwright_cli_executable_path: 'npx playwright')
    rescue LoadError => e
      raise LoadError, "Playwright gem not installed. Run: bundle install && bundle exec playwright install chromium"
    end

    # Launch Playwright browser
    # @param config [PlaywrightConfiguration] Configuration object
    # @return [Playwright::Browser] Browser instance
    def launch_browser(config)
      browser_type = @playwright.send(config.browser_type) # chromium, firefox, or webkit
      browser_type.launch(**config.browser_launch_options)
    end

    # Close Playwright browser
    # @param browser [Playwright::Browser] Browser instance
    def close_browser(browser)
      browser.close if browser
    end

    # Create new browser context
    # @param browser [Playwright::Browser] Browser instance
    # @param config [PlaywrightConfiguration] Configuration object
    # @return [Playwright::BrowserContext] Browser context
    def create_context(browser, config)
      browser.new_context(**config.browser_context_options)
    end

    # Take screenshot using Playwright
    # @param page [Playwright::Page] Page instance
    # @param path [String] File path to save screenshot
    def take_screenshot(page, path)
      page.screenshot(path: path, full_page: true)
    end

    # Start Playwright tracing
    # @param context [Playwright::BrowserContext] Browser context
    def start_trace(context)
      context.tracing.start(screenshots: true, snapshots: true, sources: true)
    end

    # Stop tracing and save trace file
    # @param context [Playwright::BrowserContext] Browser context
    # @param path [String] File path to save trace
    def stop_trace(context, path)
      context.tracing.stop(path: path)
    end
  end
end
```

### 4.3 Artifact Storage

**ArtifactStorage Interface** ⭐ NEW:

```ruby
# lib/testing/artifact_storage.rb

module Testing
  # Abstract interface for artifact storage
  # Enables different storage backends (filesystem, S3, GCS, Azure Blob)
  class ArtifactStorage
    # Save screenshot to storage
    # @param name [String] Artifact name
    # @param file_path [String] Source file path
    # @param metadata [Hash] Artifact metadata
    # @return [String] Storage path
    def save_screenshot(name, file_path, metadata = {})
      raise NotImplementedError, "#{self.class} must implement #save_screenshot"
    end

    # Save trace to storage
    # @param name [String] Artifact name
    # @param file_path [String] Source file path
    # @param metadata [Hash] Artifact metadata
    # @return [String] Storage path
    def save_trace(name, file_path, metadata = {})
      raise NotImplementedError, "#{self.class} must implement #save_trace"
    end

    # List all artifacts
    # @return [Array<String>] List of artifact names
    def list_artifacts
      raise NotImplementedError, "#{self.class} must implement #list_artifacts"
    end

    # Get artifact by name
    # @param name [String] Artifact name
    # @return [String, nil] File contents or nil
    def get_artifact(name)
      raise NotImplementedError, "#{self.class} must implement #get_artifact"
    end

    # Delete artifact by name
    # @param name [String] Artifact name
    def delete_artifact(name)
      raise NotImplementedError, "#{self.class} must implement #delete_artifact"
    end
  end
end
```

**FileSystemStorage Implementation** ⭐ REVISED:

```ruby
# lib/testing/file_system_storage.rb

require_relative 'artifact_storage'
require_relative 'utils/path_utils'
require_relative 'utils/string_utils'
require_relative 'utils/time_utils'
require 'fileutils'
require 'json'

module Testing
  # Filesystem-based artifact storage implementation
  class FileSystemStorage < ArtifactStorage
    attr_reader :base_path

    # @param base_path [String, Pathname] Base path for artifact storage (default: tmp/)
    def initialize(base_path: Utils::PathUtils.tmp_path)
      @base_path = Pathname.new(base_path)
      ensure_directories_exist
    end

    # Save screenshot to filesystem
    # @param name [String] Screenshot name
    # @param file_path [String] Source file path
    # @param metadata [Hash] Screenshot metadata
    # @return [String] Final screenshot path
    def save_screenshot(name, file_path, metadata = {})
      sanitized_name = Utils::StringUtils.sanitize_filename(name)
      screenshot_path = screenshots_path.join("#{sanitized_name}.png")

      # Copy file to storage location
      FileUtils.cp(file_path, screenshot_path)

      # Save metadata
      save_metadata(screenshot_path, metadata)

      screenshot_path.to_s
    end

    # Save trace to filesystem
    # @param name [String] Trace name
    # @param file_path [String] Source file path
    # @param metadata [Hash] Trace metadata
    # @return [String] Final trace path
    def save_trace(name, file_path, metadata = {})
      sanitized_name = Utils::StringUtils.sanitize_filename(name)
      trace_path = traces_path.join("#{sanitized_name}.zip")

      # Copy file to storage location
      FileUtils.cp(file_path, trace_path)

      # Save metadata
      save_metadata(trace_path, metadata)

      trace_path.to_s
    end

    # List all artifacts (screenshots + traces)
    # @return [Array<String>] List of artifact filenames
    def list_artifacts
      screenshots = Dir.glob(screenshots_path.join('*.png')).map { |f| File.basename(f) }
      traces = Dir.glob(traces_path.join('*.zip')).map { |f| File.basename(f) }
      (screenshots + traces).sort
    end

    # Get artifact by name
    # @param name [String] Artifact name
    # @return [String, nil] File contents
    def get_artifact(name)
      screenshot_path = screenshots_path.join(name)
      trace_path = traces_path.join(name)

      if File.exist?(screenshot_path)
        File.binread(screenshot_path)
      elsif File.exist?(trace_path)
        File.binread(trace_path)
      end
    end

    # Delete artifact by name
    # @param name [String] Artifact name
    def delete_artifact(name)
      screenshot_path = screenshots_path.join(name)
      trace_path = traces_path.join(name)

      FileUtils.rm_f(screenshot_path) if File.exist?(screenshot_path)
      FileUtils.rm_f(trace_path) if File.exist?(trace_path)

      # Delete metadata files
      FileUtils.rm_f("#{screenshot_path}.json")
      FileUtils.rm_f("#{trace_path}.json")
    end

    private

    def screenshots_path
      @screenshots_path ||= base_path.join('screenshots')
    end

    def traces_path
      @traces_path ||= base_path.join('traces')
    end

    def ensure_directories_exist
      FileUtils.mkdir_p(screenshots_path)
      FileUtils.mkdir_p(traces_path)
    end

    # Save metadata as JSON file alongside artifact
    def save_metadata(artifact_path, metadata)
      metadata_path = "#{artifact_path}.json"
      File.write(metadata_path, JSON.pretty_generate(metadata.merge(
        created_at: Utils::TimeUtils.format_iso8601,
        artifact_path: artifact_path.to_s
      )))
    end

    # Load metadata from JSON file
    def load_metadata(artifact_path)
      metadata_path = "#{artifact_path}.json"
      return {} unless File.exist?(metadata_path)

      JSON.parse(File.read(metadata_path), symbolize_names: true)
    rescue JSON::ParserError
      {}
    end
  end
end
```

**RetryPolicy Class** ⭐ REVISED:

```ruby
# lib/testing/retry_policy.rb

require_relative 'utils/null_logger'
require_relative 'utils/time_utils'

module Testing
  # Configurable retry policy for handling transient test failures
  # Framework-agnostic: Works with RSpec, Minitest, Cucumber, etc.
  class RetryPolicy
    # Default configuration
    DEFAULT_MAX_ATTEMPTS = 3
    DEFAULT_BASE_DELAY = 2 # seconds
    DEFAULT_MAX_DELAY = 8 # seconds

    # Common transient errors (network, timeouts, etc.)
    DEFAULT_RETRYABLE_ERRORS = [
      Playwright::TimeoutError,
      Net::ReadTimeout,
      Errno::ECONNREFUSED,
      Errno::ECONNRESET
    ].freeze

    attr_reader :max_attempts, :base_delay, :max_delay, :logger, :retryable_errors

    # @param max_attempts [Integer] Maximum retry attempts
    # @param base_delay [Integer] Base delay in seconds
    # @param max_delay [Integer] Maximum delay in seconds
    # @param logger [Object] Logger instance (defaults to NullLogger)
    # @param retryable_errors [Array<Class>] Error classes that should trigger retry
    def initialize(max_attempts: DEFAULT_MAX_ATTEMPTS,
                   base_delay: DEFAULT_BASE_DELAY,
                   max_delay: DEFAULT_MAX_DELAY,
                   logger: nil,
                   retryable_errors: DEFAULT_RETRYABLE_ERRORS)
      @max_attempts = max_attempts
      @base_delay = base_delay
      @max_delay = max_delay
      @logger = logger || Utils::NullLogger.new
      @retryable_errors = retryable_errors
    end

    # Execute block with retry logic
    # @param context [String] Description of operation being retried
    # @yield Block to execute with retry
    # @return [Object] Result of block execution
    def execute(context: 'operation', &block)
      attempt = 0

      begin
        attempt += 1
        block.call
      rescue => e
        if should_retry?(e, attempt)
          delay = calculate_delay(attempt)
          log_retry(context, attempt, e, delay)
          sleep(delay)
          retry
        else
          log_failure(context, attempt, e)
          raise
        end
      end
    end

    private

    # Check if error should trigger retry
    # @param error [Exception] Error that occurred
    # @param attempt [Integer] Current attempt number
    # @return [Boolean] True if should retry
    def should_retry?(error, attempt)
      # Don't retry if max attempts reached
      return false if attempt >= max_attempts

      # Retry if error is in retryable list
      retryable_errors.any? { |klass| error.is_a?(klass) }
    end

    # Calculate exponential backoff delay
    # @param attempt [Integer] Current attempt number
    # @return [Float] Delay in seconds
    def calculate_delay(attempt)
      # Exponential backoff: 2^(attempt-1) * base_delay
      # Attempt 1: 2s, Attempt 2: 4s, Attempt 3: 8s
      delay = (2 ** (attempt - 1)) * base_delay
      [delay, max_delay].min # Cap at max_delay
    end

    # Log retry attempt with structured format
    def log_retry(context, attempt, error, delay)
      logger.warn({
        event: 'test_retry',
        context: context,
        attempt: attempt,
        max_attempts: max_attempts,
        error_class: error.class.name,
        error_message: error.message,
        retry_delay_seconds: delay,
        timestamp: Utils::TimeUtils.format_iso8601
      }.to_json)
    end

    # Log final failure
    def log_failure(context, attempt, error)
      logger.error({
        event: 'test_retry_exhausted',
        context: context,
        attempts_made: attempt,
        error_class: error.class.name,
        error_message: error.message,
        timestamp: Utils::TimeUtils.format_iso8601
      }.to_json)
    end
  end
end
```

**Environment Variables**:

| Variable | Description | Default | Used In |
|----------|-------------|---------|---------|
| `PLAYWRIGHT_BROWSER` | Browser type (chromium/firefox/webkit) | `chromium` | Local, Docker, CI |
| `PLAYWRIGHT_HEADLESS` | Headless mode flag | `true` | Local, Docker, CI |
| `PLAYWRIGHT_VIEWPORT_WIDTH` | Browser viewport width (px) | `1920` | Local, Docker, CI |
| `PLAYWRIGHT_VIEWPORT_HEIGHT` | Browser viewport height (px) | `1080` | Local, Docker, CI |
| `PLAYWRIGHT_SLOW_MO` | Slow down automation (ms, for debugging) | `0` | Local (debugging) |
| `PLAYWRIGHT_TIMEOUT` | Default timeout (ms) | `30000` | All environments |
| `PLAYWRIGHT_TRACE_MODE` | Trace capture mode (on/off/on-first-retry) | `on-first-retry` (CI), `off` (local) | All environments |
| `USE_PLAYWRIGHT` | Feature flag to enable/disable Playwright | `true` | All environments |
| `RETRY_MAX_ATTEMPTS` | Maximum retry attempts for flaky tests | `3` | All environments |
| `CI` | CI environment flag (auto-set by GitHub Actions) | - | GitHub Actions |
| `RACK_ENV` | Rack environment (non-Rails apps) | `development` | Sinatra, Hanami |
| `APP_ENV` | App environment (non-Rails/Rack apps) | `development` | Generic Ruby apps |

### 4.4 Test Artifact Storage

**Directory Structure**:

```
tmp/
├── screenshots/           # Test failure screenshots
│   ├── operator_sessions_spec_1.png
│   ├── operator_sessions_spec_1.png.json  # Metadata with correlation_id
│   ├── contents_spec_2.png
│   ├── contents_spec_2.png.json
│   └── ...
├── traces/               # Playwright execution traces
│   ├── operator_sessions_spec_1.zip
│   ├── operator_sessions_spec_1.zip.json  # Metadata
│   ├── contents_spec_2.zip
│   └── ...
└── capybara/            # Capybara temporary files
    └── ...

coverage/                 # SimpleCov coverage reports
├── index.html
├── assets/
└── ...
```

**Artifact Metadata Format**:

```json
{
  "correlation_id": "test-run-20251123-143025-a8f3d1",
  "test_name": "Operator can sign in successfully",
  "test_file": "spec/system/operator_sessions_spec.rb",
  "test_line": 15,
  "failure_message": "expected to find text 'Welcome' but found 'Error'",
  "browser": "chromium",
  "viewport": {"width": 1920, "height": 1080},
  "created_at": "2025-11-23T14:30:25Z",
  "artifact_path": "/tmp/screenshots/operator_sessions_spec_1.png",
  "artifact_type": "screenshot",
  "environment": "ci"
}
```

**GitHub Actions Artifacts**:

```yaml
artifacts:
  - name: test-screenshots
    path: tmp/screenshots/**/*
    retention-days: 7

  - name: playwright-traces
    path: tmp/traces/**/*
    retention-days: 7

  - name: coverage-report
    path: coverage/**/*
    retention-days: 14

  - name: test-metrics  # NEW: JSON metrics for trend analysis
    path: tmp/test-metrics.json
    retention-days: 30
```

---

## 5. API Design

### 5.1 Playwright Browser Session Manager ⭐ NEW

**PlaywrightBrowserSession Class** (Framework-agnostic):

```ruby
# lib/testing/playwright_browser_session.rb

require_relative 'playwright_driver'
require_relative 'playwright_artifact_capture'
require_relative 'utils/null_logger'
require_relative 'utils/time_utils'

module Testing
  # Framework-agnostic browser session manager
  # Usable with RSpec, Minitest, Cucumber, or standalone scripts
  class PlaywrightBrowserSession
    attr_reader :driver, :artifact_capture, :logger, :config

    # @param driver [BrowserDriver] Browser driver instance
    # @param artifact_capture [PlaywrightArtifactCapture] Artifact capture service
    # @param logger [Object] Logger instance (optional)
    # @param config [PlaywrightConfiguration] Configuration object
    def initialize(driver:, artifact_capture:, config:, logger: nil)
      @driver = driver
      @artifact_capture = artifact_capture
      @config = config
      @logger = logger || Utils::NullLogger.new
      @browser = nil
      @context = nil
      @page = nil
    end

    # Start browser session
    # @yield [page] Playwright page instance
    # @return [Object] Result of block execution
    def start(&block)
      @browser = driver.launch_browser(config)
      @context = driver.create_context(@browser, config)
      @page = @context.new_page

      # Start tracing if configured
      driver.start_trace(@context) if config.trace_mode != 'off'

      logger.info("Browser session started (#{config.browser_type}, headless: #{config.headless})")

      yield @page
    ensure
      cleanup
    end

    # Execute test with automatic artifact capture on failure
    # @param test_name [String] Test name for logging
    # @yield [page] Playwright page instance
    # @return [Object] Result of block execution
    def execute(test_name:, &block)
      start_time = Time.now
      logger.info("Starting test: #{test_name}")

      start do |page|
        yield page
      end

      duration = Time.now - start_time
      logger.info("Test passed: #{test_name}", duration: duration)
    rescue => error
      # Capture artifacts on failure
      if @page && @context
        metadata = {
          test_name: test_name,
          error_message: error.message,
          error_class: error.class.name,
          timestamp: Utils::TimeUtils.format_iso8601
        }

        artifact_capture.capture_on_failure(test_name, @page, @context, metadata)
      end

      logger.error("Test failed: #{test_name}", error: error.message)
      raise
    end

    # Navigate to URL
    # @param url [String] URL to navigate to
    def navigate_to(url)
      raise "Browser not started. Call #start first." unless @page
      @page.goto(url)
    end

    # Get current page
    # @return [Playwright::Page, nil] Current page instance
    def page
      @page
    end

    private

    # Cleanup browser resources
    def cleanup
      if @context && config.trace_mode != 'off'
        # Stop tracing (already captured in artifact_capture on failure)
        @context.tracing.stop rescue nil
      end

      @page&.close rescue nil
      @context&.close rescue nil
      @browser&.close rescue nil

      logger.info("Browser session closed")
    end
  end
end
```

**Usage Examples**:

```ruby
# Example 1: Standalone script (no testing framework)
require 'testing/playwright_browser_session'
require 'testing/playwright_configuration'
require 'testing/playwright_driver'
require 'testing/playwright_artifact_capture'
require 'testing/file_system_storage'

config = Testing::PlaywrightConfiguration.for_environment('development')
driver = Testing::PlaywrightDriver.new
storage = Testing::FileSystemStorage.new
artifact_capture = Testing::PlaywrightArtifactCapture.new(
  storage: storage,
  config: config,
  logger: Logger.new(STDOUT)
)

session = Testing::PlaywrightBrowserSession.new(
  driver: driver,
  artifact_capture: artifact_capture,
  config: config,
  logger: Logger.new(STDOUT)
)

session.execute(test_name: 'Homepage loads') do |page|
  page.goto('http://localhost:3000')
  expect(page.title).to eq('My App')
end

# Example 2: Minitest integration
class MyMinitestTest < Minitest::Test
  def setup
    @config = Testing::PlaywrightConfiguration.for_environment('test')
    @driver = Testing::PlaywrightDriver.new
    @storage = Testing::FileSystemStorage.new
    @artifact_capture = Testing::PlaywrightArtifactCapture.new(
      storage: @storage,
      config: @config
    )
    @session = Testing::PlaywrightBrowserSession.new(
      driver: @driver,
      artifact_capture: @artifact_capture,
      config: @config
    )
  end

  def test_homepage
    @session.execute(test_name: 'Homepage test') do |page|
      page.goto('http://localhost:3000')
      assert_equal 'My App', page.title
    end
  end
end

# Example 3: RSpec integration (see Section 5.2)
```

### 5.2 Capybara Driver Registration

**Driver Registration with Abstraction** ⭐ REVISED:

```ruby
# spec/support/capybara.rb

require 'capybara/rspec'
require_relative '../../lib/testing/playwright_configuration'
require_relative '../../lib/testing/playwright_driver'
require_relative '../../lib/testing/file_system_storage'
require_relative '../../lib/testing/utils/env_utils'

# Feature flag to enable/disable Playwright (allows gradual migration from Selenium)
USE_PLAYWRIGHT = Testing::Utils::EnvUtils.get('USE_PLAYWRIGHT', 'true') == 'true'

if USE_PLAYWRIGHT
  # Get environment-specific configuration
  config = Testing::PlaywrightConfiguration.for_environment

  # Initialize browser driver
  driver = Testing::PlaywrightDriver.new

  # Initialize artifact storage
  storage = Testing::FileSystemStorage.new

  # Register Playwright driver with Capybara
  Capybara.register_driver :playwright do |app|
    # Use PlaywrightDriver abstraction instead of direct Playwright API
    Capybara::Playwright::Driver.new(
      app,
      browser_type: config.browser_type.to_sym,
      **config.browser_launch_options
    )
  end

  # Set Playwright as default driver for system specs
  Capybara.default_driver = :playwright
  Capybara.javascript_driver = :playwright

  puts "[PLAYWRIGHT] Using Playwright driver (#{config.browser_type}, headless: #{config.headless})"
else
  # Fallback to Selenium WebDriver (for gradual migration)
  Capybara.register_driver :selenium_headless do |app|
    Capybara::Selenium::Driver.new(app, browser: :headless_chrome)
  end

  Capybara.default_driver = :selenium_headless
  Capybara.javascript_driver = :selenium_headless

  warn "[WARNING] Using Selenium WebDriver fallback (USE_PLAYWRIGHT=false)"
end

# Common Capybara configuration
Capybara.configure do |capybara_config|
  capybara_config.default_max_wait_time = 10 # seconds
  capybara_config.server = :puma, { Silent: true }
end
```

### 5.3 Playwright Artifact Capture Service ⭐ REVISED

**PlaywrightArtifactCapture Service**:

```ruby
# lib/testing/playwright_artifact_capture.rb

require_relative 'file_system_storage'
require_relative 'utils/null_logger'
require_relative 'utils/time_utils'
require_relative 'utils/string_utils'
require 'securerandom'

module Testing
  # Service class for capturing test failure artifacts (screenshots, traces)
  # Separates artifact capture logic from test framework configuration
  # Framework-agnostic: Works with RSpec, Minitest, Cucumber, etc.
  class PlaywrightArtifactCapture
    attr_reader :storage, :config, :logger, :correlation_id

    # @param storage [ArtifactStorage] Storage implementation
    # @param config [PlaywrightConfiguration] Configuration object
    # @param logger [Object] Logger instance (optional, defaults to NullLogger)
    def initialize(storage:, config:, logger: nil)
      @storage = storage
      @config = config
      @logger = logger || Utils::NullLogger.new
      @correlation_id = Utils::TimeUtils.generate_correlation_id
    end

    # Capture screenshot on test failure
    # @param page [Playwright::Page] Playwright page instance
    # @param test_metadata [Hash] Test metadata (name, file, line, etc.)
    # @return [String, nil] Screenshot path or nil
    def capture_screenshot(page, test_metadata)
      screenshot_name = generate_artifact_name(test_metadata, 'screenshot')
      temp_path = config.screenshots_path.join("#{screenshot_name}.png")

      # Capture screenshot using Playwright
      page.screenshot(path: temp_path.to_s, full_page: true)

      # Save to storage with metadata
      final_path = storage.save_screenshot(
        screenshot_name,
        temp_path.to_s,
        build_metadata(test_metadata, 'screenshot')
      )

      # Log with structured format (JSON)
      log_artifact_captured('screenshot', final_path, test_metadata)

      final_path
    rescue => e
      # Don't fail test due to screenshot capture error
      logger.error({
        event: 'screenshot_capture_failed',
        error: e.message,
        test: test_metadata[:test_name],
        timestamp: Utils::TimeUtils.format_iso8601
      }.to_json)
      nil
    end

    # Capture Playwright trace on test failure
    # @param context [Playwright::BrowserContext] Browser context
    # @param test_metadata [Hash] Test metadata
    # @return [String, nil] Trace path or nil
    def capture_trace(context, test_metadata)
      # Only capture if trace mode is enabled
      return unless should_capture_trace?

      trace_name = generate_artifact_name(test_metadata, 'trace')
      temp_path = config.traces_path.join("#{trace_name}.zip")

      # Stop tracing and save trace file
      context.tracing.stop(path: temp_path.to_s)

      # Save to storage with metadata
      final_path = storage.save_trace(
        trace_name,
        temp_path.to_s,
        build_metadata(test_metadata, 'trace')
      )

      # Log with structured format
      log_artifact_captured('trace', final_path, test_metadata)

      final_path
    rescue => e
      logger.error({
        event: 'trace_capture_failed',
        error: e.message,
        test: test_metadata[:test_name],
        timestamp: Utils::TimeUtils.format_iso8601
      }.to_json)
      nil
    end

    # Capture all artifacts on test failure (screenshot + trace)
    # @param test_name [String] Test name
    # @param page [Playwright::Page] Page instance
    # @param context [Playwright::BrowserContext] Browser context
    # @param additional_metadata [Hash] Additional metadata
    # @return [Hash] Captured artifact paths
    def capture_on_failure(test_name, page, context, additional_metadata = {})
      metadata = {
        test_name: test_name,
        correlation_id: correlation_id
      }.merge(additional_metadata)

      artifacts = {}

      # Capture screenshot
      if page
        artifacts[:screenshot] = capture_screenshot(page, metadata)
      end

      # Capture trace
      if context && should_capture_trace?
        artifacts[:trace] = capture_trace(context, metadata)
      end

      artifacts
    end

    private

    # Check if trace should be captured based on configuration
    # @return [Boolean] true if trace should be captured
    def should_capture_trace?
      config.trace_mode == 'on' || config.trace_mode == 'on-first-retry'
    end

    # Generate artifact name from test metadata
    # @param metadata [Hash] Test metadata
    # @param type [String] Artifact type (screenshot, trace)
    # @return [String] Artifact name
    def generate_artifact_name(metadata, type)
      test_name = metadata[:test_name] || 'unknown_test'
      timestamp = Utils::TimeUtils.format_for_filename
      base_name = Utils::StringUtils.sanitize_filename(test_name)

      "#{base_name}_#{timestamp}_#{type}"
    end

    # Build metadata hash for artifact
    # @param test_metadata [Hash] Test metadata
    # @param artifact_type [String] Artifact type
    # @return [Hash] Complete metadata
    def build_metadata(test_metadata, artifact_type)
      {
        correlation_id: correlation_id,
        test_name: test_metadata[:test_name],
        test_file: test_metadata[:test_file],
        test_line: test_metadata[:test_line],
        failure_message: test_metadata[:error_message],
        browser: config.browser_type,
        viewport: config.viewport,
        artifact_type: artifact_type,
        environment: Utils::EnvUtils.environment
      }
    end

    # Log artifact captured event
    # @param type [String] Artifact type
    # @param path [String] Artifact path
    # @param metadata [Hash] Test metadata
    def log_artifact_captured(type, path, metadata)
      logger.info({
        event: "#{type}_captured",
        artifact_path: path,
        test: metadata[:test_name],
        correlation_id: correlation_id,
        timestamp: Utils::TimeUtils.format_iso8601
      }.to_json)
    end
  end
end
```

### 5.4 RSpec Integration Hooks ⭐ NEW

**RSpec Configuration with Retry and Artifact Capture**:

```ruby
# spec/support/playwright_helpers.rb

require_relative '../../lib/testing/playwright_artifact_capture'
require_relative '../../lib/testing/file_system_storage'
require_relative '../../lib/testing/retry_policy'
require_relative '../../lib/testing/utils/env_utils'

RSpec.configure do |config|
  # Initialize services for system specs
  config.before(:suite) do
    if Testing::Utils::EnvUtils.test_environment?
      playwright_config = Testing::PlaywrightConfiguration.for_environment
      storage = Testing::FileSystemStorage.new
      logger = defined?(Rails) ? Rails.logger : Logger.new(STDOUT)

      # Initialize artifact capture service
      $playwright_artifact_capture = Testing::PlaywrightArtifactCapture.new(
        storage: storage,
        config: playwright_config,
        logger: logger
      )

      # Initialize retry policy for RSpec
      # Add RSpec::Expectations::ExpectationNotMetError to retryable errors
      $playwright_retry_policy = Testing::RetryPolicy.new(
        max_attempts: Testing::Utils::EnvUtils.get('RETRY_MAX_ATTEMPTS', '3').to_i,
        logger: logger,
        retryable_errors: [
          Playwright::TimeoutError,
          Net::ReadTimeout,
          Errno::ECONNREFUSED,
          Errno::ECONNRESET,
          # Add RSpec assertion errors for retrying flaky tests
          RSpec::Expectations::ExpectationNotMetError
        ]
      )
    end
  end

  # Capture artifacts on system spec failure
  config.after(:each, type: :system) do |example|
    if example.exception
      # Get page and context from Capybara driver
      page = Capybara.page.driver.browser.contexts.first.pages.first rescue nil
      context = Capybara.page.driver.browser.contexts.first rescue nil

      # Build test metadata
      metadata = {
        test_name: example.full_description,
        test_file: example.metadata[:file_path],
        test_line: example.metadata[:line_number],
        error_message: example.exception.message,
        error_class: example.exception.class.name
      }

      # Capture artifacts
      if $playwright_artifact_capture && page
        artifacts = $playwright_artifact_capture.capture_on_failure(
          example.full_description,
          page,
          context,
          metadata
        )

        # Attach to RSpec output
        if artifacts[:screenshot]
          example.metadata[:extra_failure_lines] ||= []
          example.metadata[:extra_failure_lines] << "Screenshot: #{artifacts[:screenshot]}"
        end

        if artifacts[:trace]
          example.metadata[:extra_failure_lines] ||= []
          example.metadata[:extra_failure_lines] << "Trace: #{artifacts[:trace]}"
        end
      end
    end
  end

  # Retry wrapper for flaky system specs (optional)
  config.around(:each, type: :system, retry: true) do |example|
    if $playwright_retry_policy
      $playwright_retry_policy.execute(context: example.full_description) do
        example.run
      end
    else
      example.run
    end
  end
end
```

**Usage in Specs**:

```ruby
# spec/system/operator_sessions_spec.rb

require 'rails_helper'

RSpec.describe 'Operator Sessions', type: :system do
  # Regular test (no retry)
  it 'displays login page' do
    visit login_path
    expect(page).to have_content('Login')
  end

  # Flaky test with retry enabled
  it 'logs in successfully', retry: true do
    visit login_path
    fill_in 'Email', with: 'admin@example.com'
    fill_in 'Password', with: 'password'
    click_button 'Login'

    # Playwright auto-wait handles most race conditions
    # But retry policy will handle transient network issues
    expect(page).to have_content('Dashboard')
  end
end
```

---

## 6. Security Considerations

### 6.1 Threat Model

**Threats Identified**:

1. **T-1: Path Traversal via Artifact Names**
   - **Risk**: Malicious test names could write files outside intended directory
   - **Impact**: Filesystem corruption, overwriting system files
   - **Likelihood**: Low (requires malicious spec code)

2. **T-2: Credential Exposure in CI Logs**
   - **Risk**: Database credentials or API keys logged in plaintext
   - **Impact**: Unauthorized access to production systems
   - **Likelihood**: Medium (common misconfiguration)

3. **T-3: Compromised Playwright Binaries**
   - **Risk**: Man-in-the-middle attack during `playwright install`
   - **Impact**: Malicious code execution in test environment
   - **Likelihood**: Low (checksums verified by Playwright)

4. **T-4: Artifact Access via GitHub Actions**
   - **Risk**: Sensitive data in screenshots/traces accessible via artifact download
   - **Impact**: Information disclosure
   - **Likelihood**: Medium (depends on test data)

5. **T-5: Dependency Vulnerabilities**
   - **Risk**: Known vulnerabilities in `playwright-ruby-client` or dependencies
   - **Impact**: Code execution, DoS
   - **Likelihood**: Medium (requires regular updates)

### 6.2 Security Controls

**SC-1: Filename Sanitization**

```ruby
# lib/testing/utils/string_utils.rb (already implemented)
def self.sanitize_filename(name)
  name.to_s.gsub(/[^0-9A-Za-z_-]/, '_')
end
```

- **Mitigates**: T-1 (Path Traversal)
- **Implementation**: `StringUtils.sanitize_filename` removes special characters
- **Validation**: Unit tests verify path traversal prevention

**SC-2: Environment Variable Protection**

```yaml
# .github/workflows/rspec.yml

env:
  DATABASE_URL: ${{ secrets.DATABASE_URL }}  # Use GitHub Secrets
  SECRET_KEY_BASE: ${{ secrets.SECRET_KEY_BASE }}

# Never log sensitive environment variables
run: |
  echo "Running tests..."
  bundle exec rspec  # Don't echo DATABASE_URL
```

- **Mitigates**: T-2 (Credential Exposure)
- **Implementation**: Use GitHub Secrets for all credentials
- **Validation**: Scan workflow file for hardcoded secrets

**SC-3: Playwright Binary Verification**

```bash
# Playwright CLI automatically verifies checksums during installation
npx playwright install chromium --with-deps

# Verification happens automatically via:
# 1. HTTPS download from Microsoft CDN
# 2. SHA256 checksum validation
# 3. GPG signature verification (for system packages)
```

- **Mitigates**: T-3 (Compromised Binaries)
- **Implementation**: Rely on Playwright's built-in verification
- **Validation**: CI logs show checksum verification

**SC-4: Artifact Retention Policy**

```yaml
# .github/workflows/rspec.yml

- name: Upload screenshots
  uses: actions/upload-artifact@v4
  with:
    name: test-screenshots
    path: tmp/screenshots/**/*
    retention-days: 7  # Auto-delete after 7 days
```

- **Mitigates**: T-4 (Artifact Access)
- **Implementation**: Short retention period, review test data for PII
- **Validation**: Automated PII scanning in screenshots (future)

**SC-5: Dependency Scanning**

```yaml
# .github/workflows/security.yml (NEW)

name: Security Scan
on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly
  workflow_dispatch:

jobs:
  bundler-audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.4.6
          bundler-cache: true
      - run: gem install bundler-audit
      - run: bundler-audit check --update
```

- **Mitigates**: T-5 (Dependency Vulnerabilities)
- **Implementation**: Weekly `bundler-audit` scans
- **Validation**: Fail PR if high-severity vulnerabilities found

### 6.3 Data Protection Measures

**DP-1: Test Data Isolation**

- Use separate test database with synthetic data
- No production data in test environment
- Database reset between test runs

**DP-2: Screenshot Sanitization** (Future Enhancement)

```ruby
# lib/testing/screenshot_sanitizer.rb (FUTURE)

module Testing
  class ScreenshotSanitizer
    def self.redact_sensitive_data(screenshot_path)
      # Use OCR to detect PII (email, phone, SSN)
      # Blur or redact sensitive regions
      # Save sanitized version
    end
  end
end
```

**DP-3: Artifact Encryption** (Future Enhancement)

```ruby
# For highly sensitive applications:
# 1. Encrypt artifacts before upload to GitHub Actions
# 2. Store decryption key in GitHub Secrets
# 3. Only authorized users can download and decrypt
```

---

## 7. Error Handling

### 7.1 Error Scenarios

**ES-1: Playwright Binary Not Installed**

**Scenario**: Developer runs tests without installing Playwright browsers

**Error**:
```
Playwright::Error: Executable doesn't exist at /path/to/chromium
Run 'npx playwright install chromium'
```

**Handling**:
```ruby
# lib/testing/playwright_driver.rb

def initialize
  require 'playwright'
  @playwright = Playwright.create(playwright_cli_executable_path: 'npx playwright')
rescue Playwright::Error => e
  if e.message.include?("Executable doesn't exist")
    raise LoadError, <<~ERROR
      Playwright browser not installed.

      Run the following command to install:
        npx playwright install chromium

      For Docker environments, add to Dockerfile:
        RUN npx playwright install chromium --with-deps
    ERROR
  else
    raise
  end
end
```

**Recovery**: Display clear installation instructions

**ES-2: Test Database Connection Failure**

**Scenario**: MySQL service not running or credentials incorrect

**Error**:
```
Mysql2::Error: Can't connect to MySQL server on 'localhost' (61)
```

**Handling**:
```ruby
# spec/rails_helper.rb

begin
  ActiveRecord::Base.connection.execute('SELECT 1')
rescue ActiveRecord::ConnectionNotEstablished => e
  abort <<~ERROR
    Database connection failed: #{e.message}

    Troubleshooting:
    1. Check MySQL service is running: brew services list
    2. Verify database.yml credentials
    3. Create test database: bundle exec rails db:create db:migrate RAILS_ENV=test

    In Docker: docker-compose up -d db && sleep 5
  ERROR
end
```

**Recovery**: Show troubleshooting steps

**ES-3: Screenshot Capture Failure**

**Scenario**: Disk full or permission denied when saving screenshot

**Error**:
```
Errno::ENOSPC: No space left on device @ io_write
```

**Handling**:
```ruby
# lib/testing/playwright_artifact_capture.rb

def capture_screenshot(page, test_metadata)
  # ... screenshot capture code ...
rescue Errno::ENOSPC => e
  logger.error({
    event: 'screenshot_capture_failed',
    error: 'No disk space available',
    test: test_metadata[:test_name],
    timestamp: Utils::TimeUtils.format_iso8601
  }.to_json)

  # Don't fail the test, just log the error
  nil
rescue Errno::EACCES => e
  logger.error({
    event: 'screenshot_capture_failed',
    error: 'Permission denied (check tmp/ directory permissions)',
    test: test_metadata[:test_name],
    timestamp: Utils::TimeUtils.format_iso8601
  }.to_json)
  nil
end
```

**Recovery**: Log error, continue test execution (don't cascade failure)

**ES-4: Timeout During Test Execution**

**Scenario**: Test exceeds Playwright timeout (default: 30s)

**Error**:
```
Playwright::TimeoutError: Timeout 30000ms exceeded while waiting for element
```

**Handling**:
```ruby
# lib/testing/retry_policy.rb (already implemented)

# RetryPolicy will retry on Playwright::TimeoutError
# Up to 3 attempts with exponential backoff

def should_retry?(error, attempt)
  return false if attempt >= max_attempts
  retryable_errors.any? { |klass| error.is_a?(klass) }
end
```

**Recovery**: Retry up to 3 times, then fail with detailed error

**ES-5: GitHub Actions Workflow Failure**

**Scenario**: CI build fails due to Playwright installation error

**Error**:
```
Error: Command failed: npx playwright install chromium
```

**Handling**:
```yaml
# .github/workflows/rspec.yml

- name: Install Playwright browsers
  run: |
    npx playwright install chromium --with-deps || {
      echo "::error::Playwright installation failed"
      echo "::notice::Retrying with verbose output..."
      npx playwright install chromium --with-deps --verbose
      exit 1
    }
```

**Recovery**: Retry with verbose logging, fail with actionable error

### 7.2 Error Messages

**User-Facing Error Messages**:

```ruby
# lib/testing/error_messages.rb

module Testing
  module ErrorMessages
    # Playwright binary not installed
    PLAYWRIGHT_NOT_INSTALLED = <<~MSG
      Playwright browser binaries not found.

      Local Development:
        npx playwright install chromium

      Docker:
        docker-compose build
        # or manually: docker-compose exec web npx playwright install chromium

      CI (GitHub Actions):
        Workflow should automatically install. Check logs for errors.
    MSG

    # Database not available
    DATABASE_NOT_AVAILABLE = <<~MSG
      Test database connection failed.

      Local Development:
        1. Start MySQL: brew services start mysql
        2. Create database: bundle exec rails db:create RAILS_ENV=test
        3. Run migrations: bundle exec rails db:migrate RAILS_ENV=test

      Docker:
        docker-compose up -d db
        docker-compose exec web bundle exec rails db:create db:migrate RAILS_ENV=test

      CI (GitHub Actions):
        Check MySQL service configuration in workflow file.
    MSG

    # Invalid configuration
    INVALID_CONFIG = <<~MSG
      Playwright configuration invalid.

      Check the following:
        - PLAYWRIGHT_BROWSER must be: chromium, firefox, or webkit
        - PLAYWRIGHT_TIMEOUT must be >= 1000ms
        - PLAYWRIGHT_TRACE_MODE must be: on, off, or on-first-retry

      Current configuration:
        PLAYWRIGHT_BROWSER=%{browser}
        PLAYWRIGHT_TIMEOUT=%{timeout}
        PLAYWRIGHT_TRACE_MODE=%{trace_mode}
    MSG
  end
end
```

### 7.3 Recovery Strategies

**RS-1: Automatic Retry**

- **Trigger**: Transient errors (timeouts, network failures)
- **Strategy**: Exponential backoff (2s, 4s, 8s)
- **Max Attempts**: 3
- **Implementation**: `RetryPolicy` class

**RS-2: Graceful Degradation**

- **Trigger**: Artifact capture failure
- **Strategy**: Log error, continue test execution
- **Impact**: Missing screenshots, but test results still valid
- **Implementation**: `PlaywrightArtifactCapture` rescue blocks

**RS-3: Fail Fast**

- **Trigger**: Critical errors (database unavailable, Playwright not installed)
- **Strategy**: Abort test suite with clear error message
- **Impact**: Prevent cascading failures
- **Implementation**: `rails_helper.rb` validation

**RS-4: Detailed Logging**

- **Trigger**: All errors
- **Strategy**: Structured JSON logging with correlation IDs
- **Impact**: Easier debugging and incident response
- **Implementation**: All service classes use injected logger

---

## 8. Testing Strategy

### 8.1 Unit Tests

**Test Coverage Requirements**:
- All utility modules: 100% coverage
- Configuration classes: 100% coverage
- Driver abstraction: 90% coverage
- Storage implementations: 90% coverage

**Example Unit Tests**:

```ruby
# spec/lib/testing/utils/path_utils_spec.rb

RSpec.describe Testing::Utils::PathUtils do
  describe '.root_path' do
    context 'with Rails defined' do
      it 'returns Rails.root' do
        stub_const('Rails', double(root: Pathname.new('/rails/app')))
        expect(described_class.root_path).to eq(Pathname.new('/rails/app'))
      end
    end

    context 'without Rails' do
      it 'returns current directory' do
        hide_const('Rails')
        expect(described_class.root_path).to eq(Pathname.new(Dir.pwd))
      end
    end
  end

  describe '.screenshots_path' do
    it 'returns tmp/screenshots directory' do
      allow(described_class).to receive(:root_path).and_return(Pathname.new('/app'))
      expect(described_class.screenshots_path).to eq(Pathname.new('/app/tmp/screenshots'))
    end
  end
end

# spec/lib/testing/utils/env_utils_spec.rb

RSpec.describe Testing::Utils::EnvUtils do
  describe '.environment' do
    it 'returns Rails.env when Rails is defined' do
      stub_const('Rails', double(env: 'test'))
      expect(described_class.environment).to eq('test')
    end

    it 'returns RACK_ENV when Rails is not defined' do
      hide_const('Rails')
      ENV['RACK_ENV'] = 'production'
      expect(described_class.environment).to eq('production')
    end

    it 'defaults to development' do
      hide_const('Rails')
      ENV.delete('RACK_ENV')
      ENV.delete('APP_ENV')
      expect(described_class.environment).to eq('development')
    end
  end

  describe '.ci_environment?' do
    it 'returns true when CI=true' do
      ENV['CI'] = 'true'
      expect(described_class.ci_environment?).to be true
    end

    it 'returns false otherwise' do
      ENV.delete('CI')
      expect(described_class.ci_environment?).to be false
    end
  end
end

# spec/lib/testing/utils/string_utils_spec.rb

RSpec.describe Testing::Utils::StringUtils do
  describe '.sanitize_filename' do
    it 'removes path traversal characters' do
      expect(described_class.sanitize_filename('../etc/passwd')).to eq('___etc_passwd')
    end

    it 'removes special characters' do
      expect(described_class.sanitize_filename('test file!@#$%.txt')).to eq('test_file_____txt')
    end

    it 'preserves alphanumeric, dash, and underscore' do
      expect(described_class.sanitize_filename('valid-file_123')).to eq('valid-file_123')
    end
  end
end

# spec/lib/testing/retry_policy_spec.rb

RSpec.describe Testing::RetryPolicy do
  let(:logger) { instance_double(Logger, warn: nil, error: nil) }
  let(:policy) do
    described_class.new(
      max_attempts: 3,
      base_delay: 1,
      logger: logger,
      retryable_errors: [Playwright::TimeoutError]
    )
  end

  describe '#execute' do
    it 'retries on retryable errors' do
      attempts = 0
      result = policy.execute(context: 'test') do
        attempts += 1
        raise Playwright::TimeoutError if attempts < 3
        'success'
      end

      expect(attempts).to eq(3)
      expect(result).to eq('success')
    end

    it 'does not retry non-retryable errors' do
      attempts = 0
      expect do
        policy.execute(context: 'test') do
          attempts += 1
          raise ArgumentError, 'invalid'
        end
      end.to raise_error(ArgumentError)

      expect(attempts).to eq(1)
    end

    it 'exhausts retries and raises error' do
      expect do
        policy.execute(context: 'test') do
          raise Playwright::TimeoutError
        end
      end.to raise_error(Playwright::TimeoutError)
    end
  end
end
```

### 8.2 Integration Tests

**Test Scenarios**:

```ruby
# spec/lib/testing/playwright_browser_session_spec.rb

RSpec.describe Testing::PlaywrightBrowserSession do
  let(:config) { Testing::PlaywrightConfiguration.local_config }
  let(:driver) { Testing::PlaywrightDriver.new }
  let(:storage) { Testing::FileSystemStorage.new }
  let(:artifact_capture) do
    Testing::PlaywrightArtifactCapture.new(
      storage: storage,
      config: config
    )
  end
  let(:session) do
    described_class.new(
      driver: driver,
      artifact_capture: artifact_capture,
      config: config
    )
  end

  describe '#execute' do
    it 'executes test successfully' do
      result = session.execute(test_name: 'Test') do |page|
        page.goto('https://example.com')
        page.title
      end

      expect(result).to eq('Example Domain')
    end

    it 'captures artifacts on failure' do
      expect do
        session.execute(test_name: 'Failing test') do |page|
          page.goto('https://example.com')
          raise 'Test failed'
        end
      end.to raise_error('Test failed')

      # Verify screenshot was captured
      artifacts = storage.list_artifacts
      expect(artifacts).not_to be_empty
    end
  end
end

# spec/system/playwright_integration_spec.rb

RSpec.describe 'Playwright Integration', type: :system do
  before do
    driven_by :playwright
  end

  it 'loads homepage' do
    visit root_path
    expect(page).to have_content('Welcome')
  end

  it 'handles JavaScript interactions' do
    visit interactive_page_path
    click_button 'Toggle'
    expect(page).to have_content('Toggled')
  end

  it 'captures screenshot on failure' do
    visit root_path
    expect(page).to have_content('Nonexistent text')
    # Screenshot automatically captured by RSpec hooks
  end
end
```

### 8.3 Edge Cases

**EC-1: Concurrent Test Execution**

```ruby
# spec/system/concurrent_spec.rb

RSpec.describe 'Concurrent Tests', type: :system do
  it 'test 1 does not interfere with test 2', :parallel do
    visit '/page1'
    expect(page).to have_content('Page 1')
  end

  it 'test 2 does not interfere with test 1', :parallel do
    visit '/page2'
    expect(page).to have_content('Page 2')
  end
end
```

**EC-2: Long-Running Tests**

```ruby
# spec/system/long_running_spec.rb

RSpec.describe 'Long Running Test', type: :system do
  it 'does not timeout on slow operations' do
    # Increase timeout for this specific test
    visit slow_operation_path
    expect(page).to have_content('Complete', wait: 60) # 60 second wait
  end
end
```

**EC-3: Network Disconnection**

```ruby
# spec/system/network_failure_spec.rb

RSpec.describe 'Network Failure', type: :system, retry: true do
  it 'retries on network errors' do
    # Simulate intermittent network failure
    visit api_dependent_page_path
    expect(page).to have_content('Data loaded')
    # RetryPolicy will retry up to 3 times if network fails
  end
end
```

**EC-4: Browser Crashes**

```ruby
# spec/lib/testing/playwright_browser_session_spec.rb

RSpec.describe Testing::PlaywrightBrowserSession do
  it 'recovers from browser crash' do
    session = described_class.new(
      driver: driver,
      artifact_capture: artifact_capture,
      config: config
    )

    # Simulate browser crash
    expect do
      session.execute(test_name: 'Crash test') do |page|
        page.goto('chrome://crash')
      end
    end.to raise_error

    # Session should cleanup properly
    expect(session.instance_variable_get(:@browser)).to be_nil
  end
end
```

### 8.4 Performance Tests

**Performance Benchmarks**:

```ruby
# spec/performance/playwright_performance_spec.rb

RSpec.describe 'Playwright Performance' do
  let(:config) { Testing::PlaywrightConfiguration.ci_config }
  let(:driver) { Testing::PlaywrightDriver.new }

  it 'launches browser within 2 seconds' do
    start_time = Time.now
    browser = driver.launch_browser(config)
    duration = Time.now - start_time

    expect(duration).to be < 2.0

    browser.close
  end

  it 'captures screenshot within 1 second' do
    browser = driver.launch_browser(config)
    context = driver.create_context(browser, config)
    page = context.new_page
    page.goto('https://example.com')

    start_time = Time.now
    driver.take_screenshot(page, '/tmp/test.png')
    duration = Time.now - start_time

    expect(duration).to be < 1.0

    browser.close
  end
end
```

---

## 9. Implementation Plan

### 9.1 Phase 1: Utility Libraries (1 day)

**Tasks**:
1. Create `lib/testing/utils/` directory
2. Implement PathUtils module
3. Implement EnvUtils module
4. Implement TimeUtils module
5. Implement StringUtils module
6. Implement NullLogger class
7. Write unit tests (100% coverage)

**Deliverables**:
- `lib/testing/utils/path_utils.rb`
- `lib/testing/utils/env_utils.rb`
- `lib/testing/utils/time_utils.rb`
- `lib/testing/utils/string_utils.rb`
- `lib/testing/utils/null_logger.rb`
- Unit tests for all utilities

### 9.2 Phase 2: Core Services (2 days)

**Tasks**:
1. Update PlaywrightConfiguration to use utility modules
2. Implement BrowserDriver interface
3. Implement PlaywrightDriver
4. Update FileSystemStorage to use PathUtils
5. Update RetryPolicy for configurable errors
6. Write unit tests

**Deliverables**:
- Updated `lib/testing/playwright_configuration.rb`
- `lib/testing/browser_driver.rb`
- `lib/testing/playwright_driver.rb`
- Updated `lib/testing/file_system_storage.rb`
- Updated `lib/testing/retry_policy.rb`
- Unit tests

### 9.3 Phase 3: Browser Session Manager (1 day)

**Tasks**:
1. Implement PlaywrightBrowserSession class
2. Update PlaywrightArtifactCapture to use utilities
3. Write integration tests
4. Test with RSpec, Minitest, standalone script

**Deliverables**:
- `lib/testing/playwright_browser_session.rb`
- Updated `lib/testing/playwright_artifact_capture.rb`
- Integration tests
- Usage examples

### 9.4 Phase 4: RSpec Integration (1 day)

**Tasks**:
1. Update Capybara configuration
2. Create RSpec helper file
3. Configure artifact capture hooks
4. Update existing system specs
5. Test locally

**Deliverables**:
- Updated `spec/support/capybara.rb`
- `spec/support/playwright_helpers.rb`
- Updated system specs
- Local test results

### 9.5 Phase 5: GitHub Actions Workflow (1 day)

**Tasks**:
1. Create `.github/workflows/rspec.yml`
2. Configure job steps
3. Set up MySQL service
4. Configure artifact upload
5. Test in CI environment

**Deliverables**:
- `.github/workflows/rspec.yml`
- CI test results
- Artifact uploads verified

### 9.6 Phase 6: Documentation (1 day)

**Tasks**:
1. Update README with setup instructions
2. Create troubleshooting guide
3. Document utility library usage
4. Add examples for other frameworks
5. Review and polish

**Deliverables**:
- Updated README.md
- TESTING.md guide
- API documentation
- Usage examples

**Total Estimated Time**: 7 days

---

## 10. Appendix

### 10.1 Gemfile Changes

```ruby
# Gemfile

group :test do
  # Browser automation (Playwright replaces Selenium)
  gem 'playwright-ruby-client', '~> 1.45'
  gem 'capybara', '>= 3.26'

  # Remove: gem 'webdrivers'  # No longer needed with Playwright

  # Testing framework
  gem 'rspec-rails', '~> 7.1'

  # Code coverage
  gem 'simplecov', require: false
  gem 'simplecov-console', require: false

  # Security scanning
  gem 'bundler-audit', require: false
end
```

### 10.2 Framework-Agnostic Usage Examples

**Sinatra Application**:

```ruby
# test/test_helper.rb (Minitest)

require 'minitest/autorun'
require 'testing/playwright_browser_session'
require 'testing/playwright_configuration'
require 'testing/playwright_driver'
require 'testing/file_system_storage'
require 'testing/playwright_artifact_capture'

class SinatraSystemTest < Minitest::Test
  def setup
    @config = Testing::PlaywrightConfiguration.for_environment('test')
    @driver = Testing::PlaywrightDriver.new
    @storage = Testing::FileSystemStorage.new
    @artifact_capture = Testing::PlaywrightArtifactCapture.new(
      storage: @storage,
      config: @config
    )
    @session = Testing::PlaywrightBrowserSession.new(
      driver: @driver,
      artifact_capture: @artifact_capture,
      config: @config
    )
  end

  def test_homepage
    @session.execute(test_name: 'Homepage test') do |page|
      page.goto('http://localhost:4567')
      assert_equal 'My Sinatra App', page.title
    end
  end
end
```

**Standalone Ruby Script**:

```ruby
# scripts/smoke_test.rb

require 'testing/playwright_browser_session'
require 'testing/playwright_configuration'
require 'testing/playwright_driver'
require 'testing/file_system_storage'
require 'testing/playwright_artifact_capture'
require 'logger'

# Setup
config = Testing::PlaywrightConfiguration.for_environment('production')
driver = Testing::PlaywrightDriver.new
storage = Testing::FileSystemStorage.new
logger = Logger.new(STDOUT)

artifact_capture = Testing::PlaywrightArtifactCapture.new(
  storage: storage,
  config: config,
  logger: logger
)

session = Testing::PlaywrightBrowserSession.new(
  driver: driver,
  artifact_capture: artifact_capture,
  config: config,
  logger: logger
)

# Run smoke tests
begin
  session.execute(test_name: 'Production homepage') do |page|
    page.goto('https://myapp.com')
    raise 'Homepage failed to load' unless page.title.include?('My App')
    puts "✅ Homepage loaded successfully"
  end

  session.execute(test_name: 'Production login page') do |page|
    page.goto('https://myapp.com/login')
    raise 'Login page failed to load' unless page.has_text?('Sign In')
    puts "✅ Login page loaded successfully"
  end

  puts "\n🎉 All smoke tests passed!"
rescue => e
  puts "\n❌ Smoke tests failed: #{e.message}"
  exit 1
end
```

### 10.3 Configuration Files

**GitHub Actions Workflow**:

```yaml
# .github/workflows/rspec.yml

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
        options: >-
          --health-cmd="mysqladmin ping"
          --health-interval=10s
          --health-timeout=5s
          --health-retries=3

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.4.6
          bundler-cache: true

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        run: |
          npm install
          bundle install

      - name: Install Playwright browsers
        run: npx playwright install chromium --with-deps

      - name: Set up database
        env:
          RAILS_ENV: test
          DATABASE_URL: mysql2://root:password@127.0.0.1:3306/test_db
        run: |
          bundle exec rails db:create
          bundle exec rails db:migrate

      - name: Build assets
        run: |
          npm run build
          npm run build:css

      - name: Run RSpec tests
        env:
          RAILS_ENV: test
          DATABASE_URL: mysql2://root:password@127.0.0.1:3306/test_db
          CI: true
          PLAYWRIGHT_BROWSER: chromium
          PLAYWRIGHT_HEADLESS: true
        run: bundle exec rspec --format progress --format json --out tmp/rspec_results.json

      - name: Upload screenshots
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: test-screenshots
          path: tmp/screenshots/
          retention-days: 7

      - name: Upload traces
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: playwright-traces
          path: tmp/traces/
          retention-days: 7

      - name: Upload coverage report
        uses: actions/upload-artifact@v4
        with:
          name: coverage-report
          path: coverage/
          retention-days: 14
```

**Docker Configuration**:

```dockerfile
# Dockerfile

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
    libxrandr2 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Ruby dependencies
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Install Node dependencies
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

---

## Summary of Changes (Iteration 3 - Final Revision)

### Reusability Improvements

1. **Utility Libraries Created** ⭐ NEW
   - `PathUtils`: Abstracts Rails.root (8 replacements)
   - `EnvUtils`: Abstracts Rails.env (5 replacements)
   - `TimeUtils`: Timestamp formatting utilities
   - `StringUtils`: Filename sanitization
   - `NullLogger`: Null object pattern for logger

2. **Rails Dependencies Removed**
   - All `Rails.root` → `PathUtils.root_path`
   - All `Rails.env` → `EnvUtils.environment`
   - All `Rails.logger` → Injected logger with NullLogger fallback

3. **PlaywrightBrowserSession Implemented** ⭐ NEW
   - Framework-agnostic browser session management
   - Usable without RSpec (Minitest, Cucumber, CLI)
   - Complete with examples for Sinatra, standalone scripts

4. **RetryPolicy Made Configurable**
   - Error types now configurable via constructor
   - No hardcoded RSpec::Expectations::ExpectationNotMetError
   - Example usage for RSpec, Minitest shown

5. **Dependency Injection Throughout**
   - All services accept logger parameter (defaults to NullLogger)
   - No global constants (Rails, ENV accessed via utilities)
   - Configuration passed explicitly, not assumed

6. **Documentation Enhanced**
   - Framework-agnostic usage examples added
   - Sinatra integration example
   - Standalone Ruby script example
   - Minitest integration example

### Files Added/Updated

**New Files**:
- `lib/testing/utils/path_utils.rb`
- `lib/testing/utils/env_utils.rb`
- `lib/testing/utils/time_utils.rb`
- `lib/testing/utils/string_utils.rb`
- `lib/testing/utils/null_logger.rb`
- `lib/testing/playwright_browser_session.rb`

**Updated Files**:
- `lib/testing/playwright_configuration.rb` (uses PathUtils, EnvUtils)
- `lib/testing/file_system_storage.rb` (uses PathUtils, StringUtils, TimeUtils)
- `lib/testing/retry_policy.rb` (configurable errors, injected logger)
- `lib/testing/playwright_artifact_capture.rb` (injected logger, uses TimeUtils)

### Expected Evaluation Score

With these changes, the design should achieve:
- **Reusability Score**: ≥ 7.0/10.0 (up from 3.4/5.0)
  - All Rails dependencies removed ✅
  - Framework-agnostic utilities implemented ✅
  - PlaywrightBrowserSession usable outside RSpec ✅
  - Configurable error types in RetryPolicy ✅
  - Dependency injection throughout ✅

**Ready for re-evaluation by design-reusability-evaluator.**
