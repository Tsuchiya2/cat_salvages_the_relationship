# Design Observability Evaluation - GitHub Actions RSpec with Playwright Integration

**Evaluator**: design-observability-evaluator
**Design Document**: docs/designs/github-actions-rspec-playwright.md
**Evaluated**: 2025-11-23T10:30:00+09:00

---

## Overall Judgment

**Status**: Request Changes
**Overall Score**: 3.2 / 5.0

The design provides basic observability for test execution artifacts (screenshots, traces, coverage) but lacks comprehensive production-ready monitoring, logging, and diagnostics strategy. While appropriate for a CI/CD testing infrastructure, there are gaps in structured logging, metrics collection, and health monitoring that would be critical for debugging issues in the CI pipeline itself.

---

## Detailed Scores

### 1. Logging Strategy: 2.5 / 5.0 (Weight: 35%)

**Findings**:
- Minimal logging strategy mentioned - only console output and basic error messages
- No structured logging framework specified for CI workflow execution
- Limited log context for debugging CI failures
- No centralized log aggregation mentioned

**Logging Framework**:
- Not specified - only console output and GitHub Actions default logging

**Log Context**:
- Test failure output (RSpec documentation format)
- Error messages with basic context (error code, description)
- Screenshot paths printed to console
- Trace paths printed to console

**Log Levels**:
- Not specified - relies on default RSpec output levels

**Centralization**:
- GitHub Actions logs (automatically stored by GitHub)
- No custom log aggregation or searchability mentioned

**Issues**:
1. **No structured logging**: Console output like `puts "Screenshot saved: #{screenshot_path}"` is not searchable or parseable
2. **No correlation IDs**: Cannot trace a specific test run across multiple logs
3. **Limited debugging context**: Error messages lack environment details (Ruby version, Node version, browser version at runtime)
4. **No workflow-level logging**: No logging strategy for the CI workflow itself (setup steps, timing, resource usage)

**Recommendation**:
Implement structured logging for CI workflow:

```ruby
# spec/support/playwright.rb
require 'json'

module PlaywrightLogger
  def self.log(level:, message:, context: {})
    log_entry = {
      timestamp: Time.now.iso8601,
      level: level,
      message: message,
      context: context.merge(
        rails_env: Rails.env,
        ci: ENV['CI'].present?,
        github_run_id: ENV['GITHUB_RUN_ID'],
        github_sha: ENV['GITHUB_SHA']
      )
    }

    # Output as JSON for structured parsing
    puts log_entry.to_json
  end
end

# Usage
PlaywrightLogger.log(
  level: 'ERROR',
  message: 'System spec failed',
  context: {
    spec_file: example.file_path,
    spec_description: example.full_description,
    screenshot_path: screenshot_path,
    duration_seconds: example.execution_result.run_time
  }
)
```

Add GitHub Actions workflow logging:

```yaml
# .github/workflows/rspec.yml
- name: Run RSpec
  run: |
    echo "::group::RSpec Execution"
    echo "Start time: $(date -Iseconds)"
    echo "Ruby version: $(ruby -v)"
    echo "Rails version: $(bundle exec rails -v)"
    bundle exec rspec --format documentation --format RspecJunitFormatter --out tmp/rspec-results.xml
    EXIT_CODE=$?
    echo "End time: $(date -Iseconds)"
    echo "Exit code: $EXIT_CODE"
    echo "::endgroup::"
    exit $EXIT_CODE
```

**Observability Benefit**:
- Searchable logs by test name, failure type, or run ID
- Correlate failures across multiple workflow runs
- Export logs to external systems (e.g., Elasticsearch) for analysis

### 2. Metrics & Monitoring: 3.0 / 5.0 (Weight: 30%)

**Findings**:
- Basic metrics collected via artifacts (test results, coverage)
- No real-time metrics or monitoring dashboard
- Performance benchmarks defined but not monitored
- No alerting mechanism for degraded test performance

