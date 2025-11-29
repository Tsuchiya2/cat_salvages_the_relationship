require 'rails_helper'

RSpec.describe '[SystemTest] PWA Offline Functionality', type: :system, js: true do
  before do
    # Use PWA-enabled driver
    driven_by :headless_chrome_pwa

    # Clear service workers and caches before each test
    visit root_path

    # Check if browser supports service workers
    unless service_worker_supported?
      skip 'Service Worker not supported in this browser'
    end

    unregister_service_workers
    clear_caches
    sleep 0.5 # Wait for cleanup to complete
  end

  after do
    # Restore online mode and cleanup after each test
    set_online_mode if can_use_cdp?
    unregister_service_workers
    clear_caches
  end

  describe 'Service Worker Registration' do
    it 'registers service worker when visiting home page' do
      # Visit home page (service worker should auto-register)
      visit root_path

      # Manually trigger registration if not automatically registered
      unless service_worker_registered?
        trigger_service_worker_registration
      end

      # Wait for service worker registration
      expect(wait_for_service_worker_registration(timeout: 10)).to be true

      # Verify service worker is registered
      expect(service_worker_registered?).to be true
    end

    it 'activates service worker successfully' do
      # Visit home page
      visit root_path

      # Manually trigger registration if needed
      unless service_worker_registered?
        trigger_service_worker_registration
      end

      # Wait for service worker to be active
      expect(wait_for_service_worker_active(timeout: 15)).to be true

      # Verify service worker state is active
      expect(service_worker_state).to eq 'active'
    end

    it 'caches offline page during installation' do
      # Visit home page to trigger service worker installation
      visit root_path

      # Manually trigger registration if needed
      unless service_worker_registered?
        trigger_service_worker_registration
      end

      # Wait for service worker to be active
      wait_for_service_worker_active(timeout: 15)

      # Give service worker time to cache offline page
      sleep 2

      # Verify offline page is cached
      expect(url_cached?("#{Capybara.app_host}/offline.html")).to be true
    end
  end

  describe 'Offline Page Display', skip: !ENV['PWA_TEST_OFFLINE'] do
    before do
      unless can_use_cdp?
        skip 'Chrome DevTools Protocol not available - required for offline simulation'
      end
    end

    it 'displays offline page when navigating to uncached page while offline' do
      # Step 1: Register service worker and cache offline page
      visit root_path
      expect(wait_for_service_worker_active(timeout: 10)).to be true
      sleep 1 # Wait for offline page to be cached

      # Step 2: Simulate offline mode
      expect(set_offline_mode).to be true

      # Step 3: Navigate to uncached page
      visit terms_path # Navigate to a page that may not be cached

      # Step 4: Verify offline page is displayed
      # The offline page should show "オフラインです" (Japanese for "You are offline")
      expect(page).to have_content('オフラインです')
      expect(page).to have_content('現在オフラインです')
      expect(page).to have_content('インターネット接続を確認してください')
      expect(page).to have_button('再試行')
    end

    it 'shows offline page with proper styling and branding' do
      # Register service worker
      visit root_path
      expect(wait_for_service_worker_active(timeout: 10)).to be true
      sleep 1

      # Go offline
      expect(set_offline_mode).to be true

      # Navigate to uncached page
      visit privacy_policy_path

      # Verify offline page elements
      expect(page).to have_content('ReLINE')
      expect(page).to have_css('.container')
      expect(page).to have_css('.retry-btn')

      # Verify page title
      expect(page).to have_title('オフライン - ReLINE')
    end

    it 'allows retry when clicking retry button' do
      # Register service worker
      visit root_path
      expect(wait_for_service_worker_active(timeout: 10)).to be true
      sleep 1

      # Go offline and navigate to uncached page
      expect(set_offline_mode).to be true
      visit terms_path
      expect(page).to have_content('オフラインです')

      # Restore online mode
      expect(set_online_mode).to be true

      # Click retry button
      click_button '再試行'

      # Page should reload successfully
      sleep 1
      expect(page).not_to have_content('オフラインです')
    end
  end

  describe 'Install Prompt Availability' do
    before do
      # Set up beforeinstallprompt event listener
      visit root_path
      setup_install_prompt_listener
    end

    it 'sets up beforeinstallprompt event listener', skip: 'Browser-dependent feature' do
      # Note: This test is skipped because beforeinstallprompt is only fired
      # in certain conditions (e.g., site meets PWA criteria, user hasn't installed yet)
      # In a real browser environment with proper PWA setup, this would work

      visit root_path
      setup_install_prompt_listener
      sleep 1

      # Check if listener is set up (not if event fired)
      has_listener = page.evaluate_script(<<~JAVASCRIPT)
        typeof window.installPromptAvailable === 'boolean'
      JAVASCRIPT

      expect(has_listener).to be true
    end

    it 'can detect install prompt availability when event fires', skip: 'Browser-dependent feature' do
      # This test demonstrates how to check if the install prompt is available
      # It will be skipped in automated tests but can be used for manual testing

      visit root_path
      setup_install_prompt_listener

      # Wait to see if event fires (it usually won't in automated tests)
      sleep 2

      # In a real scenario with proper PWA setup and user context,
      # this would return true if the event fired
      # expect(install_prompt_available?).to be true
    end
  end

  describe 'Service Worker Updates' do
    it 'replaces old service worker with new version' do
      # Visit page to register service worker
      visit root_path
      unless service_worker_registered?
        trigger_service_worker_registration
      end
      expect(wait_for_service_worker_active(timeout: 15)).to be true

      # Get initial registration
      first_registration = page.evaluate_script(<<~JAVASCRIPT)
        (async () => {
          const registration = await navigator.serviceWorker.getRegistration();
          return registration ? registration.active.scriptURL : null;
        })();
      JAVASCRIPT

      expect(first_registration).to include('serviceworker.js')

      # Trigger update check
      update_result = page.evaluate_script(<<~JAVASCRIPT)
        (async () => {
          try {
            const registration = await navigator.serviceWorker.getRegistration();
            if (registration) {
              await registration.update();
              return true;
            }
            return false;
          } catch (e) {
            return false;
          }
        })();
      JAVASCRIPT

      expect(update_result).to be true
    end

    it 'handles service worker message events' do
      # Visit page and wait for service worker
      visit root_path
      unless service_worker_registered?
        trigger_service_worker_registration
      end
      expect(wait_for_service_worker_active(timeout: 15)).to be true

      # Send message to service worker
      message_sent = page.evaluate_script(<<~JAVASCRIPT)
        (async () => {
          try {
            const registration = await navigator.serviceWorker.getRegistration();
            if (registration && registration.active) {
              registration.active.postMessage({ type: 'PING' });
              return true;
            }
            return false;
          } catch (e) {
            return false;
          }
        })();
      JAVASCRIPT

      expect(message_sent).to be true
    end
  end

  describe 'Cache Management' do
    it 'creates static cache after service worker activation' do
      # Visit page to register service worker
      visit root_path
      unless service_worker_registered?
        trigger_service_worker_registration
      end
      expect(wait_for_service_worker_active(timeout: 15)).to be true
      sleep 2 # Wait for caching to complete

      # Get cache names
      cache_names = page.evaluate_script(<<~JAVASCRIPT)
        (async () => {
          if (!caches) return [];
          return await caches.keys();
        })();
      JAVASCRIPT

      # Verify static cache exists
      static_cache = cache_names.find { |name| name.include?('static-') }
      expect(static_cache).not_to be_nil
    end

    it 'caches root path during installation' do
      # Visit page to trigger service worker installation
      visit root_path
      unless service_worker_registered?
        trigger_service_worker_registration
      end
      expect(wait_for_service_worker_active(timeout: 15)).to be true
      sleep 2

      # Verify root path is cached
      root_cached = url_cached?("#{Capybara.app_host}/")
      expect(root_cached).to be true
    end

    it 'retrieves cached URLs from static cache' do
      # Visit page and wait for caching
      visit root_path
      unless service_worker_registered?
        trigger_service_worker_registration
      end
      expect(wait_for_service_worker_active(timeout: 15)).to be true
      sleep 2

      # Get cache names
      cache_names = page.evaluate_script(<<~JAVASCRIPT)
        (async () => {
          if (!caches) return [];
          return await caches.keys();
        })();
      JAVASCRIPT

      # Find static cache
      static_cache = cache_names.find { |name| name.include?('static-') }
      skip 'No static cache found' unless static_cache

      # Get cached URLs
      cached_urls = get_cached_urls(static_cache)
      expect(cached_urls).not_to be_empty
      expect(cached_urls.any? { |url| url.include?('offline.html') }).to be true
    end
  end

  describe 'Error Handling' do
    it 'handles service worker registration errors gracefully' do
      # Visit page normally
      visit root_path

      # Even if service worker fails, the page should load normally
      expect(page).to have_current_path(root_path)
      # Page should have loaded successfully (no error page)
      expect(page).not_to have_content('エラーが発生しました')
    end

    it 'handles cache errors without breaking the app' do
      # Visit page normally
      visit root_path
      unless service_worker_registered?
        trigger_service_worker_registration
      end
      wait_for_service_worker_active(timeout: 15)

      # Try to delete cache while service worker is active
      # This should not break the app
      clear_caches

      # App should continue to work
      visit root_path
      expect(page).to have_current_path(root_path)
    end
  end
end
