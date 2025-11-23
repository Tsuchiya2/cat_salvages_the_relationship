# Only load for system tests
return unless RSpec.configuration.files_to_run.any? { |f| f.include?('spec/system') }

RSpec.configure do |config|
  config.before(:each, type: :system) do
    # Use Selenium with headless Chrome for system tests
    driven_by :selenium, using: :headless_chrome, screen_size: [1920, 1080]
  end
end