**Key Metrics**:
- Test execution time (captured in RSpec output)
- Coverage percentage (SimpleCov report)
- Test pass/fail counts (JUnit XML format)
- Artifact sizes (screenshots, traces)

**Monitoring System**:
- Not specified - relies on GitHub Actions UI

**Alerts**:
- SimpleCov threshold (88% minimum) - fails build
- No alerts for:
  - Execution time exceeding target (5 minutes)
  - Flakiness rate > 1%
  - Workflow failure rate > threshold

**Dashboards**:
- Not mentioned - no visualization of trends over time

**Issues**:
1. **No trend monitoring**: Cannot detect gradual performance degradation
2. **No flakiness tracking**: No automated detection of flaky tests
3. **No resource monitoring**: No tracking of CI runner resource usage (CPU, memory, disk)
4. **No workflow metrics**: No monitoring of workflow queue time, setup duration, or artifact upload time

**Recommendation**:
Add metrics collection:

```yaml
# .github/workflows/rspec.yml
- name: Collect metrics
  if: always()
  run: |
    # Generate metrics file
    cat > tmp/workflow-metrics.json <<EOF
    {
      "workflow_run_id": "${{ github.run_id }}",
      "workflow_run_number": "${{ github.run_number }}",
      "timestamp": "$(date -Iseconds)",
      "ref": "${{ github.ref }}",
      "sha": "${{ github.sha }}",
      "actor": "${{ github.actor }}",
      "metrics": {
        "rspec_duration_seconds": $(grep -oP 'Finished in \K[0-9.]+' tmp/rspec.log || echo 0),
        "total_examples": $(grep -oP '\K[0-9]+ examples' tmp/rspec.log | grep -oP '[0-9]+' | head -1 || echo 0),
        "failures": $(grep -oP '\K[0-9]+ failures' tmp/rspec.log | grep -oP '[0-9]+' | head -1 || echo 0),
        "coverage_percent": $(jq -r '.result.covered_percent' coverage/.last_run.json || echo 0)
      }
    }
    EOF

- name: Upload metrics
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: workflow-metrics
    path: tmp/workflow-metrics.json
    retention-days: 30
```

Implement flakiness detection:

```ruby
# spec/support/flakiness_tracker.rb
RSpec.configure do |config|
  config.after(:each, type: :system) do |example|
    if example.exception
      # Track flaky test candidates
      FlakynessTracker.record_failure(
        spec_file: example.file_path,
        spec_description: example.full_description,
        timestamp: Time.now.iso8601,
        run_id: ENV['GITHUB_RUN_ID']
      )
    end
  end
end
```

Create monitoring dashboard (optional):
- Use GitHub Actions API to collect metrics
- Visualize in Grafana or Datadog
- Alert on regression patterns

**Observability Benefit**:
- Detect performance regressions early
- Identify flaky tests before they impact development
- Track CI pipeline health over time

### 3. Distributed Tracing: 3.5 / 5.0 (Weight: 20%)

**Findings**:
- Good tracing capability for individual test failures via Playwright traces
- Screenshot capture with timestamps
- Trace files (.zip) can be analyzed with Playwright trace viewer
- Limited correlation between workflow steps and test execution

**Tracing Framework**:
- Playwright tracing (`page.context.tracing.start`)
- Enabled conditionally via `PLAYWRIGHT_TRACE=true`

**Trace ID Propagation**:
- GitHub run ID available as context
- Test example description used as identifier
- No explicit trace ID propagation across workflow steps

**Span Instrumentation**:
- Playwright captures:
  - Screenshots at each action
  - Network requests
  - Console logs
  - DOM snapshots
- Not mentioned for workflow steps themselves

**Issues**:
1. **Tracing disabled by default**: `ENV['PLAYWRIGHT_TRACE'] == 'true'` - not enabled in CI workflow
2. **No workflow-level tracing**: Cannot trace from "git push" → "workflow trigger" → "test execution" → "artifact upload"
3. **Limited context correlation**: Cannot easily link screenshot to specific GitHub Actions step
4. **No span timing details**: No instrumentation of workflow step durations (database setup, asset build, etc.)

