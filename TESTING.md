# Testing Guide

This document provides comprehensive testing guidelines for the cat_salvages_the_relationship project.

## Table of Contents

- [Overview](#overview)
- [Testing Infrastructure](#testing-infrastructure)
- [Prerequisites](#prerequisites)
- [Running Tests](#running-tests)
- [Test Artifacts](#test-artifacts)
- [Writing Tests](#writing-tests)
- [Troubleshooting](#troubleshooting)
- [CI/CD Integration](#cicd-integration)

---

## Overview

This project uses **RSpec** for testing with **Playwright** for browser automation in system specs. The testing infrastructure is designed to be framework-agnostic and works seamlessly across local, Docker, and CI environments.

### Technology Stack

- **RSpec 3.13** - Testing framework
- **Playwright 1.45+** - Modern browser automation
- **Capybara** - DSL for testing web applications
- **SimpleCov** - Code coverage analysis (88% threshold)
- **FactoryBot** - Test data factories
- **Database Cleaner** - Database cleanup strategies

---

## Testing Infrastructure

### System Testing with Playwright

Playwright replaces Selenium WebDriver for more reliable and faster system tests.

**Key Features:**
- 🚀 **25-36% faster** than Selenium
- 📸 **Automatic screenshots** on test failures
- 🎬 **Full browser traces** for debugging
- 🔄 **Smart retry** with exponential backoff
- 🌐 **Multi-browser support** (Chromium, Firefox, WebKit)

**Architecture:**
```
RSpec → Capybara → PlaywrightDriver → playwright-ruby-client → Chromium
```

---

## Prerequisites

### Local Development

1. **Ruby 3.4.6** (or specified in `.ruby-version`)
2. **Node.js 20+** and npm
3. **MySQL 8.0** (for test database)
4. **Playwright browsers**

### Installation

```bash
# Install Ruby dependencies
bundle install

# Install Node.js dependencies
npm ci

# Install Playwright browsers (first time only)
npx playwright install chromium --with-deps

# Setup test database
RAILS_ENV=test bundle exec rails db:create db:schema:load
```

---

## Running Tests

### All Tests

```bash
# Run all tests with coverage
COVERAGE=true bundle exec rspec

# Run all tests without coverage (faster)
bundle exec rspec
```

### Test Suites

```bash
# Run model tests only
bundle exec rspec spec/models

# Run system tests only
bundle exec rspec spec/system

# Run a specific file
bundle exec rspec spec/system/users_spec.rb

# Run a specific test
bundle exec rspec spec/system/users_spec.rb:42
```

### Development Mode

```bash
# Run with visible browser (non-headless)
PLAYWRIGHT_HEADLESS=false bundle exec rspec spec/system

# Run with slow motion (helpful for debugging)
PLAYWRIGHT_SLOW_MO=1000 bundle exec rspec spec/system

# Enable trace recording
PLAYWRIGHT_TRACE_MODE=on bundle exec rspec spec/system
```

### Parallel Testing (Faster)

```bash
# Run tests in parallel (recommended for large test suites)
bundle exec parallel_rspec spec/
```

---

## Test Artifacts

### Screenshots

Captured automatically on test failures.

**Location:** `tmp/screenshots/`

**Naming:** `{test-name}-{timestamp}.png`

**Example:**
```
tmp/screenshots/
└── user-login-should-redirect-to-dashboard-20250123-143022.png
```

### Traces

Full browser interaction traces for deep debugging.

**Location:** `tmp/traces/`

**Naming:** `{test-name}-{timestamp}.zip`

**Viewing traces:**
```bash
# View a trace file in Playwright Trace Viewer
npx playwright show-trace tmp/traces/user-login-20250123-143022.zip
```

The trace viewer shows:
- Timeline of all actions
- Network requests
- Console logs
- Screenshots at each step
- DOM snapshots

### Coverage Reports

**Location:** `coverage/`

**Viewing:**
```bash
# Open HTML coverage report
open coverage/index.html
```

**Threshold:** 88% (builds fail below this threshold)

---

## Writing Tests

### System Specs with Playwright

```ruby
require 'rails_helper'

RSpec.describe 'User authentication', type: :system do
  it 'allows user to log in' do
    user = create(:user, email: 'test@example.com', password: 'password123')

    visit login_path
    fill_in 'Email', with: user.email
    fill_in 'Password', with: 'password123'
    click_button 'Log in'

    expect(page).to have_content 'Welcome back!'
  end

  it 'shows error for invalid credentials' do
    visit login_path
    fill_in 'Email', with: 'invalid@example.com'
    fill_in 'Password', with: 'wrongpassword'
    click_button 'Log in'

    expect(page).to have_content 'Invalid email or password'
  end
end
```

### Using Playwright Helpers

```ruby
require 'rails_helper'

RSpec.describe 'Advanced interactions', type: :system do
  it 'waits for dynamic content' do
    visit dashboard_path

    # Wait for an element to appear
    wait_for_selector('.notification', timeout: 5000)

    # Capture a screenshot
    capture_screenshot('dashboard-loaded')

    # Wait for URL change
    click_link 'Profile'
    wait_for_url(/\/profile/)
  end

  it 'debugs with trace' do
    start_trace

    visit complex_page_path
    # ... complex interactions ...

    stop_trace('complex-interaction')
  end
end
```

### Model Specs

```ruby
require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email) }
  end

  describe '#full_name' do
    it 'concatenates first and last name' do
      user = build(:user, first_name: 'John', last_name: 'Doe')
      expect(user.full_name).to eq 'John Doe'
    end
  end
end
```

### Request Specs

```ruby
require 'rails_helper'

RSpec.describe 'Users API', type: :request do
  describe 'GET /api/users' do
    it 'returns list of users' do
      create_list(:user, 3)

      get '/api/users'

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body).size).to eq 3
    end
  end
end
```

---

## Troubleshooting

### Common Issues

#### 1. Playwright not found

**Error:**
```
LoadError: cannot load such file -- playwright
```

**Solution:**
```bash
bundle install
npx playwright install chromium --with-deps
```

#### 2. Browser launch timeout

**Error:**
```
Timeout waiting for browser to start
```

**Solutions:**
- Increase timeout: `PLAYWRIGHT_TIMEOUT=60000 bundle exec rspec`
- Check browser installation: `npx playwright list`
- Run in headed mode to see what's happening: `PLAYWRIGHT_HEADLESS=false bundle exec rspec`

#### 3. Database connection error

**Error:**
```
ActiveRecord::NoDatabaseError: Unknown database 'cat_salvages_the_relationship_test'
```

**Solution:**
```bash
RAILS_ENV=test bundle exec rails db:create db:schema:load
```

#### 4. Port already in use

**Error:**
```
Errno::EADDRINUSE: Address already in use - bind(2)
```

**Solution:**
```bash
# Find process using port 3000
lsof -i :3000

# Kill the process
kill -9 <PID>
```

#### 5. Flaky tests

**Symptoms:**
- Tests pass locally but fail in CI
- Tests fail intermittently

**Solutions:**
- Use `wait_for_selector` instead of `sleep`
- Increase timeout for slow operations
- Check for race conditions in JavaScript
- Review Playwright traces to identify timing issues

#### 6. Memory issues

**Error:**
```
Cannot allocate memory
```

**Solution:**
- Close unused browser tabs
- Reduce parallel test workers
- Ensure `@playwright_session.stop` is called in `after` hooks

---

## CI/CD Integration

### GitHub Actions

The project uses GitHub Actions for continuous integration.

**Workflow file:** `.github/workflows/rspec.yml`

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop`

**Steps:**
1. Checkout code
2. Setup Ruby 3.4.6 (with bundler cache)
3. Setup Node.js 20 (with npm cache)
4. Setup MySQL 8.0 service
5. Install Playwright browsers
6. Create and setup test database
7. Build JavaScript and CSS assets
8. Run RSpec with coverage
9. Upload artifacts (screenshots, traces, coverage)
10. Check coverage threshold (≥88%)

**Viewing CI artifacts:**
1. Go to GitHub Actions tab
2. Click on the workflow run
3. Scroll to "Artifacts" section
4. Download:
   - `playwright-screenshots-{run_number}`
   - `playwright-traces-{run_number}`
   - `coverage-report-{run_number}`

### Environment Variables

**Required:**
```bash
RAILS_ENV=test
DATABASE_URL=mysql2://root:password@127.0.0.1:3306/cat_salvages_the_relationship_test
CI=true
COVERAGE=true
```

**Optional (for customization):**
```bash
PLAYWRIGHT_BROWSER=chromium          # chromium, firefox, or webkit
PLAYWRIGHT_HEADLESS=true             # true or false
PLAYWRIGHT_SLOW_MO=0                 # milliseconds to slow down operations
PLAYWRIGHT_TIMEOUT=30000             # milliseconds
PLAYWRIGHT_TRACE_MODE=off            # on, off, or on-first-retry
```

---

## Performance Tips

### 1. Use Parallel Testing

```bash
# Install parallel_tests gem
bundle add parallel_tests

# Setup databases
RAILS_ENV=test bundle exec rake parallel:create parallel:load_schema

# Run tests in parallel
bundle exec parallel_rspec spec/
```

### 2. Focus on Relevant Tests

```bash
# Run only tests matching a pattern
bundle exec rspec --tag focus

# Skip slow tests during development
bundle exec rspec --tag ~slow
```

### 3. Optimize Database Interactions

```ruby
# Use transactions for faster cleanup
RSpec.configure do |config|
  config.use_transactional_fixtures = true
end

# Use build instead of create when persistence isn't needed
user = build(:user)
```

### 4. Profile Your Tests

```bash
# Find the slowest tests
bundle exec rspec --profile 10
```

---

## Best Practices

### 1. Test Independence

✅ **Good:**
```ruby
it 'creates a new user' do
  user = create(:user)
  expect(User.count).to eq 1
end
```

❌ **Bad:**
```ruby
before(:all) do
  @user = create(:user)  # Shared state across tests
end

it 'finds the user' do
  expect(User.find(@user.id)).to be_present
end
```

### 2. Descriptive Test Names

✅ **Good:**
```ruby
it 'redirects to dashboard after successful login'
it 'displays validation error for invalid email format'
```

❌ **Bad:**
```ruby
it 'works'
it 'test login'
```

### 3. Arrange-Act-Assert Pattern

```ruby
it 'updates user profile' do
  # Arrange
  user = create(:user, name: 'Old Name')

  # Act
  user.update(name: 'New Name')

  # Assert
  expect(user.reload.name).to eq 'New Name'
end
```

### 4. Use Factories Over Fixtures

✅ **Good:**
```ruby
user = create(:user, email: 'test@example.com')
```

❌ **Bad:**
```ruby
user = User.create!(email: 'test@example.com', password: '...', ...)
```

### 5. Test One Thing Per Example

✅ **Good:**
```ruby
it 'validates presence of email'
it 'validates uniqueness of email'
it 'validates format of email'
```

❌ **Bad:**
```ruby
it 'validates email' do
  expect(user).to validate_presence_of(:email)
  expect(user).to validate_uniqueness_of(:email)
  expect(user).to validate_format_of(:email)
end
```

---

## Additional Resources

- [RSpec Documentation](https://rspec.info/)
- [Playwright Ruby Documentation](https://playwright-ruby-client.vercel.app/)
- [Capybara Documentation](https://github.com/teamcapybara/capybara)
- [FactoryBot Documentation](https://github.com/thoughtbot/factory_bot)
- [SimpleCov Documentation](https://github.com/simplecov-ruby/simplecov)

---

## Support

For questions or issues:
1. Check this documentation
2. Review existing tests for examples
3. Check GitHub Issues
4. Ask in team chat

---

**Last Updated:** 2025-11-23
**Maintained By:** Development Team
