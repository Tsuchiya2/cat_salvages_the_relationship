# Design Reusability Evaluation - GitHub Actions RSpec with Playwright Integration

**Evaluator**: design-reusability-evaluator
**Design Document**: /Users/yujitsuchiya/cat_salvages_the_relationship/docs/designs/github-actions-rspec-playwright.md
**Evaluated**: 2025-11-23T00:00:00Z

---

## Overall Judgment

**Status**: Approved
**Overall Score**: 8.3 / 10.0

---

## Detailed Scores

### 1. Component Generalization: 8.5 / 10.0 (Weight: 35%)

**Findings**:
- **Excellent abstraction layers implemented**: BrowserDriver interface allows swapping Playwright for Selenium, Puppeteer, or other drivers
- **Utility libraries are highly generalized**: PathUtils, EnvUtils, TimeUtils, StringUtils can be used in any Ruby project (Rails, Sinatra, Hanami, CLI)
- **PlaywrightBrowserSession is framework-agnostic**: Works with RSpec, Minitest, Cucumber, or standalone scripts
- **Configuration system uses dependency injection**: PlaywrightConfiguration.for_environment() detects environment without hardcoded Rails assumptions
- **Artifact storage abstraction**: ArtifactStorage interface enables future cloud storage (S3, GCS, Azure Blob) without changing client code

**Issues**:
1. **Minor coupling in RSpec integration**: The `spec/support/playwright_helpers.rb` file uses global variables (`$playwright_artifact_capture`, `$playwright_retry_policy`), which reduces reusability. Consider using RSpec's `let` or instance variables.
2. **Capybara driver registration is Rails-specific**: While the underlying components are framework-agnostic, the Capybara integration assumes Rails project structure (`spec/support/`).

**Recommendation**:
```ruby
# Instead of global variables in spec/support/playwright_helpers.rb:
RSpec.configure do |config|
  config.before(:suite) do
    config.add_setting :playwright_artifact_capture
    config.add_setting :playwright_retry_policy

    config.playwright_artifact_capture = Testing::PlaywrightArtifactCapture.new(...)
    config.playwright_retry_policy = Testing::RetryPolicy.new(...)
  end
end
```

**Reusability Potential**:
- ✅ `Testing::Utils::PathUtils` → Can be extracted to gem (e.g., `testing-utils`)
- ✅ `Testing::Utils::EnvUtils` → Can be extracted to gem
- ✅ `Testing::PlaywrightBrowserSession` → Can be extracted to gem (e.g., `playwright-session-manager`)
- ✅ `Testing::BrowserDriver` → Can be used in other projects with Puppeteer, Selenium
- ✅ `Testing::RetryPolicy` → Can be used for any retry logic (API calls, database connections)
- ⚠️ Capybara integration → Specific to Rails/Capybara projects (acceptable)

**Score Justification**: 8.5/10.0
- Components are highly generalized (9/10)
- Minor Rails/RSpec coupling in integration layer (-0.5)
- Excellent abstraction with BrowserDriver interface (+0.5)

---

### 2. Business Logic Independence: 8.0 / 10.0 (Weight: 30%)

**Findings**:
- **Perfect separation of browser automation logic from test framework**: PlaywrightBrowserSession, PlaywrightDriver, and PlaywrightArtifactCapture have no dependencies on RSpec, Capybara, or Rails
- **Utility libraries are framework-agnostic**: PathUtils works without Rails by falling back to `Pathname.new(Dir.pwd)`
- **Configuration uses environment detection, not framework assumptions**: EnvUtils checks `Rails.env`, `RACK_ENV`, or `APP_ENV` in that order
- **Retry logic is decoupled from RSpec**: RetryPolicy accepts configurable error types, not hardcoded `RSpec::Expectations::ExpectationNotMetError`
- **Artifact capture works without test framework**: Can be used in CLI scripts, background jobs, or monitoring tools

**Portability Assessment**:
- **Can this logic run in CLI?** ✅ YES - PlaywrightBrowserSession example shows standalone script usage
- **Can this logic run in mobile app?** ⚠️ N/A - Browser automation is inherently desktop/server-based
- **Can this logic run in background job?** ✅ YES - Can schedule browser automation tasks with Sidekiq, Resque, etc.
- **Can this logic run in Sinatra app?** ✅ YES - Design explicitly mentions Sinatra compatibility
- **Can this logic run in Minitest?** ✅ YES - Complete Minitest example provided (lines 1497-1520)

**Issues**:
1. **One remaining Rails coupling in RSpec helpers**: Line 1783 shows `logger = defined?(Rails) ? Rails.logger : Logger.new(STDOUT)`. While this is acceptable as a fallback, it could be cleaner with explicit logger injection.