**Recommendation**:
Enable Playwright tracing in CI:

```yaml
# .github/workflows/rspec.yml
env:
  PLAYWRIGHT_TRACE: "on-first-retry"  # Capture traces on retry attempts
```

Add workflow step tracing:

```yaml
- name: Setup database
  id: setup-db
  run: |
    START_TIME=$(date +%s)
    bundle exec rails db:create
    bundle exec rails db:schema:load
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    echo "duration_seconds=$DURATION" >> $GITHUB_OUTPUT
    echo "Setup database completed in ${DURATION}s"

- name: Report timing
  if: always()
  run: |
    echo "Database setup: ${{ steps.setup-db.outputs.duration_seconds }}s"
    echo "Asset build: ${{ steps.build-assets.outputs.duration_seconds }}s"
    echo "RSpec execution: ${{ steps.run-rspec.outputs.duration_seconds }}s"
```

Implement trace correlation:

```ruby
# spec/support/playwright.rb
RSpec.configure do |config|
  config.before(:each, type: :system) do
    if ENV['PLAYWRIGHT_TRACE'] == 'true' || ENV['CI']
      trace_name = [
        ENV['GITHUB_RUN_ID'],
        example.metadata[:file_path].gsub('/', '_'),
        example.metadata[:line_number]
      ].compact.join('-')

      page.context.tracing.start(
        name: trace_name,
        screenshots: true,
        snapshots: true,
        sources: true
      )
    end
  end
end
```

**Observability Benefit**:
- Trace entire CI workflow from trigger to completion
- Correlate test failures with specific workflow execution
- Identify bottlenecks in CI pipeline stages

### 4. Health Checks & Diagnostics: 4.0 / 5.0 (Weight: 15%)

**Findings**:
- Good health check implementation for MySQL service
- Database connection retry logic planned
- Playwright browser availability check via error handling
- Asset build verification

**Health Check Endpoints**:
- MySQL health check (GitHub Actions service):
  ```yaml
  --health-cmd="mysqladmin ping"
  --health-interval=10s
  --health-timeout=5s
  --health-retries=3
  ```
- Database connection verification (planned):
  ```ruby
  wait_for_database(timeout: 30)
  ```

**Dependency Checks**:
- MySQL database (health check configured)
- Playwright browsers (installation verification)
- Node.js dependencies (npm ci)
- Ruby dependencies (bundler-cache)
- Asset compilation (build step with error handling)

**Diagnostic Endpoints**:
- Test results (JUnit XML)
- Coverage report (SimpleCov HTML)
- Screenshots on failure
- Playwright traces (optional)
- Workflow artifacts

**Issues**:
1. **No pre-flight checks**: No validation that all dependencies are ready before running tests
2. **Limited environment diagnostics**: No dump of environment variables, versions, or configuration
3. **No health check for asset server**: If tests require running Rails server, no health check mentioned
4. **No diagnostic script**: No single command to verify entire test environment

**Recommendation**:
Add comprehensive diagnostic script:

