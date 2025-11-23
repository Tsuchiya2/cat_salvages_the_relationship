# frozen_string_literal: true

module Testing
  # Abstract interface for browser automation drivers.
  #
  # This interface defines the contract that all browser drivers must implement,
  # enabling future driver swapping (e.g., Playwright, Selenium, Puppeteer).
  # All methods raise NotImplementedError and must be overridden by subclasses.
  #
  # @example Implementing a custom driver
  #   class CustomDriver < BrowserDriver
  #     def launch_browser(config)
  #       # Custom browser launch logic
  #     end
  #
  #     def close_browser(browser)
  #       # Custom browser close logic
  #     end
  #
  #     # ... implement other methods
  #   end
  #
  # @abstract Subclass and override all methods
  # @since 1.0.0
  # @see PlaywrightDriver
  class BrowserDriver
    # Launch a browser instance with the given configuration.
    #
    # @param config [PlaywrightConfiguration] Browser configuration
    # @return [Object] Browser instance
    # @raise [NotImplementedError] Must be implemented by subclass
    # @example
    #   driver = PlaywrightDriver.new
    #   browser = driver.launch_browser(config)
    def launch_browser(config)
      raise NotImplementedError, "#{self.class}#launch_browser must be implemented"
    end

    # Close a browser instance.
    #
    # @param browser [Object] Browser instance to close
    # @return [void]
    # @raise [NotImplementedError] Must be implemented by subclass
    # @example
    #   driver.close_browser(browser)
    def close_browser(browser)
      raise NotImplementedError, "#{self.class}#close_browser must be implemented"
    end

    # Create a new browser context (isolated session).
    #
    # Browser contexts provide session isolation with separate cookies,
    # storage, and cache. Useful for parallel test execution.
    #
    # @param browser [Object] Browser instance
    # @param config [PlaywrightConfiguration] Context configuration
    # @return [Object] Browser context instance
    # @raise [NotImplementedError] Must be implemented by subclass
    # @example
    #   context = driver.create_context(browser, config)
    def create_context(browser, config)
      raise NotImplementedError, "#{self.class}#create_context must be implemented"
    end

    # Take a screenshot of the current page.
    #
    # @param page [Object] Page instance
    # @param path [String, Pathname] Path where screenshot will be saved
    # @return [void]
    # @raise [NotImplementedError] Must be implemented by subclass
    # @example
    #   driver.take_screenshot(page, '/tmp/screenshots/test-failure.png')
    def take_screenshot(page, path)
      raise NotImplementedError, "#{self.class}#take_screenshot must be implemented"
    end

    # Start tracing for debugging and test artifact capture.
    #
    # Tracing captures screenshots, snapshots, and source code during
    # browser interactions. Useful for debugging test failures.
    #
    # @param context [Object] Browser context instance
    # @return [void]
    # @raise [NotImplementedError] Must be implemented by subclass
    # @example
    #   driver.start_trace(context)
    def start_trace(context)
      raise NotImplementedError, "#{self.class}#start_trace must be implemented"
    end

    # Stop tracing and save trace file.
    #
    # @param context [Object] Browser context instance
    # @param path [String, Pathname] Path where trace file will be saved
    # @return [void]
    # @raise [NotImplementedError] Must be implemented by subclass
    # @example
    #   driver.stop_trace(context, '/tmp/traces/test-trace.zip')
    def stop_trace(context, path)
      raise NotImplementedError, "#{self.class}#stop_trace must be implemented"
    end
  end
end
