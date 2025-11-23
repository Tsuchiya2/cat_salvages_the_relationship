# frozen_string_literal: true

require_relative 'utils/null_logger'

module Testing
  # Framework-agnostic browser session manager with retry support.
  #
  # Manages Playwright browser and context lifecycle with automatic cleanup,
  # retry logic for transient failures, and artifact capture on failures.
  # Works with RSpec, Minitest, or standalone Ruby.
  #
  # @example Basic usage with RSpec
  #   session = PlaywrightBrowserSession.new(
  #     driver: PlaywrightDriver.new,
  #     config: PlaywrightConfiguration.for_environment,
  #     artifact_capture: PlaywrightArtifactCapture.new(...),
  #     retry_policy: RetryPolicy.new(...)
  #   )
  #
  #   session.start
  #   session.execute_with_retry(test_name: 'User login') do
  #     page = session.context.new_page
  #     page.goto('http://localhost:3000')
  #     # ... test code ...
  #   end
  #   session.stop
  #
  # @example With automatic cleanup
  #   session.start
  #   begin
  #     # ... tests ...
  #   ensure
  #     session.stop
  #   end
  #
  # @since 1.0.0
  class PlaywrightBrowserSession
    # @return [BrowserDriver] Browser driver instance
    attr_reader :driver

    # @return [PlaywrightConfiguration] Configuration instance
    attr_reader :config

    # @return [PlaywrightArtifactCapture] Artifact capture service
    attr_reader :artifact_capture

    # @return [RetryPolicy] Retry policy instance
    attr_reader :retry_policy

    # @return [Playwright::Browser, nil] Current browser instance
    attr_reader :browser

    # @return [Playwright::BrowserContext, nil] Current browser context
    attr_reader :context

    # @return [Logger] Logger instance
    attr_reader :logger

    # Initialize browser session manager.
    #
    # @param driver [BrowserDriver] Browser driver for automation
    # @param config [PlaywrightConfiguration] Configuration for browser/context
    # @param artifact_capture [PlaywrightArtifactCapture] Service for capturing artifacts
    # @param retry_policy [RetryPolicy] Policy for retrying transient failures
    # @param logger [Logger] Logger for structured output (default: NullLogger)
    def initialize(driver:, config:, artifact_capture:, retry_policy:, logger: Utils::NullLogger.new)
      raise ArgumentError, 'driver cannot be nil' if driver.nil?
      raise ArgumentError, 'config cannot be nil' if config.nil?

      @driver = driver
      @config = config
      @artifact_capture = artifact_capture
      @retry_policy = retry_policy
      @logger = logger
      @browser = nil
      @context = nil
    end

    # Start browser session.
    #
    # Launches browser with configuration and creates initial context.
    #
    # @return [Playwright::Browser] The launched browser instance
    # @raise [StandardError] If browser fails to launch
    def start
      ensure_browser_started
      create_context unless @context
      logger.info("Browser session started | browser=#{config.browser_type} | headless=#{config.headless}")
      @browser
    end

    # Stop browser session.
    #
    # Closes browser and cleans up all resources.
    #
    # @return [void]
    def stop
      cleanup
      logger.info('Browser session stopped')
    end

    # Restart browser session.
    #
    # Closes current browser and starts a new one.
    #
    # @return [Playwright::Browser] The new browser instance
    def restart
      logger.info('Restarting browser session')
      stop
      start
    end

    # Create new browser context.
    #
    # Creates isolated context with separate storage, cookies, and cache.
    # Closes existing context if present.
    #
    # @return [Playwright::BrowserContext] New browser context
    def create_context
      close_context if @context
      ensure_browser_started

      @context = driver.create_context(@browser, config)
      logger.info('Browser context created')

      @context
    end

    # Close current browser context.
    #
    # @return [void]
    def close_context
      return unless @context

      begin
        @context.close
      rescue StandardError => e
        logger.error("Failed to close context: #{e.message}")
      ensure
        @context = nil
      end
    end

    # Execute block with retry logic and artifact capture.
    #
    # Retries transient failures using retry policy. Captures screenshot
    # on final failure. Optionally captures trace based on config.
    #
    # @param test_name [String] Test name for artifact naming
    # @param metadata [Hash] Additional metadata for artifacts
    # @yield Block to execute with retry logic
    # @return [Object] Return value of block
    # @raise [StandardError] Re-raises error after max retries
    #
    # @example
    #   session.execute_with_retry(test_name: 'User login', metadata: { example_id: '...' }) do
    #     page = session.context.new_page
    #     page.goto('http://localhost:3000')
    #     page.fill('#email', 'user@example.com')
    #     page.click('text=Login')
    #   end
    def execute_with_retry(test_name:, metadata: {}, &block)
      ensure_browser_started
      create_context unless @context

      retry_policy.execute(&block)
    rescue StandardError => e
      # Capture screenshot on final failure
      capture_failure_artifacts(test_name, metadata, e)
      raise
    end

    private

    # Ensure browser is started.
    #
    # @return [void]
    # @raise [StandardError] If browser fails to launch
    def ensure_browser_started
      return if @browser

      @browser = driver.launch_browser(config)
    end

    # Clean up all resources.
    #
    # Closes context and browser, ensuring cleanup even if errors occur.
    #
    # @return [void]
    def cleanup
      close_context

      return unless @browser

      begin
        driver.close_browser(@browser)
      rescue StandardError => e
        logger.error("Failed to close browser: #{e.message}")
      ensure
        @browser = nil
      end
    end

    # Capture artifacts on test failure.
    #
    # @param test_name [String] Test name
    # @param metadata [Hash] Test metadata
    # @param error [Exception] Error that caused failure
    # @return [void]
    def capture_failure_artifacts(test_name, metadata, error)
      return unless @context

      enhanced_metadata = metadata.merge(
        error_class: error.class.name,
        error_message: error.message
      )

      # Capture screenshot from first page in context
      pages = @context.pages
      if pages.present?
        artifact_capture.capture_screenshot(
          pages.first,
          test_name: test_name,
          metadata: enhanced_metadata
        )
      end
    rescue StandardError => e
      logger.error("Failed to capture failure artifacts: #{e.message}")
    end
  end
end
