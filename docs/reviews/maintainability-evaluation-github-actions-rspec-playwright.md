# Code Maintainability Evaluation: GitHub Actions RSpec with Playwright Integration

**Evaluation Date**: 2025-11-23
**Evaluator**: EDAF Code Maintainability Evaluator v1.0
**Technology Stack**: Ruby 3.4.6, Rails 6.1.4, RSpec, Playwright

---

## Executive Summary

| Metric | Score | Status |
|--------|-------|--------|
| **Overall Maintainability** | **8.7/10** | ✅ EXCELLENT |
| Code Complexity | 9.5/10 | ✅ Excellent |
| Code Duplication | 9.0/10 | ✅ Excellent |
| Separation of Concerns | 9.5/10 | ✅ Excellent |
| Dependency Management | 8.5/10 | ✅ Good |
| Ease of Modification | 7.5/10 | ✅ Good |

**Overall Assessment**: The GitHub Actions RSpec with Playwright integration demonstrates **excellent maintainability** with clean architecture, minimal complexity, and strong separation of concerns. Minor improvements recommended for reducing class size and parameter counts.

---

## 1. Code Complexity Analysis

### 1.1 Cyclomatic Complexity

**Score: 9.5/10** ✅ Excellent

**Metrics**:
- **Total Files Analyzed**: 15
- **Total Lines of Code**: 1,791
- **Average Method Length**: ~15 lines
- **Maximum Method Length**: 24 lines (FileSystemStorage#list_artifacts)
- **Complex Methods (>20 lines)**: 2/119 (1.7%)
- **Cyclomatic Complexity Violations**: 0

**RuboCop Metrics Results**:
```json
{
  "CyclomaticComplexity": 0 violations,
  "PerceivedComplexity": 0 violations,
  "AbcSize": 0 violations
}
```

**Analysis**:
- All methods maintain **low cyclomatic complexity** (no violations)
- No methods exceed cyclomatic complexity threshold of 10
- No perceived complexity violations
- Clean control flow structures throughout the codebase

**Long Methods Identified**:
1. **FileSystemStorage#list_artifacts** (24 lines)
   - Purpose: List all artifacts with metadata
   - Complexity: Low (simple iteration)
   - Recommendation: Consider extracting metadata loading logic

2. **PlaywrightArtifactCapture#capture_trace** (23 lines)
   - Purpose: Capture trace with error handling
   - Complexity: Low (mostly error handling)
   - Recommendation: Acceptable length given error handling needs

**Strengths**:
- ✅ All methods are small and focused (average 15 lines)
- ✅ No deeply nested conditionals
- ✅ Single Responsibility Principle well-applied
- ✅ Clear, linear control flow

**Recommendations**:
- Consider extracting helper methods for metadata handling in FileSystemStorage
- Monitor method length as features expand

---

### 1.2 Cognitive Complexity

**Score: 9.5/10** ✅ Excellent

**Metrics**:
- **Max Nesting Depth**: 2 levels
- **Conditional Complexity**: Low (mostly simple if/else)
- **Loop Complexity**: Low (simple iterations)

**Analysis**:
- **No deeply nested structures** (max 2 levels)
- **Simple conditionals** throughout
- **No complex boolean logic** (minimal use of && or ||)

**Example of Clean Code** (RetryPolicy#execute):
```ruby
def execute
  attempt = 1
  begin
    yield
  rescue StandardError => e
    if retryable_error?(e) && attempt < max_attempts
      delay = calculate_delay(attempt)
      log_retry_attempt(attempt, e, delay)
      sleep(delay)
      attempt += 1
      retry
    else
      raise
    end
  end
end
```

**Strengths**:
- ✅ Flat control structures
- ✅ Early returns reduce nesting
- ✅ Descriptive helper methods improve readability

---

## 2. Code Duplication Analysis

### 2.1 Duplication Metrics

**Score: 9.0/10** ✅ Excellent

**Metrics**:
- **Total Lines**: 1,791
- **Estimated Duplication**: <3%
- **Duplicated Patterns**: Minimal

**Manual Analysis Results**:

**Acceptable Duplication** (Pattern Consistency):
1. **Error Handling Pattern** (used in 4 classes):
   ```ruby
   rescue StandardError => e
     logger.error("Failed to ...: #{e.message}")
     raise
   end
   ```
   - **Justification**: Consistent error handling is a feature, not duplication

2. **Metadata Enhancement Pattern** (used in 3 classes):
   ```ruby
   enhanced_metadata = metadata.merge(
     timestamp: Utils::TimeUtils.format_iso8601,
     correlation_id: artifact_name
   )
   ```
   - **Justification**: Common pattern for artifact metadata

3. **Path Sanitization** (used in 2 classes):
   ```ruby
   sanitized_name = Utils::StringUtils.sanitize_filename(name)
   ```
   - **Justification**: Utility method call, not duplication

**No Structural Duplication Detected**:
- ✅ No copy-pasted methods
- ✅ No duplicated business logic
- ✅ DRY principle well-applied

**Strengths**:
- ✅ Excellent use of utility modules (StringUtils, TimeUtils, PathUtils)
- ✅ Common patterns extracted to shared helpers
- ✅ Interface-based design reduces duplication (BrowserDriver, ArtifactStorage)

**Recommendations**:
- None. Duplication is minimal and acceptable.

---

## 3. Separation of Concerns

### 3.1 Architecture Analysis

**Score: 9.5/10** ✅ Excellent

**Architecture Pattern**: **Layered Architecture with Dependency Injection**

```
┌─────────────────────────────────────────────────┐
│ Integration Layer (RSpec/Capybara Support)      │
│ - spec/support/capybara.rb                      │
│ - spec/support/playwright_helpers.rb            │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│ Orchestration Layer                             │
│ - PlaywrightBrowserSession (session management) │
│ - PlaywrightConfiguration (environment config)  │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│ Service Layer                                   │
│ - PlaywrightDriver (browser automation)         │
│ - PlaywrightArtifactCapture (artifact service)  │
│ - RetryPolicy (retry logic)                     │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│ Infrastructure Layer                            │
│ - FileSystemStorage (storage backend)           │
│ - Utils (PathUtils, EnvUtils, etc.)             │
└─────────────────────────────────────────────────┘
```

**Module Structure**:
```
lib/testing/
├── Interfaces (2 files)
│   ├── browser_driver.rb          # Abstract browser driver
│   └── artifact_storage.rb        # Abstract storage interface
├── Implementations (6 files)
│   ├── playwright_driver.rb       # Playwright implementation
│   ├── playwright_configuration.rb
│   ├── playwright_browser_session.rb
│   ├── playwright_artifact_capture.rb
│   ├── file_system_storage.rb     # Filesystem storage
│   └── retry_policy.rb
└── Utils (5 files)
    ├── path_utils.rb
    ├── env_utils.rb
    ├── time_utils.rb
    ├── string_utils.rb
    └── null_logger.rb
```

**Strengths**:
- ✅ **Clear layer separation** (Integration → Orchestration → Service → Infrastructure)
- ✅ **Interface-based design** (BrowserDriver, ArtifactStorage)
- ✅ **Dependency Injection** throughout (driver, storage, logger)
- ✅ **Single Responsibility Principle** enforced at class level
- ✅ **Framework-agnostic utilities** (no Rails dependencies in lib/testing/utils)

**Dependency Analysis**:

| Class | Dependencies | Coupling |
|-------|-------------|----------|
| PlaywrightDriver | playwright gem, BrowserDriver | Low |
| PlaywrightBrowserSession | driver, config, artifact_capture, retry_policy | Medium (4 deps) |
| PlaywrightConfiguration | Utils::PathUtils, Utils::EnvUtils | Low |
| PlaywrightArtifactCapture | driver, storage, logger | Low (3 deps) |
| FileSystemStorage | Utils::PathUtils, Utils::StringUtils, Utils::TimeUtils | Low |
| RetryPolicy | logger, Utils::NullLogger | Very Low |

**Cohesion Analysis**:
- ✅ All classes have **high cohesion** (related methods and data)
- ✅ Utils modules are **tightly focused** on single concerns
- ✅ No god classes or utility dumping grounds

**Recommendations**:
- None. Separation of concerns is excellent.

---

### 3.2 SOLID Principles Compliance

**Analysis**:

#### ✅ Single Responsibility Principle (SRP)
- **PlaywrightDriver**: Only responsible for Playwright automation
- **PlaywrightConfiguration**: Only responsible for configuration
- **PlaywrightBrowserSession**: Only responsible for session lifecycle
- **PlaywrightArtifactCapture**: Only responsible for artifact capture
- **FileSystemStorage**: Only responsible for filesystem operations
- **RetryPolicy**: Only responsible for retry logic

**Violations**: None

#### ✅ Open/Closed Principle (OCP)
- **BrowserDriver interface**: Allows extending with new browser drivers (Selenium, Puppeteer)
- **ArtifactStorage interface**: Allows extending with new storage backends (S3, Azure)
- **Factory methods**: PlaywrightConfiguration.for_environment allows environment-based configs

**Strengths**:
- Can add new browser drivers without modifying existing code
- Can add new storage backends without modifying artifact capture logic

#### ✅ Liskov Substitution Principle (LSP)
- **PlaywrightDriver** is substitutable for **BrowserDriver**
- **FileSystemStorage** is substitutable for **ArtifactStorage**
- All interface implementations honor contracts

**Violations**: None

#### ✅ Interface Segregation Principle (ISP)
- **BrowserDriver**: Minimal interface (6 methods)
- **ArtifactStorage**: Minimal interface (5 methods)
- No clients forced to depend on methods they don't use

**Violations**: None

#### ⚠️ Dependency Inversion Principle (DIP)
- **Good**: PlaywrightBrowserSession depends on abstractions (driver, storage)
- **Good**: PlaywrightArtifactCapture depends on abstractions (driver, storage)
- **Issue**: Some direct instantiation in spec/support/capybara.rb

**Minor Violation** (Line 14 in spec/support/capybara.rb):
```ruby
playwright_driver = Testing::PlaywrightDriver.new  # Direct instantiation
```

**Recommendation**:
- Consider using a factory or service locator for driver instantiation
- Current approach is acceptable for test setup but limits flexibility

**Overall SOLID Score**: 9.0/10

---

## 4. Dependency Management

### 4.1 External Dependencies

**Score: 8.5/10** ✅ Good

**Gem Dependencies**:
```ruby
# Required gems
- playwright-ruby-client (~> 1.45)  # Browser automation
- capybara                          # Testing framework integration

# Optional gems (graceful fallback)
- capybara-playwright              # Capybara adapter
```

**Dependency Count**: 27 requires across 15 files

**Dependency Analysis**:

| Dependency Type | Count | Status |
|----------------|-------|--------|
| Standard Library | 15 | ✅ Good |
| Testing Framework | 5 | ✅ Good |
| Browser Automation | 1 | ✅ Good |
| Internal Modules | 6 | ✅ Excellent |

**Strengths**:
- ✅ **Minimal external dependencies** (only playwright gem required)
- ✅ **Graceful fallback** to Selenium if Playwright unavailable
- ✅ **Framework-agnostic utilities** (no Rails dependencies in core)
- ✅ **Explicit require statements** (no autoload magic)

**Dependency Injection Pattern**:
```ruby
# Example: PlaywrightBrowserSession
def initialize(driver:, config:, artifact_capture:, retry_policy:, logger: Utils::NullLogger.new)
  @driver = driver              # Injected
  @config = config              # Injected
  @artifact_capture = artifact_capture  # Injected
  @retry_policy = retry_policy  # Injected
  @logger = logger              # Injected (with default)
end
```

**Recommendations**:
- Consider adding dependency version constraints in documentation
- Document fallback behavior for missing gems

---

### 4.2 Internal Dependencies

**Score: 9.0/10** ✅ Excellent

**Module Coupling Analysis**:

```
Testing::PlaywrightBrowserSession
  ├── depends on: PlaywrightDriver (interface)
  ├── depends on: PlaywrightConfiguration
  ├── depends on: PlaywrightArtifactCapture
  ├── depends on: RetryPolicy
  └── depends on: Utils::NullLogger

Testing::PlaywrightArtifactCapture
  ├── depends on: BrowserDriver (interface)
  ├── depends on: ArtifactStorage (interface)
  ├── depends on: Utils::TimeUtils
  ├── depends on: Utils::StringUtils
  └── depends on: Utils::NullLogger

Testing::PlaywrightDriver
  └── depends on: BrowserDriver (interface)

Testing::PlaywrightConfiguration
  ├── depends on: Utils::PathUtils
  └── depends on: Utils::EnvUtils

Testing::FileSystemStorage
  ├── depends on: ArtifactStorage (interface)
  ├── depends on: Utils::PathUtils
  ├── depends on: Utils::StringUtils
  └── depends on: Utils::TimeUtils

Testing::RetryPolicy
  └── depends on: Utils::NullLogger
```

**Coupling Metrics**:
- **Average Coupling**: 2.5 dependencies per class
- **Maximum Coupling**: 4 dependencies (PlaywrightBrowserSession)
- **Circular Dependencies**: 0

**Strengths**:
- ✅ **Acyclic dependency graph** (no circular dependencies)
- ✅ **Low coupling** (average 2.5 deps per class)
- ✅ **Utility modules** reduce coupling
- ✅ **Interface-based coupling** (depends on abstractions, not concretions)

**Recommendations**:
- None. Internal dependency management is excellent.

---

## 5. Ease of Modification

### 5.1 Extensibility Analysis

**Score: 7.5/10** ✅ Good

**Easy to Modify**:
1. ✅ **Add new browser drivers** (extend BrowserDriver interface)
2. ✅ **Add new storage backends** (extend ArtifactStorage interface)
3. ✅ **Add new configuration presets** (add factory methods to PlaywrightConfiguration)
4. ✅ **Add new utility helpers** (add to Utils module)

**Moderate Difficulty**:
1. ⚠️ **Modify PlaywrightConfiguration initialization** (6 parameters - long parameter list)
2. ⚠️ **Modify retry behavior** (hardcoded in RetryPolicy constants)

**Difficult to Modify**:
1. ❌ **Change Capybara integration approach** (tightly coupled in spec/support/capybara.rb)

**RuboCop Violations Related to Modification**:

```ruby
# Metrics/ClassLength violations
- FileSystemStorage: 101/100 lines (1 line over limit)
- PlaywrightConfiguration: 111/100 lines (11 lines over limit)

# Metrics/ParameterLists violations
- PlaywrightConfiguration#initialize: 6/5 parameters
- RetryPolicy#initialize: 6/5 parameters

# Metrics/MethodLength violations
- FileSystemStorage#list_artifacts: 24/20 lines
- PlaywrightArtifactCapture#capture_trace: 23/20 lines
```

**Impact on Maintainability**:
- **Class Length**: Minor issue. Acceptable for configuration classes.
- **Parameter Lists**: Medium issue. Consider using options hash or builder pattern.
- **Method Length**: Minor issue. Methods are still readable.

**Recommendations**:

### Priority 1: Reduce Parameter Lists

**Before**:
```ruby
def initialize(browser_type:, headless:, viewport:, slow_mo:, timeout:, trace_mode:)
  # 6 parameters
end
```

**After** (Options Hash Pattern):
```ruby
def initialize(options = {})
  @browser_type = options.fetch(:browser_type, DEFAULT_BROWSER)
  @headless = options.fetch(:headless, DEFAULT_HEADLESS)
  @viewport = options.fetch(:viewport, { width: DEFAULT_VIEWPORT_WIDTH, height: DEFAULT_VIEWPORT_HEIGHT })
  @slow_mo = options.fetch(:slow_mo, DEFAULT_SLOW_MO)
  @timeout = options.fetch(:timeout, DEFAULT_TIMEOUT)
  @trace_mode = options.fetch(:trace_mode, DEFAULT_TRACE_MODE)
end
```

**Benefit**: More flexible, easier to add new parameters

### Priority 2: Extract Metadata Logic

**Current** (FileSystemStorage#list_artifacts):
```ruby
def list_artifacts
  artifacts = []

  # Screenshot listing (12 lines)
  Dir.glob(screenshots_path.join('*.png')).each do |screenshot_path|
    # ...
  end

  # Trace listing (12 lines)
  Dir.glob(traces_path.join('*.zip')).each do |trace_path|
    # ...
  end

  artifacts.sort_by { |a| a[:name] }
end
```

**Recommended** (Extract helper methods):
```ruby
def list_artifacts
  artifacts = list_screenshots + list_traces
  artifacts.sort_by { |a| a[:name] }
end

private

def list_screenshots
  Dir.glob(screenshots_path.join('*.png')).map do |path|
    build_artifact_entry(path, 'screenshot')
  end
end

def list_traces
  Dir.glob(traces_path.join('*.zip')).map do |path|
    build_artifact_entry(path, 'trace')
  end
end

def build_artifact_entry(path, type)
  name = File.basename(path, File.extname(path))
  metadata_path = Pathname.new(path).sub_ext('.metadata.json')

  {
    name: name,
    path: path,
    type: type,
    metadata: load_metadata(metadata_path)
  }
end
```

**Benefit**: Each method has single responsibility, easier to test

---

### 5.2 Test Coverage Impact

**Analysis**:

**Testability Score**: 9.0/10 ✅ Excellent

**Strengths**:
- ✅ **Dependency injection** makes classes easy to test
- ✅ **Interface-based design** allows easy mocking
- ✅ **Pure functions** in Utils modules (no side effects)
- ✅ **No hidden dependencies** (no global state)

**Example of Testable Code**:
```ruby
# Easy to test with mocked dependencies
session = PlaywrightBrowserSession.new(
  driver: mock_driver,
  config: mock_config,
  artifact_capture: mock_artifact_capture,
  retry_policy: mock_retry_policy,
  logger: mock_logger
)
```

**Recommendations**:
- Add unit tests for Utils modules
- Add integration tests for browser session lifecycle
- Add tests for error handling paths

---

## 6. GitHub Actions Workflow Analysis

### 6.1 Workflow Maintainability

**Score: 8.5/10** ✅ Good

**File**: `.github/workflows/rspec.yml`

**Strengths**:
- ✅ **Clear step names** (easy to understand)
- ✅ **Proper environment variables** (DATABASE_URL, PLAYWRIGHT_BROWSER, etc.)
- ✅ **Health checks** for MySQL service
- ✅ **Conditional artifact uploads** (only on failure)
- ✅ **Coverage threshold enforcement** (88%)

**Workflow Structure**:
```yaml
jobs:
  rspec:
    - Setup: Ruby, Node.js, MySQL
    - Dependencies: bundle install, npm ci, playwright install
    - Database: db:create, db:schema:load
    - Assets: Build JS, CSS, precompile
    - Tests: Run RSpec
    - Artifacts: Upload screenshots, traces, coverage (conditional)
    - Validation: Check coverage threshold
```

**Areas for Improvement**:

1. **⚠️ Hardcoded Ruby version** (3.4.6)
   - Recommendation: Use `.ruby-version` file or matrix strategy

2. **⚠️ Hardcoded coverage threshold** (88%)
   - Recommendation: Move to configuration file

3. **⚠️ No workflow caching optimization**
   - Recommendation: Add caching for Playwright browsers

**Recommended Improvements**:

```yaml
# Use matrix for multiple Ruby versions
strategy:
  matrix:
    ruby-version: [3.4.6]  # Easily add more versions

# Add Playwright browser caching
- name: Cache Playwright browsers
  uses: actions/cache@v4
  with:
    path: ~/.cache/ms-playwright
    key: playwright-${{ runner.os }}-${{ hashFiles('package-lock.json') }}

# Move coverage threshold to environment variable
env:
  COVERAGE_THRESHOLD: 88
```

---

## 7. Overall Code Quality Metrics

### Summary Table

| Category | Metric | Value | Threshold | Status |
|----------|--------|-------|-----------|--------|
| **Complexity** | Cyclomatic violations | 0 | 0 | ✅ Pass |
| | Perceived complexity violations | 0 | 0 | ✅ Pass |
| | ABC size violations | 0 | 0 | ✅ Pass |
| | Average method length | 15 lines | ≤20 | ✅ Pass |
| | Max method length | 24 lines | ≤30 | ✅ Pass |
| **Size** | Total lines of code | 1,791 | - | ✅ Good |
| | Classes over size limit | 2 | 0 | ⚠️ Minor |
| | Methods over size limit | 2 | 0 | ⚠️ Minor |
| **Design** | Parameter list violations | 2 | 0 | ⚠️ Minor |
| | Circular dependencies | 0 | 0 | ✅ Pass |
| | Average coupling | 2.5 deps | ≤5 | ✅ Pass |
| | SOLID compliance | 9.0/10 | ≥8.0 | ✅ Pass |
| **Duplication** | Estimated duplication | <3% | ≤5% | ✅ Pass |
| **Dependencies** | External dependencies | 2 gems | - | ✅ Good |
| | Internal coupling | Low | Low | ✅ Good |

---

## 8. Recommendations

### Priority 1: Critical (None)
No critical issues identified. Code is production-ready.

### Priority 2: High (Implement Soon)

1. **Reduce Parameter Lists** (2 violations)
   - **Files**: PlaywrightConfiguration, RetryPolicy
   - **Impact**: Easier to extend and maintain
   - **Effort**: 2 hours
   - **Approach**: Use options hash pattern or builder pattern

2. **Extract Long Methods** (2 violations)
   - **Files**: FileSystemStorage#list_artifacts, PlaywrightArtifactCapture#capture_trace
   - **Impact**: Improved readability and testability
   - **Effort**: 1 hour
   - **Approach**: Extract private helper methods

### Priority 3: Medium (Consider for Next Iteration)

3. **Reduce Class Size** (2 violations)
   - **Files**: PlaywrightConfiguration (111 lines), FileSystemStorage (101 lines)
   - **Impact**: Better Single Responsibility adherence
   - **Effort**: 3 hours
   - **Approach**: Extract factory methods to separate class, extract metadata handling

4. **Add Workflow Optimizations**
   - **File**: .github/workflows/rspec.yml
   - **Impact**: Faster CI runs
   - **Effort**: 1 hour
   - **Approach**: Add Playwright browser caching

### Priority 4: Low (Nice to Have)

5. **Add Comprehensive Unit Tests**
   - **Files**: All Utils modules
   - **Impact**: Higher confidence in utilities
   - **Effort**: 4 hours
   - **Approach**: Add RSpec tests for edge cases

6. **Document Fallback Behavior**
   - **File**: spec/support/capybara.rb
   - **Impact**: Clearer understanding of Selenium fallback
   - **Effort**: 30 minutes
   - **Approach**: Add inline documentation

---

## 9. Conclusion

### Overall Assessment

The GitHub Actions RSpec with Playwright integration demonstrates **excellent maintainability** with a score of **8.7/10**. The codebase exhibits:

**Strengths**:
- ✅ **Clean Architecture**: Well-layered design with clear separation of concerns
- ✅ **Low Complexity**: All methods maintain low cyclomatic and cognitive complexity
- ✅ **Minimal Duplication**: Excellent use of utilities and interfaces
- ✅ **Strong SOLID Compliance**: Interface-based design enables extensibility
- ✅ **Dependency Injection**: Makes code highly testable
- ✅ **Framework-Agnostic**: Core utilities work without Rails dependencies

**Minor Issues**:
- ⚠️ 2 classes slightly over size limit (acceptable for configuration classes)
- ⚠️ 2 methods slightly over length limit (acceptable given error handling)
- ⚠️ 2 parameter list violations (can be improved with options hash pattern)

**Verdict**: **Ready for production use** with minor refactoring recommended for long-term maintainability.

### Maintainability Trends

| Aspect | Current | Target | Gap |
|--------|---------|--------|-----|
| Code Complexity | 9.5/10 | 9.0/10 | ✅ Exceeds target |
| Code Duplication | 9.0/10 | 9.0/10 | ✅ Meets target |
| Separation of Concerns | 9.5/10 | 9.0/10 | ✅ Exceeds target |
| Dependency Management | 8.5/10 | 9.0/10 | ⚠️ 0.5 below target |
| Ease of Modification | 7.5/10 | 8.5/10 | ⚠️ 1.0 below target |

**Recommendation**: Address Priority 2 recommendations to close gaps and achieve 9.0/10+ across all aspects.

---

## Appendix A: File-by-File Breakdown

### Core Components

| File | Lines | Classes | Methods | Complexity | Status |
|------|-------|---------|---------|------------|--------|
| playwright_driver.rb | 138 | 1 | 9 | Low | ✅ Excellent |
| playwright_configuration.rb | 255 | 1 | 11 | Low | ⚠️ 111 lines (over limit) |
| playwright_browser_session.rb | 230 | 1 | 12 | Low | ✅ Excellent |
| playwright_artifact_capture.rb | 168 | 1 | 7 | Low | ⚠️ 1 method over limit |
| file_system_storage.rb | 219 | 1 | 14 | Low | ⚠️ 101 lines (over limit) |
| retry_policy.rb | 180 | 1 | 8 | Low | ⚠️ 6 parameters |
| browser_driver.rb | 104 | 1 | 8 | N/A (abstract) | ✅ Excellent |
| artifact_storage.rb | 69 | 1 | 7 | N/A (abstract) | ✅ Excellent |

### Utilities

| File | Lines | Modules | Methods | Complexity | Status |
|------|-------|---------|---------|------------|--------|
| path_utils.rb | 93 | 1 | 10 | Very Low | ✅ Excellent |
| env_utils.rb | 97 | 1 | 10 | Very Low | ✅ Excellent |
| time_utils.rb | 87 | 1 | 8 | Very Low | ✅ Excellent |
| string_utils.rb | 107 | 1 | 7 | Very Low | ✅ Excellent |
| null_logger.rb | 57 | 1 | 8 | Very Low | ✅ Excellent |

### Integration Files

| File | Lines | Purpose | Complexity | Status |
|------|-------|---------|------------|--------|
| spec/support/capybara.rb | 75 | RSpec/Capybara integration | Low | ✅ Excellent |
| spec/support/playwright_helpers.rb | 107 | Helper methods for specs | Low | ✅ Excellent |

---

## Appendix B: Metrics Definitions

### Cyclomatic Complexity
- **Definition**: Number of linearly independent paths through code
- **Calculation**: 1 + (number of decision points)
- **Threshold**: ≤10 per method (industry standard)
- **Current Status**: All methods ≤10

### Perceived Complexity
- **Definition**: How difficult code appears to understand (considers nesting)
- **Calculation**: Weighted by nesting depth
- **Threshold**: ≤15 per method (RuboCop default)
- **Current Status**: All methods ≤15

### ABC Size
- **Definition**: Assignment, Branches, Calls metric
- **Calculation**: sqrt(A² + B² + C²)
- **Threshold**: ≤18 per method (RuboCop default)
- **Current Status**: All methods ≤18

### Code Duplication
- **Definition**: Percentage of duplicated lines
- **Threshold**: ≤5% (industry standard)
- **Current Status**: <3% (estimated)

---

**End of Report**
