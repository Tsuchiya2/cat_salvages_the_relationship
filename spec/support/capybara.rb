RSpec.configure do |config|
  config.before(:each, type: :system) do
    # CI環境ではより安定した設定を使用
    if ENV['CI']
      driven_by :selenium, using: :headless_chrome, screen_size: [1920, 1080] do |driver_options|
        driver_options.add_argument('--disable-dev-shm-usage')
        driver_options.add_argument('--no-sandbox')
        driver_options.add_argument('--disable-gpu')
        driver_options.add_argument('--disable-software-rasterizer')
        driver_options.add_argument('--disable-extensions')
      end
    else
      driven_by :selenium, using: :headless_chrome, screen_size: [1920, 1080]
    end
  end
end
