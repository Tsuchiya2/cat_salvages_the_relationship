# frozen_string_literal: true

require_relative 'browser_driver'

module Testing
  # Playwright-specific implementation of BrowserDriver interface.
  #
  # Implements browser automation using playwright-ruby-client gem.
  # Supports chromium, firefox, and webkit browsers with full tracing
  # and screenshot capabilities.
  #
  # @example Basic usage
  #   driver = PlaywrightDriver.new
  #   config = PlaywrightConfiguration.for_environment
  #   browser = driver.launch_browser(config)
  #   context = driver.create_context(browser, config)
  #   page = context.new_page
  #   page.goto('https://example.com')
  #   driver.take_screenshot(page, '/tmp/screenshot.png')
  #   driver.close_browser(browser)
  #
  # @example With tracing
  #   driver = PlaywrightDriver.new
  #   browser = driver.launch_browser(config)
  #   context = driver.create_context(browser, config)
  #   driver.start_trace(context)
  #   # ... perform browser interactions
  #   driver.stop_trace(context, '/tmp/trace.zip')
  #
  # @since 1.0.0
  # @see BrowserDriver
  # @see PlaywrightConfiguration
  class PlaywrightDriver < BrowserDriver
    # @return [Playwright::Playwright] Playwright instance
    attr_reader :playwright

    # Initialize Playwright driver.
    #
    # Requires playwright-ruby-client gem to be installed.
    # Uses npx playwright as the executable path.
    #
    # @raise [LoadError] If playwright gem is not installed
    # @example
    #   driver = PlaywrightDriver.new
    def initialize
      require 'playwright'
      @playwright = Playwright.create(playwright_cli_executable_path: 'npx playwright')
    rescue LoadError => e
      raise LoadError,
            "Playwright gem not installed. Add to Gemfile:\n" \
            "  gem 'playwright-ruby-client', '~> 1.45'\n" \
            "Then run:\n" \
            "  bundle install\n" \
            "  npx playwright install chromium --with-deps\n" \
            "Original error: #{e.message}"
    end

    # Launch a browser instance with the given configuration.
    #
    # @param config [PlaywrightConfiguration] Browser configuration
    # @return [Playwright::Browser] Browser instance
    # @example
    #   browser = driver.launch_browser(config)
    def launch_browser(config)
      browser_type = playwright.public_send(config.browser_type)
      browser_type.launch(**config.browser_launch_options)
    end

    # Close a browser instance.
    #
    # @param browser [Playwright::Browser] Browser instance to close
    # @return [void]
    # @example
    #   driver.close_browser(browser)
    def close_browser(browser)
      browser&.close
    end

    # Create a new browser context (isolated session).
    #
    # Browser contexts provide session isolation with separate cookies,
    # storage, and cache. Useful for parallel test execution.
    #
    # @param browser [Playwright::Browser] Browser instance
    # @param config [PlaywrightConfiguration] Context configuration
    # @return [Playwright::BrowserContext] Browser context instance
    # @example
    #   context = driver.create_context(browser, config)
    def create_context(browser, config)
      browser.new_context(**config.browser_context_options)
    end

    # Take a screenshot of the current page.
    #
    # Captures full page screenshot (including scrollable content).
    #
    # @param page [Playwright::Page] Page instance
    # @param path [String, Pathname] Path where screenshot will be saved
    # @return [void]
    # @example
    #   driver.take_screenshot(page, '/tmp/screenshots/test-failure.png')
    def take_screenshot(page, path)
      page.screenshot(path: path.to_s, fullPage: true)
    end

    # Start tracing for debugging and test artifact capture.
    #
    # Tracing captures screenshots, snapshots, and source code during
    # browser interactions. Useful for debugging test failures.
    #
    # @param context [Playwright::BrowserContext] Browser context instance
    # @return [void]
    # @example
    #   driver.start_trace(context)
    def start_trace(context)
      context.tracing.start(
        screenshots: true,
        snapshots: true,
        sources: true
      )
    end

    # Stop tracing and save trace file.
    #
    # Trace file is saved in Playwright trace viewer format (.zip).
    # View with: npx playwright show-trace <path>
    #
    # @param context [Playwright::BrowserContext] Browser context instance
    # @param path [String, Pathname] Path where trace file will be saved
    # @return [void]
    # @example
    #   driver.stop_trace(context, '/tmp/traces/test-trace.zip')
    def stop_trace(context, path)
      context.tracing.stop(path: path.to_s)
    end
  end
end
