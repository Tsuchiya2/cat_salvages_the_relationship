# PWA Testing Helpers
# Provides utilities for testing PWA functionality including service workers and offline behavior

module PwaHelpers
  # Wait for service worker registration with timeout
  # @param timeout [Integer] Maximum wait time in seconds (default: 5)
  # @return [Boolean] true if registration successful
  def wait_for_service_worker_registration(timeout: 5)
    start_time = Time.zone.now
    loop do
      break if Time.zone.now - start_time > timeout

      registered = page.evaluate_script(<<~JAVASCRIPT)
        (async () => {
          if (!navigator.serviceWorker) return false;
          const registration = await navigator.serviceWorker.getRegistration();
          return !!registration;
        })();
      JAVASCRIPT

      return true if registered

      sleep 0.3
    end
    false
  rescue StandardError => e
    Rails.logger.warn "[PWA Test] Error waiting for service worker: #{e.message}"
    false
  end

  # Wait for service worker to be active
  # @param timeout [Integer] Maximum wait time in seconds (default: 10)
  # @return [Boolean] true if service worker is active
  def wait_for_service_worker_active(timeout: 10)
    start_time = Time.zone.now
    loop do
      break if Time.zone.now - start_time > timeout

      active = page.evaluate_script(<<~JAVASCRIPT)
        (async () => {
          if (!navigator.serviceWorker) return false;
          const registration = await navigator.serviceWorker.getRegistration();
          return registration && registration.active;
        })();
      JAVASCRIPT

      return true if active

      sleep 0.5
    end
    false
  rescue StandardError => e
    Rails.logger.warn "[PWA Test] Error waiting for service worker active: #{e.message}"
    false
  end

  # Check if service worker is registered
  # @return [Boolean] true if service worker is registered
  def service_worker_registered?
    page.evaluate_script(<<~JAVASCRIPT)
      (async () => {
        if (!navigator.serviceWorker) return false;
        const registration = await navigator.serviceWorker.getRegistration();
        return !!registration;
      })();
    JAVASCRIPT
  end

  # Get service worker state
  # @return [String, nil] Service worker state (installing, waiting, active) or nil
  def service_worker_state
    page.evaluate_script(<<~JAVASCRIPT)
      (async () => {
        if (!navigator.serviceWorker) return null;
        const registration = await navigator.serviceWorker.getRegistration();
        if (!registration) return null;
        if (registration.active) return 'active';
        if (registration.waiting) return 'waiting';
        if (registration.installing) return 'installing';
        return null;
      })();
    JAVASCRIPT
  end

  # Simulate offline network condition using Chrome DevTools Protocol
  # @return [Boolean] true if successfully set to offline
  def set_offline_mode
    return false unless can_use_cdp?

    begin
      page.driver.browser.execute_cdp(
        'Network.enable'
      )

      page.driver.browser.execute_cdp(
        'Network.emulateNetworkConditions',
        offline: true,
        downloadThroughput: 0,
        uploadThroughput: 0,
        latency: 0
      )

      # Wait a moment for the offline state to take effect
      sleep 0.3
      true
    rescue StandardError => e
      Rails.logger.warn "[PWA Test] Failed to set offline mode: #{e.message}"
      false
    end
  end

  # Restore online network condition
  # @return [Boolean] true if successfully restored to online
  def set_online_mode
    return false unless can_use_cdp?

    begin
      page.driver.browser.execute_cdp(
        'Network.emulateNetworkConditions',
        offline: false,
        downloadThroughput: -1,
        uploadThroughput: -1,
        latency: 0
      )

      page.driver.browser.execute_cdp(
        'Network.disable'
      )

      # Wait a moment for the online state to take effect
      sleep 0.3
      true
    rescue StandardError => e
      Rails.logger.warn "[PWA Test] Failed to set online mode: #{e.message}"
      false
    end
  end

  # Check if browser supports service workers
  # @return [Boolean] true if service worker is supported
  def service_worker_supported?
    page.evaluate_script('!!navigator.serviceWorker')
  end

  # Manually trigger service worker registration
  # Useful for testing when automatic registration doesn't happen
  # @return [Boolean] true if registration started successfully
  def trigger_service_worker_registration
    page.evaluate_script(<<~JAVASCRIPT)
      (async () => {
        try {
          if (!navigator.serviceWorker) return false;
          const registration = await navigator.serviceWorker.register('/serviceworker.js', {
            scope: '/'
          });
          console.log('[PWA Test] Service worker registered manually:', registration.scope);
          return true;
        } catch (error) {
          console.error('[PWA Test] Manual registration failed:', error);
          return false;
        }
      })();
    JAVASCRIPT
  end

  # Check if browser supports Chrome DevTools Protocol
  # @return [Boolean] true if CDP is available
  def can_use_cdp?
    return false unless page.driver.is_a?(Capybara::Selenium::Driver)
    return false unless page.driver.browser.respond_to?(:execute_cdp)

    true
  rescue StandardError
    false
  end

  # Unregister all service workers (cleanup)
  # @return [Boolean] true if successfully unregistered
  def unregister_service_workers
    page.evaluate_script(<<~JAVASCRIPT)
      (async () => {
        if (!navigator.serviceWorker) return false;
        const registrations = await navigator.serviceWorker.getRegistrations();
        await Promise.all(registrations.map(reg => reg.unregister()));
        return true;
      })();
    JAVASCRIPT
  end

  # Clear all caches (cleanup)
  # @return [Boolean] true if successfully cleared
  def clear_caches
    page.evaluate_script(<<~JAVASCRIPT)
      (async () => {
        if (!caches) return false;
        const cacheNames = await caches.keys();
        await Promise.all(cacheNames.map(name => caches.delete(name)));
        return true;
      })();
    JAVASCRIPT
  end

  # Get cached URLs from a specific cache
  # @param cache_name [String] Name of the cache
  # @return [Array<String>] Array of cached URLs
  def get_cached_urls(cache_name)
    page.evaluate_script(<<~JAVASCRIPT)
      (async () => {
        if (!caches) return [];
        const cache = await caches.open('#{cache_name}');
        const requests = await cache.keys();
        return requests.map(req => req.url);
      })();
    JAVASCRIPT
  end

  # Check if a URL is cached
  # @param url [String] URL to check
  # @return [Boolean] true if URL is cached
  def url_cached?(url)
    page.evaluate_script(<<~JAVASCRIPT)
      (async () => {
        if (!caches) return false;
        const response = await caches.match('#{url}');
        return !!response;
      })();
    JAVASCRIPT
  end

  # Get beforeinstallprompt event status
  # @return [Boolean] true if event was fired
  def install_prompt_available?
    page.evaluate_script(<<~JAVASCRIPT)
      window.installPromptAvailable === true
    JAVASCRIPT
  end

  # Set up beforeinstallprompt event listener
  # @return [Boolean] true if listener was set up
  def setup_install_prompt_listener
    page.evaluate_script(<<~JAVASCRIPT)
      window.installPromptAvailable = false;
      window.addEventListener('beforeinstallprompt', (e) => {
        e.preventDefault();
        window.installPromptAvailable = true;
        window.installPromptEvent = e;
      });
      true;
    JAVASCRIPT
  end
end

# Include in RSpec configuration
RSpec.configure do |config|
  config.include PwaHelpers, type: :system
end
