require 'testing/playwright_configuration'
require 'testing/playwright_driver'
require 'testing/file_system_storage'
require 'testing/playwright_artifact_capture'
require 'testing/retry_policy'
require 'testing/playwright_browser_session'

RSpec.configure do |config|
  config.before(:each, type: :system) do
    # Initialize Playwright configuration for the current environment
    playwright_config = Testing::PlaywrightConfiguration.for_environment

    # Initialize Playwright driver
    playwright_driver = Testing::PlaywrightDriver.new

    # Initialize artifact storage
    storage = Testing::FileSystemStorage.new

    # Initialize artifact capture
    artifact_capture = Testing::PlaywrightArtifactCapture.new(
      driver: playwright_driver,
      storage: storage,
      logger: Rails.logger
    )

    # Initialize retry policy
    retry_policy = Testing::RetryPolicy.new(
      max_attempts: Testing::RetryPolicy::DEFAULT_MAX_ATTEMPTS,
      backoff_multiplier: Testing::RetryPolicy::DEFAULT_BACKOFF_MULTIPLIER,
      initial_delay: Testing::RetryPolicy::DEFAULT_INITIAL_DELAY,
      logger: Rails.logger,
      retryable_errors: [
        Net::ReadTimeout,
        Errno::ECONNREFUSED,
        Selenium::WebDriver::Error::WebDriverError
      ],
      non_retryable_errors: [
        RSpec::Expectations::ExpectationNotMetError
      ]
    )

    # Initialize browser session
    @playwright_session = Testing::PlaywrightBrowserSession.new(
      driver: playwright_driver,
      config: playwright_config,
      artifact_capture: artifact_capture,
      retry_policy: retry_policy
    )

    # Register Playwright driver with Capybara
    Capybara.register_driver :playwright do |app|
      # Start Playwright browser session
      @playwright_session.start

      # Create Capybara driver using Playwright
      Capybara::Playwright::Driver.new(app, browser: @playwright_session.browser)
    rescue LoadError
      # Fallback: Use capybara-playwright adapter if available
      # This requires installing capybara-playwright gem
      warn 'Warning: Direct Playwright integration not available. Using fallback.'
      driven_by :selenium, using: :headless_chrome, screen_size: [1920, 1080]
    end

    # Use Playwright driver for system specs
    begin
      driven_by :playwright, screen_size: [1920, 1080] do |driver_options|
        driver_options.add_argument('--window-size=1920,1080')
      end
    rescue StandardError
      driven_by :selenium, using: :headless_chrome, screen_size: [1920, 1080]
    end
  end

  # Clean up browser session after each test
  config.after(:each, type: :system) do
    @playwright_session&.stop
  end
end