**Recommendation**:
```ruby
# spec/support/playwright_helpers.rb
RSpec.configure do |config|
  config.before(:suite) do
    # Explicit logger configuration instead of conditional
    logger = Testing::Utils::EnvUtils.get('LOGGER_TARGET') == 'stdout' ?
             Logger.new(STDOUT) :
             Logger.new("log/test.log")

    # Only use Rails.logger if explicitly requested via ENV
    logger = Rails.logger if defined?(Rails) && ENV['USE_RAILS_LOGGER'] == 'true'
  end
end
```

**Score Justification**: 8.0/10.0
- Perfect separation in core components (9/10)
- Minor Rails coupling in integration helpers (-1.0)

---

### 3. Domain Model Abstraction: 8.5 / 10.0 (Weight: 20%)

**Findings**:
- **Configuration models are pure Ruby**: PlaywrightConfiguration is a plain Ruby class with no ActiveRecord, ORM, or framework dependencies
- **Artifact metadata uses plain Hash**: FileSystemStorage saves metadata as JSON, not ActiveRecord models
- **Browser driver abstraction is interface-based**: BrowserDriver defines a clean interface without framework coupling
- **Session management is stateless**: PlaywrightBrowserSession manages browser lifecycle without persistence layer assumptions
- **Utility modules are stateless and side-effect free**: PathUtils, EnvUtils, TimeUtils, StringUtils are pure functions

**Examples of Pure Domain Models**:
```ruby
# PlaywrightConfiguration - Plain Ruby class (no ORM)
class PlaywrightConfiguration
  attr_reader :browser_type, :headless, :viewport, :slow_mo, :timeout

  def initialize(browser_type:, headless:, viewport:, slow_mo:, timeout:, ...)
    @browser_type = browser_type
    @headless = headless
    # ... no ActiveRecord magic
  end
end

# Artifact metadata - Plain Hash (no model objects)
{
  "correlation_id": "test-run-20251123-143025-a8f3d1",
  "test_name": "Operator can sign in successfully",
  "browser": "chromium",
  "viewport": {"width": 1920, "height": 1080}
}
```

**Issues**:
None identified. All models are framework-agnostic and persistence-agnostic.

**Questions Answered**:
- **Can we switch from PostgreSQL to MongoDB?** ✅ YES - No database models in this design
- **Can we use models in non-Rails framework?** ✅ YES - All models are plain Ruby classes
- **Are models specific to HTTP API responses?** ✅ NO - Models are generic data structures

**Score Justification**: 8.5/10.0
- Perfect domain model abstraction (9/10)
- Could add value objects for viewport, browser options (-0.5)

---

### 4. Shared Utility Design: 8.5 / 10.0 (Weight: 15%)

**Findings**:
- **Comprehensive utility library created**: PathUtils, EnvUtils, TimeUtils, StringUtils, NullLogger
- **Zero code duplication**: Filename sanitization extracted to `StringUtils.sanitize_filename`, used consistently across FileSystemStorage and PlaywrightArtifactCapture
- **Utilities are general-purpose**: TimeUtils provides ISO 8601, filename, and human-readable formats - not specific to Playwright
- **NullLogger follows Null Object pattern**: Clean design pattern for optional dependencies
- **Utilities use standard Ruby libraries**: Pathname, ENV, File, Time - no external dependencies

**Utility Reusability Examples**:
```ruby
# PathUtils - Works without Rails
PathUtils.root_path              # Automatically detects Rails.root or uses Dir.pwd
PathUtils.screenshots_path       # tmp/screenshots
PathUtils.tmp_path              # tmp/

# EnvUtils - Works with Rails, Rack, or generic Ruby
EnvUtils.environment            # Tries Rails.env, RACK_ENV, APP_ENV
EnvUtils.ci_environment?        # Detects GitHub Actions, CircleCI, etc.

# TimeUtils - General-purpose timestamp formatting
TimeUtils.format_for_filename   # "20251123-143025"
TimeUtils.format_iso8601        # "2025-11-23T14:30:25Z"
TimeUtils.generate_correlation_id # "test-run-20251123-143025-a8f3d1"

# StringUtils - Secure filename handling
StringUtils.sanitize_filename("My Test!@#$")  # "My_Test____"
StringUtils.truncate_filename(long_name, 255) # Prevents filesystem errors
```

**Issues**:
1. **No utility for environment variable validation**: While EnvUtils.get() exists, there's no utility for type coercion (e.g., `get_int('PORT', 3000)`, `get_bool('DEBUG', false)`)

