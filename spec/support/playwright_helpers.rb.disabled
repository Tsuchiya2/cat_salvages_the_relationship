# RSpec helpers for Playwright integration
#
# Provides helper methods for common Playwright operations in system specs.
# Automatically captures screenshots on test failures.
module PlaywrightHelpers
  # Capture a screenshot with a custom name
  #
  # @param name [String] Name for the screenshot file
  # @return [String] Path to the saved screenshot
  def capture_screenshot(name)
    return unless @playwright_session

    sanitized_name = Testing::Utils::StringUtils.sanitize_filename(name)
    screenshot_path = Testing::Utils::PathUtils.screenshots_path.join("#{sanitized_name}.png")

    page = Capybara.current_session.driver.browser.current_page
    @playwright_session.driver.take_screenshot(page, screenshot_path)

    Rails.logger.info("Screenshot captured: #{screenshot_path}")
    screenshot_path.to_s
  end

  # Start trace recording
  #
  # @return [void]
  def start_trace
    return unless @playwright_session

    context = @playwright_session.context
    @playwright_session.driver.start_trace(context) if context
  end

  # Stop trace recording and save to file
  #
  # @param name [String] Name for the trace file
  # @return [String] Path to the saved trace file
  def stop_trace(name)
    return unless @playwright_session

    sanitized_name = Testing::Utils::StringUtils.sanitize_filename(name)
    trace_path = Testing::Utils::PathUtils.traces_path.join("#{sanitized_name}.zip")

    context = @playwright_session.context
    @playwright_session.driver.stop_trace(context, trace_path) if context

    Rails.logger.info("Trace saved: #{trace_path}")
    trace_path.to_s
  end

  # Wait for a selector to appear on the page
  #
  # @param selector [String] CSS selector to wait for
  # @param timeout [Integer] Timeout in milliseconds (default: 30000)
  # @return [void]
  def wait_for_selector(selector, timeout: 30_000)
    page = Capybara.current_session.driver.browser.current_page
    page.wait_for_selector(selector, timeout: timeout)
  end

  # Wait for URL to match a pattern
  #
  # @param url_pattern [String, Regexp] URL pattern to wait for
  # @param timeout [Integer] Timeout in milliseconds (default: 30000)
  # @return [void]
  def wait_for_url(url_pattern, timeout: 30_000)
    page = Capybara.current_session.driver.browser.current_page
    page.wait_for_url(url_pattern, timeout: timeout)
  end

  # Pause execution for debugging (opens Playwright Inspector)
  #
  # @return [void]
  def pause_for_debugging
    page = Capybara.current_session.driver.browser.current_page
    page.pause
  end

  # Inspect current page state (logs title, URL, and HTML)
  #
  # @return [Hash] Page state information
  def inspect_page_state
    page = Capybara.current_session.driver.browser.current_page

    state = {
      title: page.title,
      url: page.url,
      html_length: page.content.length
    }

    Rails.logger.info("Page state: #{state.inspect}")
    state
  end
end

RSpec.configure do |config|
  # Include PlaywrightHelpers in system specs
  config.include PlaywrightHelpers, type: :system

  # Automatically capture screenshot on test failure
  config.after(:each, type: :system) do |example|
    if example.exception && @playwright_session
      screenshot_name = "#{example.description}-#{Time.now.to_i}"
      capture_screenshot(screenshot_name)
    end
  end
end
