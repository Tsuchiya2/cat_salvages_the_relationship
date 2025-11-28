# Only load for system tests
return unless RSpec.configuration.files_to_run.any? { |f| f.include?('spec/system') }

require 'selenium-webdriver'

Capybara.default_max_wait_time = 5
Capybara.server = :puma, { Silent: true }

# Configure Chrome options for CI environment
Capybara.register_driver :headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless=new')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--disable-gpu')
  options.add_argument('--window-size=1920,1080')
  options.add_argument('--disable-blink-features=AutomationControlled')

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

RSpec.configure do |config|
  config.before(:each, type: :system) do
    # Use custom headless Chrome driver
    driven_by :headless_chrome
  end

  config.after(:each, type: :system) do
    # Accept any open alerts before resetting (only for Selenium driver)
    if page.driver.is_a?(Capybara::Selenium::Driver)
      begin
        page.driver.browser.switch_to.alert.accept
      rescue Selenium::WebDriver::Error::NoSuchAlertError
        # No alert present, continue
      end
    end
    # Clear sessions and reset driver after each test
    Capybara.reset_sessions!
    Capybara.use_default_driver
    # Wait a moment to ensure cleanup completes
    sleep 0.1
  end
end