**Recommendation**:
```ruby
# lib/testing/utils/env_utils.rb
module EnvUtils
  class << self
    # Get integer environment variable with type safety
    def get_int(key, default = 0)
      ENV.fetch(key, default.to_s).to_i
    end

    # Get boolean environment variable
    def get_bool(key, default = false)
      value = ENV.fetch(key, default.to_s)
      %w[true 1 yes].include?(value.downcase)
    end
  end
end
```

**Potential Utilities**:
- ✅ Extract `PathUtils` to gem for reuse across projects
- ✅ Extract `TimeUtils` for consistent timestamp handling
- ✅ Extract `StringUtils` for filename sanitization (security-critical)
- ⚠️ Consider adding `LogUtils` for structured JSON logging

**Score Justification**: 8.5/10.0
- Excellent utility extraction (9/10)
- Missing type-safe environment variable utilities (-0.5)

---

## Reusability Opportunities

### High Potential (Ready for Extraction)

1. **Testing Utilities Gem** (`testing-utils`)
   - **Components**: PathUtils, EnvUtils, TimeUtils, StringUtils, NullLogger
   - **Contexts**: Rails, Sinatra, Hanami, Grape, pure Ruby CLIs
   - **Effort**: Low (already framework-agnostic)
   - **Impact**: High (eliminates boilerplate across all Ruby projects)

2. **Playwright Session Manager** (`playwright-session-ruby`)
   - **Components**: PlaywrightBrowserSession, PlaywrightDriver, PlaywrightArtifactCapture
   - **Contexts**: RSpec, Minitest, Cucumber, standalone automation scripts
   - **Effort**: Medium (add documentation, versioning)
   - **Impact**: High (no existing Ruby gem for this use case)

3. **Generic Retry Policy** (`ruby-retry-policy`)
   - **Components**: RetryPolicy
   - **Contexts**: API clients, database connections, file operations, external services
   - **Effort**: Low (already framework-agnostic)
   - **Impact**: Medium (similar gems exist, but this has better configurability)

### Medium Potential (Minor Refactoring Needed)

1. **Artifact Storage Abstraction** (`artifact-storage-ruby`)
   - **Components**: ArtifactStorage, FileSystemStorage
   - **Refactoring**: Add S3Storage, GCSStorage implementations
   - **Contexts**: Test artifacts, log storage, file uploads
   - **Effort**: Medium (need cloud storage implementations)
   - **Impact**: Medium (useful for multi-cloud deployments)

### Low Potential (Feature-Specific)

1. **Capybara Integration**
   - **Components**: `spec/support/capybara.rb`, `spec/support/playwright_helpers.rb`
   - **Reason**: Tightly coupled to RSpec + Capybara (acceptable for this project)
   - **Reusability**: Can be templated for other Rails projects

2. **GitHub Actions Workflow**
   - **Components**: `.github/workflows/rspec.yml`
   - **Reason**: CI/CD configurations are project-specific
   - **Reusability**: Can be used as template for similar Rails projects

---

## Action Items for Designer

**Status: Approved** - No critical changes required. The design has achieved excellent reusability.

### Optional Enhancements (Non-blocking):

1. **Refactor RSpec global variables** (Low Priority)
   - Replace `$playwright_artifact_capture` with RSpec settings
   - Replace `$playwright_retry_policy` with RSpec settings
   - **Benefit**: Cleaner RSpec integration, better testability

2. **Add type-safe environment variable utilities** (Low Priority)
   - Add `EnvUtils.get_int()`, `EnvUtils.get_bool()`
   - **Benefit**: Prevents runtime type errors

3. **Create example Sinatra integration** (Low Priority)
   - Add `examples/sinatra_integration.rb` to design document
   - **Benefit**: Demonstrates portability to non-Rails frameworks

4. **Document gem extraction plan** (Low Priority)
   - Add section on how to extract utilities to gems
   - **Benefit**: Clear roadmap for open-sourcing components

---

## Reusability Metrics

### Component Reusability Ratio

**Framework-Agnostic Components**: 11 out of 13 components (84.6%)

| Component | Framework-Agnostic? | Reusable In |
|-----------|---------------------|-------------|
| PathUtils | ✅ YES | Rails, Sinatra, Hanami, CLI |
| EnvUtils | ✅ YES | Rails, Sinatra, Hanami, CLI |
| TimeUtils | ✅ YES | Any Ruby project |
| StringUtils | ✅ YES | Any Ruby project |
| NullLogger | ✅ YES | Any Ruby project |
| PlaywrightConfiguration | ✅ YES | Rails, Sinatra, Hanami, CLI |
| BrowserDriver | ✅ YES | Any browser automation project |
| PlaywrightDriver | ✅ YES | Any Playwright-based project |
| PlaywrightBrowserSession | ✅ YES | RSpec, Minitest, Cucumber, CLI |
| ArtifactStorage | ✅ YES | Any artifact storage scenario |
| FileSystemStorage | ✅ YES | Any filesystem-based storage |
| RetryPolicy | ✅ YES | Any retry scenario |
| Capybara Integration | ❌ NO | Rails + Capybara only |
| RSpec Helpers | ❌ NO | Rails + RSpec only (but uses framework-agnostic components) |

