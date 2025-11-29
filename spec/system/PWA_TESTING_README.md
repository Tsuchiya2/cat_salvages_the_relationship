# PWA Offline Functionality Testing Guide

## Overview

This directory contains comprehensive system tests for PWA (Progressive Web App) offline functionality using Capybara and Selenium WebDriver.

## Test Files

### Main Test File
- **`pwa_offline_spec.rb`** - System tests for PWA offline functionality

### Helper Files
- **`spec/support/pwa_helpers.rb`** - Helper methods for PWA testing
- **`spec/support/capybara.rb`** - Capybara driver configuration with PWA support

## Test Coverage

### 1. Service Worker Registration
- ✅ Registers service worker when visiting home page
- ✅ Activates service worker successfully
- ✅ Caches offline page during installation

### 2. Offline Page Display (Optional)
- ⏭️ Displays offline page when navigating to uncached page while offline
- ⏭️ Shows offline page with proper styling and branding
- ⏭️ Allows retry when clicking retry button

**Note**: These tests are skipped by default because they require Chrome DevTools Protocol for offline simulation. Enable with `PWA_TEST_OFFLINE=true`.

### 3. Install Prompt Availability
- ⏭️ Sets up beforeinstallprompt event listener
- ⏭️ Can detect install prompt availability when event fires

**Note**: These tests are skipped because install prompts only fire under specific browser conditions.

### 4. Service Worker Updates
- ✅ Replaces old service worker with new version
- ✅ Handles service worker message events

### 5. Cache Management
- ✅ Creates static cache after service worker activation
- ✅ Caches root path during installation
- ✅ Retrieves cached URLs from static cache

### 6. Error Handling
- ✅ Handles service worker registration errors gracefully
- ✅ Handles cache errors without breaking the app

## Running Tests

### Run All PWA Tests

```bash
bundle exec rspec spec/system/pwa_offline_spec.rb
```

### Run Specific Test Groups

```bash
# Service Worker Registration tests only
bundle exec rspec spec/system/pwa_offline_spec.rb:28

# Cache Management tests only
bundle exec rspec spec/system/pwa_offline_spec.rb:258

# Error Handling tests only
bundle exec rspec spec/system/pwa_offline_spec.rb:323
```

### Run With Offline Tests Enabled

```bash
PWA_TEST_OFFLINE=true bundle exec rspec spec/system/pwa_offline_spec.rb
```

**Warning**: Offline tests require Chrome DevTools Protocol support and may be flaky in CI environments.

### Run With Detailed Output

```bash
bundle exec rspec spec/system/pwa_offline_spec.rb --format documentation
```

## Test Environment Setup

### Prerequisites

1. **Chrome Browser** - Required for Selenium WebDriver
2. **ChromeDriver** - Automatically managed by `webdrivers` gem
3. **Service Worker Support** - Modern Chrome/Chromium version

### Capybara Drivers

Two drivers are available:

1. **`:headless_chrome`** (default) - Standard headless Chrome for regular tests
2. **`:headless_chrome_pwa`** - Chrome with PWA/Service Worker support

PWA tests automatically use `:headless_chrome_pwa` driver.

### Configuration Files

- **`spec/support/capybara.rb`** - Driver registration and configuration
- **`spec/support/pwa_helpers.rb`** - PWA testing utilities
- **`spec/rails_helper.rb`** - RSpec configuration

## Helper Methods

### Service Worker Management

```ruby
# Check if service worker is supported
service_worker_supported?

# Manually trigger service worker registration
trigger_service_worker_registration

# Wait for service worker registration
wait_for_service_worker_registration(timeout: 5)

# Wait for service worker to be active
wait_for_service_worker_active(timeout: 10)

# Check if service worker is registered
service_worker_registered?

# Get service worker state
service_worker_state  # Returns: 'active', 'waiting', 'installing', or nil
```

### Cache Management

```ruby
# Clear all caches
clear_caches

# Get cached URLs from a specific cache
get_cached_urls('static-v1')

# Check if a URL is cached
url_cached?("#{Capybara.app_host}/offline.html")
```