```bash
# bin/ci-diagnostic
#!/bin/bash
set -e

echo "=== CI Environment Diagnostic ==="
echo "Timestamp: $(date -Iseconds)"
echo "Ruby version: $(ruby -v)"
echo "Rails version: $(bundle exec rails -v)"
echo "Node version: $(node -v)"
echo "npm version: $(npm -v)"
echo ""

echo "=== Database Check ==="
bundle exec rails runner 'puts "Database: #{ActiveRecord::Base.connection.current_database}"'
bundle exec rails runner 'puts "Tables: #{ActiveRecord::Base.connection.tables.count}"'
echo ""

echo "=== Playwright Check ==="
if [ -d "$HOME/.cache/ms-playwright" ]; then
  echo "Playwright browsers installed:"
  ls -lh $HOME/.cache/ms-playwright/
else
  echo "ERROR: Playwright browsers not found"
  exit 1
fi
echo ""

echo "=== Asset Check ==="
if [ -f "app/assets/builds/application.js" ]; then
  echo "JavaScript: $(stat -f%z app/assets/builds/application.js) bytes"
else
  echo "WARNING: JavaScript assets not built"
fi
if [ -f "app/assets/builds/application.css" ]; then
  echo "CSS: $(stat -f%z app/assets/builds/application.css) bytes"
else
  echo "WARNING: CSS assets not built"
fi
echo ""

echo "=== Environment Variables ==="
echo "RAILS_ENV: $RAILS_ENV"
echo "CI: $CI"
echo "PLAYWRIGHT_HEADLESS: $PLAYWRIGHT_HEADLESS"
echo "DB_HOST: $DB_HOST"
echo ""

echo "=== Diagnostic Complete ==="
```

Add to workflow:

```yaml
# .github/workflows/rspec.yml
- name: Run diagnostics
  run: |
    chmod +x bin/ci-diagnostic
    bin/ci-diagnostic
```

**Observability Benefit**:
- Quick identification of environment issues
- Consistent diagnostic output across local, Docker, and CI
- Faster debugging of CI failures

---

## Observability Gaps

### Critical Gaps

1. **No structured logging**: Console output is not searchable or correlatable across runs
   - **Impact**: Difficult to debug intermittent CI failures or analyze patterns over time
   - **Solution**: Implement JSON-structured logging with correlation IDs

2. **No metrics tracking over time**: No monitoring of performance trends
   - **Impact**: Cannot detect gradual performance degradation or identify optimization opportunities
   - **Solution**: Export metrics to time-series database or use GitHub Actions API for visualization

3. **Tracing disabled by default**: Playwright traces only captured when explicitly enabled
   - **Impact**: Missing critical debugging information when tests fail
   - **Solution**: Enable tracing for CI environment (`on-first-retry` mode)

### Minor Gaps

1. **No flakiness detection**: No automated tracking of intermittent test failures
   - **Impact**: Flaky tests may go unnoticed until they become chronic
   - **Solution**: Implement flakiness tracker that records failure patterns

2. **No alerting mechanism**: Build failure is only notification
   - **Impact**: No proactive alerts for degraded performance or increased failure rates
   - **Solution**: Add Slack/Discord notifications for repeated failures or performance regressions

3. **Limited workflow instrumentation**: No timing breakdown of workflow steps
   - **Impact**: Cannot identify bottlenecks in CI pipeline (e.g., slow database setup)
   - **Solution**: Add step timing outputs and summary report

---

## Recommended Observability Stack

Based on design, recommend:

**Logging**:
- **Primary**: GitHub Actions native logs (automatically captured)
- **Enhancement**: JSON-structured logging in RSpec output
- **Optional**: Export to Elasticsearch or CloudWatch for long-term analysis

**Metrics**:
- **Primary**: GitHub Actions artifacts (JUnit XML, coverage JSON)
- **Enhancement**: Custom metrics JSON file uploaded as artifact
- **Optional**: GitHub Actions API + Grafana for visualization
- **Optional**: Datadog CI Visibility or similar service

**Tracing**:
- **Primary**: Playwright traces (enable `on-first-retry` mode)
- **Enhancement**: Workflow step timing and correlation IDs
- **Optional**: OpenTelemetry for full distributed tracing (if integrated with other services)

**Dashboards**:
- **Primary**: GitHub Actions UI (workflow runs, artifacts)
- **Enhancement**: Custom dashboard using GitHub API
- **Optional**: Grafana dashboard for trend visualization

**Alerting**:
- **Primary**: GitHub Actions status checks (required for PR merge)
- **Enhancement**: Slack/Discord webhook for failures
- **Optional**: PagerDuty/Opsgenie for critical failures