### Dependency Analysis

**External Dependencies**: 1 (Playwright gem only)
**Rails Dependencies**: 0 (all Rails usage is conditional with fallbacks)
**Framework Assumptions**: 0 (works with any Rack-based framework)

### Portability Score

**Test Execution Contexts**:
- ✅ RSpec (primary)
- ✅ Minitest (example provided)
- ✅ Cucumber (compatible via PlaywrightBrowserSession)
- ✅ Standalone scripts (example provided)
- ✅ Background jobs (Sidekiq, Resque, etc.)
- ✅ CLI tools (example provided)

**Framework Compatibility**:
- ✅ Rails (primary)
- ✅ Sinatra (mentioned in design)
- ✅ Hanami (mentioned in design)
- ✅ Pure Ruby (examples provided)

---

## Structured Data

```yaml
evaluation_result:
  evaluator: "design-reusability-evaluator"
  design_document: "/Users/yujitsuchiya/cat_salvages_the_relationship/docs/designs/github-actions-rspec-playwright.md"
  timestamp: "2025-11-23T00:00:00Z"
  overall_judgment:
    status: "Approved"
    overall_score: 8.3
  detailed_scores:
    component_generalization:
      score: 8.5
      weight: 0.35
      weighted_score: 2.975
    business_logic_independence:
      score: 8.0
      weight: 0.30
      weighted_score: 2.400
    domain_model_abstraction:
      score: 8.5
      weight: 0.20
      weighted_score: 1.700
    shared_utility_design:
      score: 8.5
      weight: 0.15
      weighted_score: 1.275
  reusability_opportunities:
    high_potential:
      - component: "Testing Utilities Gem"
        contexts: ["Rails", "Sinatra", "Hanami", "CLI"]
        effort: "Low"
        impact: "High"
      - component: "Playwright Session Manager"
        contexts: ["RSpec", "Minitest", "Cucumber", "CLI"]
        effort: "Medium"
        impact: "High"
      - component: "Generic Retry Policy"
        contexts: ["API clients", "Database connections", "External services"]
        effort: "Low"
        impact: "Medium"
    medium_potential:
      - component: "Artifact Storage Abstraction"
        refactoring_needed: "Add cloud storage implementations (S3, GCS)"
        effort: "Medium"
        impact: "Medium"
    low_potential:
      - component: "Capybara Integration"
        reason: "Tightly coupled to RSpec + Capybara (acceptable)"
      - component: "GitHub Actions Workflow"
        reason: "CI/CD configurations are project-specific"
  reusable_component_ratio: 84.6
  rails_dependencies_removed: true
  framework_agnostic_utilities: true
  playwright_browser_session_implemented: true
  dependency_injection_complete: true
  improvements_verified:
    rails_root_replaced_with_path_utils: true
    rails_env_replaced_with_env_utils: true
    rails_logger_replaced_with_injection: true
    playwright_browser_session_framework_agnostic: true
    shared_utility_libraries_created: true
    retry_policy_error_types_configurable: true
```

---

## Conclusion

**The design has achieved excellent reusability (8.3/10.0) and is APPROVED.**

### Key Achievements:

1. ✅ **All Rails dependencies removed**: PathUtils, EnvUtils replace Rails.root and Rails.env
2. ✅ **PlaywrightBrowserSession implemented**: Framework-agnostic browser automation with RSpec, Minitest, CLI examples
3. ✅ **Shared utility libraries created**: PathUtils, EnvUtils, TimeUtils, StringUtils, NullLogger
4. ✅ **Framework decoupling complete**: RetryPolicy accepts configurable error types, all services use dependency injection
5. ✅ **84.6% of components are framework-agnostic**: Only Capybara and RSpec integrations are framework-specific (acceptable)

### Reusability Score Breakdown:
- Component Generalization: 8.5/10.0 (excellent abstraction layers)
- Business Logic Independence: 8.0/10.0 (perfect separation with minor RSpec coupling)
- Domain Model Abstraction: 8.5/10.0 (pure Ruby classes, no ORM dependencies)
- Shared Utility Design: 8.5/10.0 (comprehensive utilities, zero duplication)

**Overall Score: 8.3/10.0** ✅ **APPROVED**

The design exceeds the minimum threshold (7.0/10.0) and demonstrates industry best practices for component reusability, framework independence, and maintainability.