### Offline Simulation (CDP)

```ruby
# Check if Chrome DevTools Protocol is available
can_use_cdp?

# Set browser to offline mode
set_offline_mode

# Restore browser to online mode
set_online_mode
```

### Install Prompt

```ruby
# Set up beforeinstallprompt event listener
setup_install_prompt_listener

# Check if install prompt is available
install_prompt_available?
```

### Cleanup

```ruby
# Unregister all service workers
unregister_service_workers
```

## Test Structure

Each test follows this structure:

```ruby
describe 'Feature' do
  it 'does something' do
    # 1. Visit page
    visit root_path

    # 2. Manually trigger registration if needed
    unless service_worker_registered?
      trigger_service_worker_registration
    end

    # 3. Wait for service worker to be active
    expect(wait_for_service_worker_active(timeout: 15)).to be true

    # 4. Perform test actions
    # ... test code ...

    # 5. Verify expectations
    expect(something).to be true
  end
end
```

## Troubleshooting

### Service Worker Not Registering

**Problem**: Tests fail with timeout waiting for service worker registration.

**Solutions**:
1. Check if `/serviceworker.js` is accessible
2. Verify JavaScript is enabled in test environment
3. Check browser console logs for errors
4. Ensure `application.js` imports and calls `initServiceWorker()`

### Tests Are Flaky

**Problem**: Tests pass sometimes but fail other times.

**Solutions**:
1. Increase timeout values in `wait_for_service_worker_active`
2. Add `sleep` statements after service worker activation
3. Ensure cleanup runs properly in `after` hooks
4. Check for race conditions in async JavaScript

### Offline Tests Don't Work

**Problem**: Offline tests fail even with `PWA_TEST_OFFLINE=true`.

**Solutions**:
1. Verify Chrome DevTools Protocol is supported: `can_use_cdp?`
2. Update Chrome/ChromeDriver to latest version
3. Check if `execute_cdp` method is available
4. Run tests with `--format documentation` to see detailed errors

### Cache Tests Fail

**Problem**: Cache-related tests fail to find cached URLs.

**Solutions**:
1. Increase wait time after service worker activation
2. Verify service worker is caching files correctly
3. Check cache names match expected pattern (e.g., `static-v1`)
4. Clear caches between test runs

## CI/CD Integration

### GitHub Actions Example

```yaml
- name: Run PWA Tests
  run: |
    bundle exec rspec spec/system/pwa_offline_spec.rb --format documentation
  env:
    PWA_TEST_OFFLINE: false  # Disable offline tests in CI (optional)
```

### Skip Flaky Tests in CI

```yaml
- name: Run PWA Tests (Basic)
  run: |
    bundle exec rspec spec/system/pwa_offline_spec.rb \
      --tag ~skip_in_ci \
      --format documentation
```

## Performance

- **Average test duration**: ~25 seconds for all tests
- **Service worker registration**: ~2-3 seconds
- **Cache verification**: ~1-2 seconds per test

## Future Enhancements

Potential improvements:

1. **Background Sync Testing** - Test background sync functionality
2. **Push Notifications** - Test push notification handling
3. **Update Scenarios** - Test service worker update flows
4. **Network Resilience** - Test various network conditions
5. **Performance Metrics** - Collect and verify PWA performance metrics

## References

- [Service Worker API](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API)
- [Progressive Web Apps](https://web.dev/progressive-web-apps/)
- [Capybara Documentation](https://github.com/teamcapybara/capybara)
- [Selenium WebDriver](https://www.selenium.dev/documentation/webdriver/)
- [Chrome DevTools Protocol](https://chromedevtools.github.io/devtools-protocol/)

## Support

For issues or questions about PWA testing:

1. Check this README for troubleshooting tips
2. Review test output with `--format documentation`
3. Check browser console logs in screenshots (saved to `tmp/capybara/`)
4. Verify service worker registration in Chrome DevTools

---

**Last Updated**: 2025-11-29
**Test Framework**: RSpec + Capybara + Selenium WebDriver
**Browser**: Chrome (Headless)