---

## Action Items for Designer

To achieve "Approved" status (≥ 4.0/5.0), address the following:

### Priority 1 (Critical for Production CI)

1. **Implement structured logging**:
   - Create `spec/support/structured_logger.rb` with JSON logging
   - Add correlation IDs (GitHub run ID, test file, test name)
   - Include environment context in all logs

2. **Enable Playwright tracing in CI**:
   - Set `PLAYWRIGHT_TRACE: "on-first-retry"` in workflow environment
   - Upload traces as artifacts even on success (for debugging)

3. **Add metrics collection**:
   - Create workflow metrics JSON (execution time, test counts, coverage)
   - Upload metrics as artifact with 30-day retention
   - Document metrics schema

### Priority 2 (Recommended for Better Observability)

4. **Create diagnostic script**:
   - Implement `bin/ci-diagnostic` to verify environment health
   - Run as first step in workflow
   - Output environment details to logs

5. **Add workflow step timing**:
   - Instrument each major step (database setup, asset build, RSpec)
   - Output timing summary at end of workflow
   - Track timing trends over time

6. **Implement flakiness detection**:
   - Create `spec/support/flakiness_tracker.rb`
   - Record test failures with metadata
   - Generate flakiness report

### Priority 3 (Nice to Have)

7. **Add alerting mechanism**:
   - Configure Slack/Discord webhook for repeated failures
   - Alert on performance regression (> 20% slower)

8. **Create monitoring dashboard**:
   - Document how to query GitHub Actions API for metrics
   - Provide example Grafana dashboard configuration (optional)

---

## Structured Data

```yaml
evaluation_result:
  evaluator: "design-observability-evaluator"
  design_document: "docs/designs/github-actions-rspec-playwright.md"
  timestamp: "2025-11-23T10:30:00+09:00"
  overall_judgment:
    status: "Request Changes"
    overall_score: 3.2
  detailed_scores:
    logging_strategy:
      score: 2.5
      weight: 0.35
      weighted_contribution: 0.875
    metrics_monitoring:
      score: 3.0
      weight: 0.30
      weighted_contribution: 0.90
    distributed_tracing:
      score: 3.5
      weight: 0.20
      weighted_contribution: 0.70
    health_checks:
      score: 4.0
      weight: 0.15
      weighted_contribution: 0.60
  observability_gaps:
    - severity: "critical"
      gap: "No structured logging"
      impact: "Difficult to debug intermittent CI failures or analyze patterns over time"
    - severity: "critical"
      gap: "No metrics tracking over time"
      impact: "Cannot detect gradual performance degradation"
    - severity: "critical"
      gap: "Tracing disabled by default"
      impact: "Missing critical debugging information when tests fail"
    - severity: "minor"
      gap: "No flakiness detection"
      impact: "Flaky tests may go unnoticed"
    - severity: "minor"
      gap: "No alerting mechanism"
      impact: "No proactive alerts for degraded performance"
    - severity: "minor"
      gap: "Limited workflow instrumentation"
      impact: "Cannot identify bottlenecks in CI pipeline"
  observability_coverage: 64
  recommended_stack:
    logging: "GitHub Actions logs + JSON-structured RSpec output"
    metrics: "GitHub Actions artifacts + custom metrics JSON"
    tracing: "Playwright traces (on-first-retry mode) + workflow step timing"
    dashboards: "GitHub Actions UI + optional Grafana"
    alerting: "GitHub Actions status checks + optional Slack/Discord webhook"
  approval_threshold: 4.0
  current_score: 3.2
  score_gap: 0.8
  estimated_effort_to_approve: "1-2 days for Priority 1 items"
```

---

**Evaluation Complete**

The design provides a solid foundation for test execution observability (screenshots, traces, coverage) but needs improvements in logging, metrics, and tracing to achieve production-grade observability for the CI pipeline itself. Focus on Priority 1 action items to reach approval threshold.
