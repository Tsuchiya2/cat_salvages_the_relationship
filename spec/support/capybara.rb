# Only load for system tests
return unless RSpec.configuration.files_to_run.any? { |f| f.include?('spec/system') }

Capybara.default_max_wait_time = 5
Capybara.server = :puma, { Silent: true }

RSpec.configure do |config|
  config.before(:each, type: :system) do
    # Use Selenium with headless Chrome for system tests
    driven_by :selenium, using: :headless_chrome, screen_size: [1920, 1080]
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
